/* Harnais de test minimaliste (aucune dépendance externe). */
#ifndef CINEVA_DSP_TEST_UTIL_H
#define CINEVA_DSP_TEST_UTIL_H

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int cv_test_failures = 0;
static int cv_test_checks = 0;

#define CV_CHECK(cond, msg)                                                   \
  do {                                                                        \
    cv_test_checks++;                                                         \
    if (!(cond)) {                                                            \
      cv_test_failures++;                                                     \
      printf("  ÉCHEC [%s:%d] %s\n", __FILE__, __LINE__, msg);                \
    }                                                                         \
  } while (0)

#define CV_CHECK_NEAR(a, b, tol, msg)                                         \
  do {                                                                        \
    cv_test_checks++;                                                         \
    double _a = (double)(a), _b = (double)(b), _d = _a - _b;                  \
    if (_d < 0) _d = -_d;                                                     \
    if (!(_d <= (tol))) {                                                     \
      cv_test_failures++;                                                     \
      printf("  ÉCHEC [%s:%d] %s (%.9g vs %.9g, tol %.3g)\n", __FILE__,       \
             __LINE__, msg, _a, _b, (double)(tol));                           \
    }                                                                         \
  } while (0)

/* Générateur pseudo-aléatoire déterministe (xorshift64). */
static unsigned long long cv_rng_state = 88172645463325252ULL;
static inline unsigned long long cv_rng_next(void) {
  unsigned long long x = cv_rng_state;
  x ^= x << 13;
  x ^= x >> 7;
  x ^= x << 17;
  cv_rng_state = x;
  return x;
}
static inline double cv_rng_uniform(void) {
  return (double)(cv_rng_next() >> 11) / 9007199254740992.0;
}

static inline double cv_sine_amp(double freq, double sample_rate, int i) {
  return sin(2.0 * 3.14159265358979323846 * freq * (double)i / sample_rate);
}

static inline int cv_all_finite(const float *buf, int n) {
  for (int i = 0; i < n; i++) {
    if (!(buf[i] == buf[i] && buf[i] > -1e30f && buf[i] < 1e30f)) return 0;
  }
  return 1;
}

static inline double cv_peak_abs(const float *buf, int n) {
  double p = 0.0;
  for (int i = 0; i < n; i++) {
    double a = fabs((double)buf[i]);
    if (a > p) p = a;
  }
  return p;
}

static inline double cv_rms(const float *buf, int n) {
  double s = 0.0;
  for (int i = 0; i < n; i++) s += (double)buf[i] * (double)buf[i];
  return n > 0 ? sqrt(s / (double)n) : 0.0;
}

#endif /* CINEVA_DSP_TEST_UTIL_H */
