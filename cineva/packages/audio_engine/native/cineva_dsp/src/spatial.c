#include "spatial.h"

#include <math.h>
#include <string.h>

#include "dsp_util.h"

/* Dispositions (voir channel_mapper.h) :
 * 0 mono [L] ; 1 stéréo [L,R] ; 2 quad [L,R,Ls,Rs] ;
 * 3 5.1 [L,R,C,LFE,Ls,Rs] ; 4 7.1 [L,R,C,LFE,Ls,Rs,Lb,Rb]. */

static double cv_azimuth_for(int layout, int ch) {
  switch (layout) {
    case 2: /* quad */
      switch (ch) {
        case 0: return -30.0;
        case 1: return 30.0;
        case 2: return -105.0;
        default: return 105.0;
      }
    case 3: /* 5.1 */
    case 4: /* 7.1 */
      switch (ch) {
        case 0: return -30.0;
        case 1: return 30.0;
        case 2: return 0.0;
        case 3: return 0.0; /* LFE : non spatialisé */
        case 4: return -105.0;
        case 5: return 105.0;
        case 6: return -140.0;
        default: return 140.0;
      }
    default:
      return ch == 0 ? -30.0 : 30.0;
  }
}

void cv_spatial_init(cv_spatial *sp, double sample_rate) {
  memset(sp, 0, sizeof(*sp));
  sp->sample_rate = cv_clamp_d(sample_rate, 8000.0, 192000.0);
  sp->mode = CV_SPATIAL_MODE_WIDTH;
  sp->width = 1.0;
  sp->lfe_gain_lin = 0.0;
  for (int ch = 0; ch < CINEVA_DSP_MAX_CHANNELS; ch++) {
    cv_biquad_init(&sp->contra_shelf[ch]);
    cv_biquad_init(&sp->rear_muffle[ch]);
    cv_biquad_init(&sp->front_peak[ch]);
  }
  cv_biquad_init(&sp->cf_lp[0]);
  cv_biquad_init(&sp->cf_lp[1]);
  sp->dirty = 1;
}

void cv_spatial_set(cv_spatial *sp, int enable, int mode, double width_percent,
                    double crossfeed_percent, double binaural_amount_percent) {
  sp->enable = enable ? 1 : 0;
  int m = mode;
  if (m < CV_SPATIAL_MODE_OFF || m > CV_SPATIAL_MODE_BINAURAL_CROSSFEED) {
    m = CV_SPATIAL_MODE_WIDTH;
  }
  if (m != sp->mode) {
    sp->mode = m;
    sp->dirty = 1;
  }
  sp->width = cv_clamp_d(cv_sanitize_d(width_percent), 0.0, 150.0) / 100.0;
  sp->crossfeed = cv_clamp_d(cv_sanitize_d(crossfeed_percent), 0.0, 100.0) / 100.0;
  sp->binaural_amount = cv_clamp_d(cv_sanitize_d(binaural_amount_percent), 0.0, 100.0) / 100.0;
}

static void cv_spatial_configure(cv_spatial *sp, int channels, int layout) {
  sp->channels = channels;
  sp->layout = layout;
  double sr = sp->sample_rate;
  for (int ch = 0; ch < CINEVA_DSP_MAX_CHANNELS; ch++) {
    sp->itu_mix[ch] = 0.0;
    sp->bina_mix[ch] = 0.0;
    sp->ch_is_rear[ch] = 0;
    sp->ch_has_contra[ch] = 0;
    sp->contra_delay_smp[ch] = 0.0;
  }
  for (int ch = 0; ch < channels; ch++) {
    double az = cv_azimuth_for(layout, ch);
    int is_lfe = (layout >= 3 && ch == 3);
    if (is_lfe) continue; /* géré par lfe_gain_lin */
    int is_center = (layout >= 3 && ch == 2);
    int is_rear = fabs(az) >= 90.0;
    sp->ch_is_rear[ch] = is_rear;

    /* Gains du downmix ITU-R BS.775. */
    sp->itu_mix[ch] = is_center ? 0.707 : 0.707;

    /* Gains binauraux ipsi/controlatéraux. */
    double ipsi = 1.0;
    if (is_center) ipsi = 0.85;
    if (is_rear) ipsi = 0.75;
    sp->bina_mix[ch] = ipsi;

    /* ITD controlatérale (Woodworth simplifié) : 0.65 ms max. */
    if (fabs(az) > 1.0) {
      sp->ch_has_contra[ch] = 1;
      double itd_s = 0.00065 * sin(fabs(az) * CINEVA_PI / 180.0);
      sp->contra_delay_smp[ch] = itd_s * sr;
    }

    /* ILD : shelf négatif ~2 kHz sur la voie controlatérale. */
    double ild = is_rear ? 10.0 : 7.0; /* dB d'atténuation HF */
    cv_biquad_set(&sp->contra_shelf[ch], CV_BQ_HIGHSHELF, 2000.0, -ild, 0.707, sr);

    /* Arrière : amortissement HF supplémentaire des deux côtés. */
    if (is_rear) {
      cv_biquad_set(&sp->rear_muffle[ch], CV_BQ_LOWSHELF, 5000.0, -4.0, 0.707, sr);
    } else {
      cv_biquad_set_raw(&sp->rear_muffle[ch], 1.0, 0.0, 0.0, 0.0, 0.0);
    }

    /* Avant : léger pic de présence ipsilatéral (indice de localisation). */
    if (!is_rear && !is_center) {
      cv_biquad_set(&sp->front_peak[ch], CV_BQ_PEAKING, 5500.0, 1.5, 1.2, sr);
    } else if (is_center) {
      cv_biquad_set(&sp->front_peak[ch], CV_BQ_PEAKING, 5500.0, 0.8, 1.2, sr);
    } else {
      cv_biquad_set_raw(&sp->front_peak[ch], 1.0, 0.0, 0.0, 0.0, 0.0);
    }
  }
  /* Crossfeed : passe-bas ~700 Hz. */
  for (int i = 0; i < 2; i++) {
    cv_biquad_set(&sp->cf_lp[i], CV_BQ_LOWPASS, 700.0, 0.0, 0.707, sr);
  }
  sp->dirty = 0;
}

void cv_spatial_reset(cv_spatial *sp) {
  for (int ch = 0; ch < CINEVA_DSP_MAX_CHANNELS; ch++) {
    cv_biquad_reset_state(&sp->contra_shelf[ch]);
    cv_biquad_reset_state(&sp->rear_muffle[ch]);
    cv_biquad_reset_state(&sp->front_peak[ch]);
    memset(sp->delay_line[ch], 0, sizeof(sp->delay_line[ch]));
    sp->delay_pos[ch] = 0.0;
  }
  for (int i = 0; i < 2; i++) {
    cv_biquad_reset_state(&sp->cf_lp[i]);
    memset(sp->cf_line[i], 0, sizeof(sp->cf_line[i]));
    sp->cf_pos[i] = 0.0;
  }
  sp->dirty = 1;
}

/* Délai fractionnaire par interpolation linéaire (lecture dans le passé). */
static inline double cv_delay_read(const double *line, double pos, int write,
                                   double delay_smp) {
  int len = CV_SPATIAL_MAX_DELAY;
  double read = (double)write - delay_smp;
  if (read < 0.0) read += (double)len;
  int i0 = (int)read;
  double frac = read - (double)i0;
  int i1 = i0 - 1;
  if (i1 < 0) i1 += len;
  double a = line[i0];
  double b = line[i1];
  return a + (b - a) * frac;
}

void cv_spatial_process(cv_spatial *sp, const float *const *in, int channels,
                        int layout, float *const *out, double lfe_gain_lin,
                        int frames) {
  if (!sp->enable || channels < 1 || frames <= 0) {
    if (out[0] != in[0] && channels >= 1) {
      for (int i = 0; i < frames; i++) {
        out[0][i] = channels > 1 ? in[0][i] : in[0][i];
        out[1][i] = channels > 1 ? in[1][i] : in[0][i];
      }
    }
    return;
  }
  sp->lfe_gain_lin = cv_sanitize_d(lfe_gain_lin);
  if (sp->lfe_gain_lin < 0.0) sp->lfe_gain_lin = 0.0;

  int stereo_in = channels <= 2;

  if (stereo_in) {
    /* Chemin stéréo : élargissement M/S (+ crossfeed éventuel). */
    double width = sp->mode == CV_SPATIAL_MODE_OFF ? 1.0 : sp->width;
    double ramp = 1.0 - cv_onepole_coef(sp->sample_rate, 0.02);
    double cf_gain = sp->crossfeed * cv_db_to_lin(-8.0);
    double cf_delay = 0.00025 * sp->sample_rate;
    int do_cf = cf_gain > 0.0001 && layout != 0; /* mono : inutile */

    for (int i = 0; i < frames; i++) {
      double l = cv_sanitize_f(in[0][i]);
      double r = channels > 1 ? cv_sanitize_f(in[1][i]) : l;
      double m = (l + r) * 0.5;
      double s = (l - r) * 0.5 * width;
      l = m + s;
      r = m - s;

      if (do_cf) {
        /* Crossfeed : R retardé/filtré → L, et inversement. */
        sp->cf_line[0][(int)sp->cf_pos[0]] = r;
        sp->cf_line[1][(int)sp->cf_pos[1]] = l;
        double cr = cv_delay_read(sp->cf_line[0], 0, (int)sp->cf_pos[0], cf_delay);
        double cl = cv_delay_read(sp->cf_line[1], 0, (int)sp->cf_pos[1], cf_delay);
        cr = cv_biquad_tick(&sp->cf_lp[0], cr, ramp);
        cl = cv_biquad_tick(&sp->cf_lp[1], cl, ramp);
        l += cr * cf_gain;
        r += cl * cf_gain;
        sp->cf_pos[0] = fmod(sp->cf_pos[0] + 1.0, (double)CV_SPATIAL_MAX_DELAY);
        sp->cf_pos[1] = fmod(sp->cf_pos[1] + 1.0, (double)CV_SPATIAL_MAX_DELAY);
      }

      out[0][i] = (float)l;
      out[1][i] = (float)r;
    }
    return;
  }

  /* Chemin multicanal : downmix binaural fondu avec ITU. */
  if (sp->dirty || sp->channels != channels || sp->layout != layout) {
    cv_spatial_configure(sp, channels, layout);
  }
  double ramp = 1.0 - cv_onepole_coef(sp->sample_rate, 0.02);
  double amt = sp->mode >= CV_SPATIAL_MODE_BINAURAL ? sp->binaural_amount : 0.0;
  double itu = 1.0 - amt;

  for (int i = 0; i < frames; i++) {
    double itu_l = 0.0, itu_r = 0.0;
    double bin_l = 0.0, bin_r = 0.0;
    double lfe_l = 0.0, lfe_r = 0.0;

    for (int ch = 0; ch < channels; ch++) {
      double x = cv_sanitize_f(in[ch][i]);

      int is_lfe = (sp->layout >= 3 && ch == 3);
      if (is_lfe) {
        if (sp->lfe_gain_lin > 0.0) {
          lfe_l += x * sp->lfe_gain_lin;
          lfe_r += x * sp->lfe_gain_lin;
        }
        continue;
      }

      double az = cv_azimuth_for(sp->layout, ch);
      int right = az > 0.0;
      int center = sp->layout >= 3 && ch == 2;

      /* Voie ITU (BS.775). */
      double itu_x = x * sp->itu_mix[ch];
      if (center) {
        itu_l += itu_x;
        itu_r += itu_x;
      } else if (right) {
        itu_r += itu_x;
        itu_l += itu_x * 0.15;
      } else {
        itu_l += itu_x;
        itu_r += itu_x * 0.15;
      }

      if (amt > 0.0) {
        /* Signal coloré (amortissement arrière éventuel). */
        double xs = cv_biquad_tick(&sp->rear_muffle[ch], x, ramp);

        /* Ipsilatéral : gain + indice pinna. */
        double ipsi = cv_biquad_tick(&sp->front_peak[ch], xs * sp->bina_mix[ch], ramp);
        /* Controlatéral : ITD (délai fractionnaire) + ILD (shelf). */
        double contra = xs * (sp->bina_mix[ch] * 0.85);
        {
          int wpos = (int)sp->delay_pos[ch];
          sp->delay_line[ch][wpos] = contra;
        }
        contra = cv_delay_read(sp->delay_line[ch], 0, (int)sp->delay_pos[ch],
                               sp->contra_delay_smp[ch]);
        contra = cv_biquad_tick(&sp->contra_shelf[ch], contra, ramp);

        if (center) {
          bin_l += ipsi;
          bin_r += ipsi;
        } else if (right) {
          bin_r += ipsi;
          bin_l += contra;
        } else {
          bin_l += ipsi;
          bin_r += contra;
        }
        sp->delay_pos[ch] = fmod(sp->delay_pos[ch] + 1.0, (double)CV_SPATIAL_MAX_DELAY);
      }
    }

    out[0][i] = (float)(itu_l * itu + bin_l * amt + lfe_l);
    out[1][i] = (float)(itu_r * itu + bin_r * amt + lfe_r);
  }
}
