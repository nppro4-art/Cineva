#include "limiter.h"

#include <math.h>
#include <string.h>

#include "dsp_util.h"

void cv_limiter_init(cv_limiter *lm, double sample_rate) {
  memset(lm, 0, sizeof(*lm));
  lm->sample_rate = cv_clamp_d(sample_rate, 8000.0, 192000.0);
  lm->ceiling_db = -1.0;
  lm->lookahead_ms = 5.0;
  lm->release_ms = 120.0;
  lm->env_lin = 1.0;
  lm->current_gain = 1.0;
  cv_limiter_set(lm, 0, lm->ceiling_db, lm->lookahead_ms, lm->release_ms);
  lm->enable = 0;
}

void cv_limiter_set(cv_limiter *lm, int enable, double ceiling_db,
                    double lookahead_ms, double release_ms) {
  lm->enable = enable ? 1 : 0;
  lm->ceiling_db = cv_clamp_d(cv_sanitize_d(ceiling_db), -6.0, 0.0);
  lm->lookahead_ms = cv_clamp_d(cv_sanitize_d(lookahead_ms), 1.0, 10.0);
  lm->release_ms = cv_clamp_d(cv_sanitize_d(release_ms), 40.0, 500.0);
  lm->ceiling_lin = cv_db_to_lin(lm->ceiling_db);
  int d = (int)(lm->lookahead_ms * 0.001 * lm->sample_rate);
  if (d < 1) d = 1;
  if (d > CV_LIMITER_MAX_DELAY) d = CV_LIMITER_MAX_DELAY;
  if (d != lm->delay_smp) {
    lm->delay_smp = d;
    cv_limiter_reset(lm);
  }
  lm->att_coef = cv_onepole_coef(lm->sample_rate, lm->lookahead_ms / 1000.0 / 3.0);
  lm->rel_coef = cv_onepole_coef(lm->sample_rate, lm->release_ms / 1000.0);
}

void cv_limiter_reset(cv_limiter *lm) {
  memset(lm->delay, 0, sizeof(lm->delay));
  lm->pos = 0;
  lm->env_lin = 1.0;
  lm->current_gain = 1.0;
}

/* Crête sur-échantillonnée ×4 par interpolation Catmull-Rom. */
static inline double cv_limiter_tp4(double x0, double x1, double x2, double x3) {
  double a0 = -0.1875 * x0 + 0.5625 * x1 + 0.5625 * x2 - 0.1875 * x3;
  double a1 = -0.5 * x1 + 0.5 * x2;
  double a2 = 0.1875 * x0 - 0.75 * x1 + 0.75 * x2 - 0.1875 * x3;
  double c0 = x1;
  double c1 = a0 - 0.375 * a2 - c0;
  double c2 = 0.25 * a2 - 0.5 * a1;
  double peak = c0;
  if (fabs(c0) > peak) peak = fabs(c0);
  for (int k = 1; k <= 3; k++) {
    double t = (double)k * 0.25;
    double v = ((c2 * t + c1) * t + a1) * t + c0;
    double av = fabs(v);
    if (av > peak) peak = av;
  }
  (void)x3;
  return peak;
}

void cv_limiter_process(cv_limiter *lm, const float *const *in,
                        float *const *out, int frames) {
  if (!lm->enable) {
    if (out[0] != in[0]) memcpy(out[0], in[0], (size_t)frames * sizeof(float));
    if (out[1] != in[1]) memcpy(out[1], in[1], (size_t)frames * sizeof(float));
    return;
  }
  int d = lm->delay_smp;
  int len = CV_LIMITER_MAX_DELAY;

  for (int i = 0; i < frames; i++) {
    double l = cv_sanitize_f(in[0][i]);
    double r = cv_sanitize_f(in[1][i]);

    /* Crête true-peak ×4 sur les deux derniers + nouveaux échantillons. */
    int p = lm->pos;
    int im1 = (p + len - 1) % len;
    int im2 = (p + len - 2) % len;
    double lp0 = lm->delay[0][im2], lp1 = lm->delay[0][im1];
    double rp0 = lm->delay[1][im2], rp1 = lm->delay[1][im1];
    double peak = cv_limiter_tp4(lp0, lp1, l, l);
    double peak_r = cv_limiter_tp4(rp0, rp1, r, r);
    if (peak_r > peak) peak = peak_r;

    /* Écriture dans la ligne de délai. */
    lm->delay[0][p] = l;
    lm->delay[1][p] = r;

    /* Enveloppe : attaque immédiate (max), release exponentiel. */
    double need = 1.0;
    if (peak > lm->ceiling_lin) need = lm->ceiling_lin / peak;
    if (need < lm->env_lin) {
      lm->env_lin = need;
    } else {
      lm->env_lin = lm->rel_coef * lm->env_lin + (1.0 - lm->rel_coef) * need;
    }

    /* Gain appliqué : env lissé par l'attaque (couvre le lookahead). */
    double target = lm->env_lin;
    if (target < lm->current_gain) {
      lm->current_gain = lm->att_coef * lm->current_gain + (1.0 - lm->att_coef) * target;
      if (lm->current_gain < target) lm->current_gain = target;
    } else {
      lm->current_gain = lm->rel_coef * lm->current_gain + (1.0 - lm->rel_coef) * target;
    }

    /* Sortie : échantillon retardé. */
    int opos = (p + len - d) % len;
    out[0][i] = (float)(lm->delay[0][opos] * lm->current_gain);
    out[1][i] = (float)(lm->delay[1][opos] * lm->current_gain);

    lm->pos = (p + 1) % len;
  }
}

double cv_limiter_gain_db(const cv_limiter *lm) {
  return cv_lin_to_db(lm->current_gain);
}
