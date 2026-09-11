/* Biquad RBJ (transposed direct form II, double), coefficients interpolés. */
#ifndef CINEVA_DSP_BIQUAD_H
#define CINEVA_DSP_BIQUAD_H

typedef enum {
  CV_BQ_LOWSHELF = 0,
  CV_BQ_PEAKING = 1,
  CV_BQ_HIGHSHELF = 2,
  CV_BQ_LOWPASS = 3,
  CV_BQ_HIGHPASS = 4,
} cv_biquad_type;

typedef struct {
  double b0, b1, b2, a1, a2; /* coefficients courants */
  double tb0, tb1, tb2, ta1, ta2; /* coefficients cibles */
  double s1, s2; /* état TDF2 */
  int ramp; /* 1 tant que courants != cibles */
} cv_biquad;

/* Initialise à l'identité. */
void cv_biquad_init(cv_biquad *bq);

/* Calcule les coefficients RBJ et les fixe comme cible (ramp ~20 ms). */
void cv_biquad_set(cv_biquad *bq, int type, double freq_hz, double gain_db,
                   double q, double sample_rate);

/* Fixe directement les coefficients cibles. */
void cv_biquad_set_raw(cv_biquad *bq, double b0, double b1, double b2,
                       double a1, double a2);

/* Filtre un échantillon (interpolation des coefficients si nécessaire). */
static inline double cv_biquad_tick(cv_biquad *bq, double x, double ramp_coef) {
  if (bq->ramp) {
    bq->b0 += (bq->tb0 - bq->b0) * ramp_coef;
    bq->b1 += (bq->tb1 - bq->b1) * ramp_coef;
    bq->b2 += (bq->tb2 - bq->b2) * ramp_coef;
    bq->a1 += (bq->ta1 - bq->a1) * ramp_coef;
    bq->a2 += (bq->ta2 - bq->a2) * ramp_coef;
    double e0 = bq->b0 - bq->tb0, e1 = bq->b1 - bq->tb1, e2 = bq->b2 - bq->tb2;
    double e3 = bq->a1 - bq->ta1, e4 = bq->a2 - bq->ta2;
    if (e0 * e0 + e1 * e1 + e2 * e2 + e3 * e3 + e4 * e4 < 1e-18) {
      bq->b0 = bq->tb0; bq->b1 = bq->tb1; bq->b2 = bq->tb2;
      bq->a1 = bq->ta1; bq->a2 = bq->ta2;
      bq->ramp = 0;
    }
  }
  double y = bq->b0 * x + bq->s1;
  bq->s1 = bq->b1 * x - bq->a1 * y + bq->s2;
  bq->s2 = bq->b2 * x - bq->a2 * y;
  return y;
}

void cv_biquad_reset_state(cv_biquad *bq);

/* Met immédiatement les coefficients cibles dans les coefficients courants. */
void cv_biquad_snap(cv_biquad *bq);

#endif /* CINEVA_DSP_BIQUAD_H */
