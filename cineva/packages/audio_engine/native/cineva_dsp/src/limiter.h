/*
 * Limiteur true-peak lookahead.
 * Détection de crête sur-échantillonnée ×4 (interpolation Catmull-Rom),
 * enveloppe avec attaque couvrant le lookahead, release configurable.
 */
#ifndef CINEVA_DSP_LIMITER_H
#define CINEVA_DSP_LIMITER_H

#define CV_LIMITER_MAX_DELAY 4096 /* 10 ms @ 384 kHz */

typedef struct {
  int enable;
  double ceiling_db;
  double lookahead_ms;
  double release_ms;

  double sample_rate;
  double ceiling_lin;
  int delay_smp;
  double delay[2][CV_LIMITER_MAX_DELAY];
  int pos;
  double env_lin;      /* atténuation instantanée (1 = rien) */
  double att_coef;     /* lissage d'attaque ≈ lookahead/3 */
  double rel_coef;
  double current_gain; /* gain appliqué (pour métriques) */
} cv_limiter;

void cv_limiter_init(cv_limiter *lm, double sample_rate);
void cv_limiter_set(cv_limiter *lm, int enable, double ceiling_db,
                    double lookahead_ms, double release_ms);
void cv_limiter_reset(cv_limiter *lm);

/* io : entrée modifiée en place vers out (out peut être != io). */
void cv_limiter_process(cv_limiter *lm, const float *const *in,
                        float *const *out, int frames);
double cv_limiter_gain_db(const cv_limiter *lm);

#endif /* CINEVA_DSP_LIMITER_H */
