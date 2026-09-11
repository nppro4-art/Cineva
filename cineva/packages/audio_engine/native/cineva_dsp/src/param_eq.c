#include "param_eq.h"

#include <string.h>

#include "dsp_util.h"

void cv_param_eq_init(cv_param_eq *eq, double sample_rate) {
  memset(eq, 0, sizeof(*eq));
  eq->sample_rate = cv_clamp_d(sample_rate, 8000.0, 192000.0);
  static const double def_freq[CV_EQ_BANDS] = {45.0, 90.0, 300.0, 1200.0, 3500.0, 10000.0};
  static const int def_type[CV_EQ_BANDS] = {CV_BQ_LOWSHELF, CV_BQ_PEAKING, CV_BQ_PEAKING,
                                            CV_BQ_PEAKING, CV_BQ_PEAKING, CV_BQ_HIGHSHELF};
  for (int i = 0; i < CV_EQ_BANDS; i++) {
    eq->types[i] = def_type[i];
    eq->freq[i] = def_freq[i];
    eq->q[i] = 0.9;
    for (int ch = 0; ch < 2; ch++) cv_biquad_init(&eq->bands[i][ch]);
  }
  eq->dirty = 1;
}

void cv_param_eq_set(cv_param_eq *eq, int enable, const int *types,
                     const double *freq, const double *gain_db, const double *q) {
  eq->enable = enable ? 1 : 0;
  if (types && freq && gain_db && q) {
    for (int i = 0; i < CV_EQ_BANDS; i++) {
      int t = types[i];
      if (t < CV_BQ_LOWSHELF || t > CV_BQ_HIGHPASS) t = CV_BQ_PEAKING;
      double f = cv_clamp_d(cv_sanitize_d(freq[i]), 20.0, 20000.0);
      double g = cv_clamp_d(cv_sanitize_d(gain_db[i]), -15.0, 15.0);
      double qq = cv_clamp_d(cv_sanitize_d(q[i]), 0.3, 4.0);
      if (t != eq->types[i] || f != eq->freq[i] || g != eq->gain_db[i] || qq != eq->q[i]) {
        eq->types[i] = t;
        eq->freq[i] = f;
        eq->gain_db[i] = g;
        eq->q[i] = qq;
        eq->dirty = 1;
      }
    }
  }
}

void cv_param_eq_reset(cv_param_eq *eq) {
  for (int i = 0; i < CV_EQ_BANDS; i++) {
    cv_biquad_reset_state(&eq->bands[i][0]);
    cv_biquad_reset_state(&eq->bands[i][1]);
  }
}

void cv_param_eq_process(cv_param_eq *eq, float *const *io, int channels,
                         int frames) {
  if (!eq->enable) return;
  if (channels < 1 || channels > 2) return;
  if (eq->dirty) {
    for (int i = 0; i < CV_EQ_BANDS; i++) {
      for (int ch = 0; ch < 2; ch++) {
        cv_biquad_set(&eq->bands[i][ch], eq->types[i], eq->freq[i], eq->gain_db[i],
                      eq->q[i], eq->sample_rate);
      }
    }
    eq->dirty = 0;
  }
  double ramp = 1.0 - cv_onepole_coef(eq->sample_rate, 0.02);
  for (int i = 0; i < frames; i++) {
    double l = cv_sanitize_f(io[0][i]);
    double r = channels > 1 ? cv_sanitize_f(io[1][i]) : l;
    for (int b = 0; b < CV_EQ_BANDS; b++) {
      l = cv_biquad_tick(&eq->bands[b][0], l, ramp);
      r = cv_biquad_tick(&eq->bands[b][1], r, ramp);
    }
    io[0][i] = (float)l;
    if (channels > 1) io[1][i] = (float)r;
  }
}
