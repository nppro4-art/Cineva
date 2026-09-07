#include "cineva_dsp.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "bass.h"
#include "channel_mapper.h"
#include "dialogue.h"
#include "drc.h"
#include "dsp_util.h"
#include "limiter.h"
#include "loudness.h"
#include "param_eq.h"
#include "room.h"
#include "spatial.h"

#define CV_VERSION_STRING "1.0.0"

struct cineva_dsp {
  double params[CINEVA_DSP_PARAM_COUNT];
  double sample_rate;
  int layout;

  cv_loudness loudness;
  cv_param_eq eq;
  cv_drc drc;
  cv_dialogue dialogue;
  cv_bass bass;
  cv_spatial spatial;
  cv_room room;
  cv_limiter limiter;

  float chan[CINEVA_DSP_MAX_CHANNELS][CINEVA_DSP_MAX_BLOCK];   /* bus multicanal */
  float stereo[2][CINEVA_DSP_MAX_BLOCK];                        /* bus stéréo */
  double weights[CINEVA_DSP_MAX_CHANNELS];

  /* Métriques. */
  double integrated_lufs;
  double true_peak_db;
  double clipped_samples;
  int engine_active;
};

const char *cineva_dsp_version(void) { return CV_VERSION_STRING; }

static double cv_p(const double *v, int i, double def, double lo, double hi) {
  double x = v[i];
  if (!(x == x) || x < -1e30 || x > 1e30) x = def;
  if (x < lo) x = lo;
  if (x > hi) x = hi;
  return x;
}

static int cv_p_bool(const double *v, int i) {
  return v[i] != 0.0 && v[i] == v[i] ? 1 : 0;
}

static double cv_norm(double *v, int i, double def, double lo, double hi) {
  v[i] = cv_p(v, i, def, lo, hi);
  return v[i];
}

static void cineva_dsp_apply_params(cineva_dsp *d) {
  double *v = d->params;

  cv_norm(v, 3, 2, 1, 8);           /* inChannels */
  int in_ch = (int)v[3];
  cv_norm(v, 4, 2, 2, 2);           /* outChannels (V1 : stéréo) */
  cv_norm(v, 5, 1, 0, 4);           /* inputLayout */
  int layout = cv_layout_from_channels(in_ch);
  v[5] = (double)layout;            /* la disposition réelle prime */
  d->layout = layout;

  cv_loudness_set(&d->loudness, cv_p_bool(v, 8),
                  cv_norm(v, 9, -16, -36, -8), cv_norm(v, 10, 8, 0, 12),
                  cv_norm(v, 11, 8, 0, 12), cv_norm(v, 12, 1.5, 0.1, 6));

  int types[CV_EQ_BANDS];
  double freqs[CV_EQ_BANDS], gains[CV_EQ_BANDS], qs[CV_EQ_BANDS];
  for (int i = 0; i < CV_EQ_BANDS; i++) {
    types[i] = (int)cv_norm(v, 17 + 5 * i, 1, 0, 4);
    freqs[i] = cv_norm(v, 18 + 5 * i, 1000, 20, 20000);
    gains[i] = cv_norm(v, 19 + 5 * i, 0, -15, 15);
    qs[i] = cv_norm(v, 20 + 5 * i, 0.9, 0.3, 4);
  }
  cv_param_eq_set(&d->eq, cv_p_bool(v, 16), types, freqs, gains, qs);

  cv_drc_set(&d->drc, cv_p_bool(v, 48), cv_norm(v, 49, -24, -60, 0),
             cv_norm(v, 50, 2.5, 1, 20), cv_norm(v, 51, 6, 0, 24),
             cv_norm(v, 52, 15, 0.5, 200), cv_norm(v, 53, 250, 20, 1000),
             cv_norm(v, 54, 0, -6, 12), cv_norm(v, 55, 100, 0, 100),
             (int)cv_norm(v, 56, 1, 0, 1));

  cv_dialogue_set(&d->dialogue, cv_p_bool(v, 60), cv_norm(v, 61, 35, 0, 100));

  cv_bass_set(&d->bass, cv_p_bool(v, 68), cv_norm(v, 69, 50, 0, 100),
              cv_norm(v, 70, 80, 50, 160), (int)cv_norm(v, 71, 0, 0, 2),
              cv_norm(v, 72, 5, -6, 9), cv_norm(v, 73, 0, 0, 100),
              cv_norm(v, 74, 0, -12, 6));

  cv_spatial_set(&d->spatial, cv_p_bool(v, 80), (int)cv_norm(v, 81, 1, 0, 3),
                 cv_norm(v, 82, 100, 0, 150), cv_norm(v, 83, 0, 0, 100),
                 cv_norm(v, 84, 100, 0, 100));

  cv_room_set(&d->room, cv_p_bool(v, 92), cv_norm(v, 93, 6, 0, 15),
              cv_norm(v, 94, 100, 50, 150));

  cv_limiter_set(&d->limiter, cv_p_bool(v, 100), cv_norm(v, 101, -1, -6, 0),
                 cv_norm(v, 102, 5, 1, 10), cv_norm(v, 103, 120, 40, 500));

  cv_mapper_weights(d->layout, in_ch, d->weights);
}

cineva_dsp *cineva_dsp_create(double sample_rate) {
  if (!(sample_rate == sample_rate) || sample_rate < 8000.0 || sample_rate > 192000.0) {
    sample_rate = 48000.0;
  }
  cineva_dsp *d = (cineva_dsp *)calloc(1, sizeof(cineva_dsp));
  if (d == NULL) return NULL;
  d->sample_rate = sample_rate;
  d->true_peak_db = -999.0;

  cv_loudness_init(&d->loudness, sample_rate);
  cv_param_eq_init(&d->eq, sample_rate);
  cv_drc_init(&d->drc, sample_rate);
  cv_dialogue_init(&d->dialogue, sample_rate);
  cv_bass_init(&d->bass, sample_rate);
  cv_spatial_init(&d->spatial, sample_rate);
  cv_room_init(&d->room, sample_rate);
  cv_limiter_init(&d->limiter, sample_rate);

  /* Paramètres par défaut : profil Standard neutre + masterEnable
     (identiques à neutralParams() côté Dart). */
  memset(d->params, 0, sizeof(d->params));
  d->params[0] = CINEVA_DSP_PARAM_VERSION;
  d->params[1] = sample_rate;
  d->params[2] = 1;
  d->params[3] = 2;
  d->params[4] = 2;
  d->params[5] = 1;
  d->params[8] = 1;   /* loudness on */
  d->params[9] = -16;
  d->params[10] = 8;
  d->params[11] = 8;
  d->params[12] = 1.5;
  d->params[16] = 1;  /* eq on */
  {
    static const int eq_types[6] = {0, 1, 1, 1, 1, 2};
    static const double eq_freqs[6] = {45, 90, 300, 1200, 3500, 10000};
    for (int i = 0; i < 6; i++) {
      d->params[17 + 5 * i] = eq_types[i];
      d->params[18 + 5 * i] = eq_freqs[i];
      d->params[19 + 5 * i] = 0.0;
      d->params[20 + 5 * i] = 0.9;
    }
  }
  d->params[48] = 1;  /* drc on */
  d->params[49] = -24;
  d->params[50] = 2.5;
  d->params[51] = 6;
  d->params[52] = 15;
  d->params[53] = 250;
  d->params[55] = 100;
  d->params[56] = 1;  /* rms */
  d->params[60] = 1;  /* dialogue on */
  d->params[61] = 35;
  d->params[68] = 1;  /* bass on */
  d->params[69] = 50;
  d->params[70] = 80;
  d->params[72] = 5;
  d->params[80] = 1;  /* spatial on */
  d->params[81] = 1;  /* width */
  d->params[82] = 100;
  d->params[84] = 100;
  d->params[92] = 1;  /* room on */
  d->params[93] = 6;
  d->params[94] = 100;
  d->params[100] = 1; /* limiter on */
  d->params[101] = -1;
  d->params[102] = 5;
  d->params[103] = 120;
  cineva_dsp_apply_params(d);
  return d;
}

void cineva_dsp_destroy(cineva_dsp *dsp) { free(dsp); }

int cineva_dsp_set_params(cineva_dsp *dsp, const double *values, int count) {
  if (dsp == NULL || values == NULL || count != CINEVA_DSP_PARAM_COUNT) return -1;
  double version = values[0];
  if (!(version == version) || (int)version != CINEVA_DSP_PARAM_VERSION) return -2;

  double new_sr = cv_p(values, 1, 48000, 8000, 192000);
  if (new_sr != dsp->sample_rate) {
    dsp->sample_rate = new_sr;
    cv_loudness_init(&dsp->loudness, new_sr);
    cv_param_eq_init(&dsp->eq, new_sr);
    cv_drc_init(&dsp->drc, new_sr);
    cv_dialogue_init(&dsp->dialogue, new_sr);
    cv_bass_init(&dsp->bass, new_sr);
    cv_spatial_init(&dsp->spatial, new_sr);
    cv_room_init(&dsp->room, new_sr);
    cv_limiter_init(&dsp->limiter, new_sr);
  }

  memcpy(dsp->params, values, sizeof(double) * CINEVA_DSP_PARAM_COUNT);
  dsp->params[1] = dsp->sample_rate;
  cineva_dsp_apply_params(dsp);
  return 0;
}

int cineva_dsp_get_params(const cineva_dsp *dsp, double *out, int count) {
  if (dsp == NULL || out == NULL || count != CINEVA_DSP_PARAM_COUNT) return -1;
  memcpy(out, dsp->params, sizeof(double) * CINEVA_DSP_PARAM_COUNT);
  return 0;
}

int cineva_dsp_reset(cineva_dsp *dsp) {
  if (dsp == NULL) return -1;
  cv_loudness_reset(&dsp->loudness);
  cv_param_eq_reset(&dsp->eq);
  cv_drc_reset(&dsp->drc);
  cv_dialogue_reset(&dsp->dialogue);
  cv_bass_reset(&dsp->bass);
  cv_spatial_reset(&dsp->spatial);
  cv_room_reset(&dsp->room);
  cv_limiter_reset(&dsp->limiter);
  dsp->integrated_lufs = -70.0;
  dsp->true_peak_db = -999.0;
  dsp->clipped_samples = 0.0;
  return 0;
}

static void cineva_dsp_process_chunk(cineva_dsp *d, const float *const *in,
                                     int in_channels, float *const *out,
                                     int frames) {
  int master = cv_p_bool(d->params, 2);
  int layout = d->layout;

  /* 1. Nettoyage + copie vers le bus interne. */
  for (int ch = 0; ch < in_channels; ch++) {
    for (int i = 0; i < frames; i++) {
      d->chan[ch][i] = cv_sanitize_f(in[ch][i]);
    }
  }

  if (!master) {
    /* Bypass bit-exact (A/B). */
    for (int i = 0; i < frames; i++) {
      float l = in_channels > 0 ? in[0][i] : 0.0f;
      float r = in_channels > 1 ? in[1][i] : l;
      float cl = cv_clamp_f(cv_sanitize_f(l), -1.0f, 1.0f);
      float cr = cv_clamp_f(cv_sanitize_f(r), -1.0f, 1.0f);
      if (cl != l || cr != r) d->clipped_samples += 1.0;
      out[0][i] = cl;
      out[1][i] = cr;
    }
    d->engine_active = 0;
    return;
  }
  d->engine_active = 1;

  /* 2. Loudness (mesure multicanal + gain) sur le bus. */
  {
    const float *bus[CINEVA_DSP_MAX_CHANNELS];
    float *bus_out[CINEVA_DSP_MAX_CHANNELS];
    for (int ch = 0; ch < in_channels; ch++) {
      bus[ch] = d->chan[ch];
      bus_out[ch] = d->chan[ch];
    }
    cv_loudness_process(&d->loudness, bus, bus_out, in_channels, frames, d->weights);
    d->integrated_lufs = d->loudness.integrated_lufs;
  }

  /* 3. Dialogue (multicanal si disponible). */
  {
    float *bus[CINEVA_DSP_MAX_CHANNELS];
    for (int ch = 0; ch < in_channels; ch++) bus[ch] = d->chan[ch];
    cv_dialogue_process(&d->dialogue, bus, in_channels, layout, frames);
  }

  /* 4. Spatial (ou downmix ITU) vers le bus stéréo. */
  double headroom = cv_db_to_lin(cv_p(d->params, 7, 0, -12, 12));
  int bass_handles_lfe = d->bass.enable && cv_p_bool(d->params, 6) && layout >= 3 && in_channels >= 6;
  double lfe_downmix_gain = 0.0;
  if (layout >= 3 && in_channels >= 6) {
    if (!bass_handles_lfe) {
      lfe_downmix_gain = cv_p_bool(d->params, 6)
          ? cv_db_to_lin(cv_p(d->params, 74, 0, -12, 6))
          : 0.0;
    }
  }

  {
    const float *bus[CINEVA_DSP_MAX_CHANNELS];
    for (int ch = 0; ch < in_channels; ch++) bus[ch] = d->chan[ch];
    float *st[2] = {d->stereo[0], d->stereo[1]};
    if (d->spatial.enable) {
      cv_spatial_process(&d->spatial, bus, in_channels, layout, st,
                         lfe_downmix_gain, frames);
    } else {
      cv_mapper_downmix_itu(bus, in_channels, layout, st, lfe_downmix_gain, frames);
    }
  }

  /* 5. Bass management (stéréo + LFE). */
  const float *lfe_ptr = bass_handles_lfe ? d->chan[3] : NULL;
  {
    float *st[2] = {d->stereo[0], d->stereo[1]};
    cv_bass_process(&d->bass, st, lfe_ptr, frames);
  }

  /* 6. Headroom master. */
  if (headroom != 1.0) {
    for (int i = 0; i < frames; i++) {
      d->stereo[0][i] = (float)((double)d->stereo[0][i] * headroom);
      d->stereo[1][i] = (float)((double)d->stereo[1][i] * headroom);
    }
  }

  /* 7. EQ. */
  {
    float *st[2] = {d->stereo[0], d->stereo[1]};
    cv_param_eq_process(&d->eq, st, 2, frames);
  }

  /* 8. DRC. */
  {
    float *st[2] = {d->stereo[0], d->stereo[1]};
    cv_drc_process(&d->drc, st, 2, frames);
  }

  /* 9. Room. */
  {
    float *st[2] = {d->stereo[0], d->stereo[1]};
    cv_room_process(&d->room, st, frames);
  }

  /* 10. Limiteur + clamp final + métriques. */
  {
    const float *st_in[2] = {d->stereo[0], d->stereo[1]};
    cv_limiter_process(&d->limiter, st_in, out, frames);
  }

  for (int i = 0; i < frames; i++) {
    float l = out[0][i];
    float r = out[1][i];
    double pl = fabs((double)l);
    double pr = fabs((double)r);
    if (pl > pr) pr = pl;
    double pdb = cv_lin_to_db(pr);
    if (pdb > d->true_peak_db) d->true_peak_db = pdb;
    float cl = cv_clamp_f(cv_sanitize_f(l), -1.0f, 1.0f);
    float cr = cv_clamp_f(cv_sanitize_f(r), -1.0f, 1.0f);
    if (cl != l || cr != r) d->clipped_samples += 1.0;
    out[0][i] = cl;
    out[1][i] = cr;
  }
}

int cineva_dsp_process(cineva_dsp *dsp, const float *const *in, int in_channels,
                       float *const *out, int out_channels, int frames) {
  if (dsp == NULL || in == NULL || out == NULL) return -1;
  if (in_channels < 1 || in_channels > CINEVA_DSP_MAX_CHANNELS) return -1;
  if (out_channels != 2) return -1;
  if (frames <= 0) return 0;

  int offset = 0;
  while (offset < frames) {
    int n = frames - offset;
    if (n > CINEVA_DSP_MAX_BLOCK) n = CINEVA_DSP_MAX_BLOCK;

    const float *chunk_in[CINEVA_DSP_MAX_CHANNELS];
    float *chunk_out[2];
    for (int ch = 0; ch < in_channels; ch++) chunk_in[ch] = in[ch] + offset;
    chunk_out[0] = out[0] + offset;
    chunk_out[1] = out[1] + offset;

    cineva_dsp_process_chunk(dsp, chunk_in, in_channels, chunk_out, n);
    offset += n;
  }
  return 0;
}

int cineva_dsp_get_metrics(cineva_dsp *dsp, double *out, int count) {
  if (dsp == NULL || out == NULL || count != CINEVA_DSP_METRIC_COUNT) return -1;
  for (int i = 0; i < CINEVA_DSP_METRIC_COUNT; i++) out[i] = 0.0;
  out[0] = dsp->integrated_lufs;
  out[1] = dsp->true_peak_db;
  dsp->true_peak_db = -999.0;
  out[2] = cv_loudness_gain_db(&dsp->loudness);
  out[3] = cv_limiter_gain_db(&dsp->limiter);
  out[4] = dsp->clipped_samples;
  dsp->clipped_samples = 0.0;
  out[5] = (double)dsp->engine_active;
  return 0;
}
