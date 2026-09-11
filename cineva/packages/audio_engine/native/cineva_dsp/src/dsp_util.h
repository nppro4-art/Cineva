/* Utilitaires DSP partagés (interne). */
#ifndef CINEVA_DSP_UTIL_H
#define CINEVA_DSP_UTIL_H

#include <math.h>

#define CINEVA_PI 3.14159265358979323846

static inline double cv_clamp_d(double v, double lo, double hi) {
  if (!(v == v)) return lo; /* NaN */
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}

static inline float cv_clamp_f(float v, float lo, float hi) {
  if (!(v == v)) return lo;
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}

static inline double cv_db_to_lin(double db) { return pow(10.0, db / 20.0); }

static inline double cv_lin_to_db(double lin) {
  return 20.0 * log10(lin > 1e-12 ? lin : 1e-12);
}

/* Nettoie un échantillon : NaN/Inf → 0. */
static inline float cv_sanitize_f(float v) {
  if (v == v && v > -1e30f && v < 1e30f) return v;
  return 0.0f;
}

static inline double cv_sanitize_d(double v) {
  if (v == v && v > -1e30 && v < 1e30) return v;
  return 0.0;
}

/* Coefficient d'un filtre unipolaire avec constante de temps en secondes. */
static inline double cv_onepole_coef(double sample_rate, double tau_seconds) {
  if (tau_seconds <= 0.0 || sample_rate <= 0.0) return 0.0;
  return exp(-1.0 / (sample_rate * tau_seconds));
}

static inline double cv_max_d(double a, double b) { return a > b ? a : b; }
static inline double cv_min_d(double a, double b) { return a < b ? a : b; }

#endif /* CINEVA_DSP_UTIL_H */
