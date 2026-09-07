#include "loudness.h"

#include <math.h>
#include <string.h>

#include "dsp_util.h"

#define CV_LOUDNESS_OFFSET (-0.691)

void cv_loudness_init(cv_loudness *ln, double sample_rate) {
  memset(ln, 0, sizeof(*ln));
  ln->sample_rate = cv_clamp_d(sample_rate, 8000.0, 192000.0);
  ln->hop_len = (int)(ln->sample_rate * 0.1);
  if (ln->hop_len < 1) ln->hop_len = 1;
  ln->target_lufs = -16.0;
  ln->max_gain_db = 8.0;
  ln->max_att_db = 8.0;
  ln->adapt_rate_db_s = 1.5;
  ln->gain_db = 0.0;
  ln->target_gain_db = 0.0;
  ln->integrated_lufs = -70.0;
  for (int i = 0; i < CINEVA_DSP_MAX_CHANNELS; i++) {
    cv_biquad_init(&ln->k1[i]);
    cv_biquad_init(&ln->k2[i]);
    /* Pondération K : shelf +4 dB @ 1681.97 Hz (Q 0.7071) puis HP 38.13 Hz (Q 0.5). */
    cv_biquad_set(&ln->k1[i], CV_BQ_HIGHSHELF, 1681.97, 3.9998, 0.7071752369556, ln->sample_rate);
    cv_biquad_set(&ln->k2[i], CV_BQ_HIGHPASS, 38.13, 0.0, 0.5003270372833, ln->sample_rate);
    cv_biquad_snap(&ln->k1[i]);
    cv_biquad_snap(&ln->k2[i]);
  }
}

void cv_loudness_set(cv_loudness *ln, int enable, double target_lufs,
                     double max_gain_db, double max_att_db,
                     double adapt_rate_db_s) {
  ln->enable = enable ? 1 : 0;
  ln->target_lufs = cv_clamp_d(cv_sanitize_d(target_lufs), -36.0, -8.0);
  ln->max_gain_db = cv_clamp_d(cv_sanitize_d(max_gain_db), 0.0, 12.0);
  ln->max_att_db = cv_clamp_d(cv_sanitize_d(max_att_db), 0.0, 12.0);
  ln->adapt_rate_db_s = cv_clamp_d(cv_sanitize_d(adapt_rate_db_s), 0.1, 6.0);
}

void cv_loudness_reset(cv_loudness *ln) {
  ln->hop_pos = 0;
  for (int i = 0; i < CINEVA_DSP_MAX_CHANNELS; i++) ln->hop_ms[i] = 0.0;
  memset(ln->hop_z, 0, sizeof(ln->hop_z));
  ln->hop_count = 0;
  ln->hop_head = 0;
  ln->silent_run = 0;
  ln->integrated_lufs = -70.0;
  ln->gain_db = 0.0;
  ln->target_gain_db = 0.0;
  for (int i = 0; i < CINEVA_DSP_MAX_CHANNELS; i++) {
    cv_biquad_reset_state(&ln->k1[i]);
    cv_biquad_reset_state(&ln->k2[i]);
  }
}

/* Recalcule le loudness intégré gate (double gate) sur l'historique. */
static void cv_loudness_recompute(cv_loudness *ln) {
  int n = ln->hop_count;
  if (n <= 0) {
    ln->integrated_lufs = -70.0;
    return;
  }
  /* Passe 1 : gate absolu à -70 LUFS. */
  double sum = 0.0;
  int count = 0;
  for (int i = 0; i < n; i++) {
    double z = ln->hop_z[i];
    if (z <= 0.0) continue;
    double lb = CV_LOUDNESS_OFFSET + 10.0 * log10(z);
    if (lb > -70.0) {
      sum += z;
      count++;
    }
  }
  if (count == 0 || sum <= 0.0) {
    ln->integrated_lufs = -70.0;
    return;
  }
  double mean_z = sum / (double)count;
  double rel_threshold = CV_LOUDNESS_OFFSET + 10.0 * log10(mean_z) - 10.0;
  /* Passe 2 : gate relatif à -10 LU. */
  double sum2 = 0.0;
  int count2 = 0;
  for (int i = 0; i < n; i++) {
    double z = ln->hop_z[i];
    if (z <= 0.0) continue;
    double lb = CV_LOUDNESS_OFFSET + 10.0 * log10(z);
    if (lb > -70.0 && lb > rel_threshold) {
      sum2 += z;
      count2++;
    }
  }
  if (count2 == 0 || sum2 <= 0.0) {
    ln->integrated_lufs = -70.0;
    return;
  }
  ln->integrated_lufs = CV_LOUDNESS_OFFSET + 10.0 * log10(sum2 / (double)count2);
}

void cv_loudness_process(cv_loudness *ln, const float *const *in,
                         float *const *out, int channels, int frames,
                         const double *weights) {
  if (channels < 1 || channels > CINEVA_DSP_MAX_CHANNELS) return;
  double ramp = 1.0 - cv_onepole_coef(ln->sample_rate, 0.02);
  double gain_step_db = ln->adapt_rate_db_s / ln->sample_rate;

  for (int ch = 0; ch < channels; ch++) {
    if (out[ch] != in[ch]) memcpy(out[ch], in[ch], (size_t)frames * sizeof(float));
  }

  if (!ln->enable) {
    ln->gain_db = 0.0;
    ln->target_gain_db = 0.0;
    return;
  }

  for (int i = 0; i < frames; i++) {
    for (int ch = 0; ch < channels; ch++) {
      double x = cv_sanitize_f(in[ch][i]);
      double y = cv_biquad_tick(&ln->k1[ch], x, ramp);
      y = cv_biquad_tick(&ln->k2[ch], y, ramp);
      ln->hop_ms[ch] += y * y;
    }

    ln->hop_pos++;
    if (ln->hop_pos >= ln->hop_len) {
      ln->hop_pos = 0;
      double z = 0.0;
      for (int ch = 0; ch < channels; ch++) {
        double ms = ln->hop_ms[ch] / (double)ln->hop_len;
        z += (weights ? weights[ch] : 1.0) * ms;
        ln->hop_ms[ch] = 0.0;
      }
      ln->hop_z[ln->hop_head] = z;
      ln->hop_head = (ln->hop_head + 1) % CV_LOUDNESS_HOPS;
      if (ln->hop_count < CV_LOUDNESS_HOPS) ln->hop_count++;

      if (z < 1e-10) {
        ln->silent_run++;
      } else {
        ln->silent_run = 0;
      }
      cv_loudness_recompute(ln);

      if (ln->silent_run >= CV_LOUDNESS_SILENCE_BLOCKS || ln->integrated_lufs <= -69.9) {
        ln->target_gain_db = ln->gain_db; /* gel pendant le silence */
      } else {
        double want = ln->target_lufs - ln->integrated_lufs;
        ln->target_gain_db = cv_clamp_d(want, -ln->max_att_db, ln->max_gain_db);
      }
    }

    /* Gain adaptatif borné en vitesse (pas de pompage). */
    if (ln->gain_db < ln->target_gain_db) {
      ln->gain_db += gain_step_db;
      if (ln->gain_db > ln->target_gain_db) ln->gain_db = ln->target_gain_db;
    } else if (ln->gain_db > ln->target_gain_db) {
      ln->gain_db -= gain_step_db;
      if (ln->gain_db < ln->target_gain_db) ln->gain_db = ln->target_gain_db;
    }

    double g = cv_db_to_lin(ln->gain_db);
    for (int ch = 0; ch < channels; ch++) {
      out[ch][i] = (float)((double)cv_sanitize_f(out[ch][i]) * g);
    }
  }
}

double cv_loudness_integrated(const cv_loudness *ln) { return ln->integrated_lufs; }

double cv_loudness_gain_db(const cv_loudness *ln) { return ln->gain_db; }
