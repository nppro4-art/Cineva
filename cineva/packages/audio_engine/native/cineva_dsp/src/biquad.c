#include "biquad.h"

#include <math.h>

#include "dsp_util.h"

void cv_biquad_init(cv_biquad *bq) {
  bq->b0 = 1.0; bq->b1 = 0.0; bq->b2 = 0.0; bq->a1 = 0.0; bq->a2 = 0.0;
  bq->tb0 = 1.0; bq->tb1 = 0.0; bq->tb2 = 0.0; bq->ta1 = 0.0; bq->ta2 = 0.0;
  bq->s1 = 0.0; bq->s2 = 0.0;
  bq->ramp = 0;
}

void cv_biquad_reset_state(cv_biquad *bq) {
  bq->s1 = 0.0;
  bq->s2 = 0.0;
}

void cv_biquad_snap(cv_biquad *bq) {
  bq->b0 = bq->tb0; bq->b1 = bq->tb1; bq->b2 = bq->tb2;
  bq->a1 = bq->ta1; bq->a2 = bq->ta2;
  bq->ramp = 0;
}

void cv_biquad_set_raw(cv_biquad *bq, double b0, double b1, double b2,
                       double a1, double a2) {
  bq->tb0 = b0; bq->tb1 = b1; bq->tb2 = b2; bq->ta1 = a1; bq->ta2 = a2;
  bq->ramp = 1;
}

void cv_biquad_set(cv_biquad *bq, int type, double freq_hz, double gain_db,
                   double q, double sample_rate) {
  double fs = sample_rate > 0.0 ? sample_rate : 48000.0;
  double f0 = cv_clamp_d(freq_hz, 10.0, fs * 0.49);
  double Q = cv_clamp_d(q, 0.1, 20.0);
  double A = pow(10.0, cv_clamp_d(gain_db, -40.0, 40.0) / 40.0);
  double w0 = 2.0 * CINEVA_PI * f0 / fs;
  double cw = cos(w0);
  double sw = sin(w0);
  double alpha = sw / (2.0 * Q);

  double b0 = 1.0, b1 = 0.0, b2 = 0.0, a0 = 1.0, a1 = 0.0, a2 = 0.0;

  switch (type) {
    case CV_BQ_LOWSHELF: {
      double sqA = 2.0 * sqrt(A) * alpha;
      b0 = A * ((A + 1.0) - (A - 1.0) * cw + sqA);
      b1 = 2.0 * A * ((A - 1.0) - (A + 1.0) * cw);
      b2 = A * ((A + 1.0) - (A - 1.0) * cw - sqA);
      a0 = (A + 1.0) + (A - 1.0) * cw + sqA;
      a1 = -2.0 * ((A - 1.0) + (A + 1.0) * cw);
      a2 = (A + 1.0) + (A - 1.0) * cw - sqA;
      break;
    }
    case CV_BQ_HIGHSHELF: {
      double sqA = 2.0 * sqrt(A) * alpha;
      b0 = A * ((A + 1.0) + (A - 1.0) * cw + sqA);
      b1 = -2.0 * A * ((A - 1.0) + (A + 1.0) * cw);
      b2 = A * ((A + 1.0) + (A - 1.0) * cw - sqA);
      a0 = (A + 1.0) - (A - 1.0) * cw + sqA;
      a1 = 2.0 * ((A - 1.0) - (A + 1.0) * cw);
      a2 = (A + 1.0) - (A - 1.0) * cw - sqA;
      break;
    }
    case CV_BQ_LOWPASS: {
      b0 = (1.0 - cw) * 0.5;
      b1 = 1.0 - cw;
      b2 = (1.0 - cw) * 0.5;
      a0 = 1.0 + alpha;
      a1 = -2.0 * cw;
      a2 = 1.0 - alpha;
      break;
    }
    case CV_BQ_HIGHPASS: {
      b0 = (1.0 + cw) * 0.5;
      b1 = -(1.0 + cw);
      b2 = (1.0 + cw) * 0.5;
      a0 = 1.0 + alpha;
      a1 = -2.0 * cw;
      a2 = 1.0 - alpha;
      break;
    }
    case CV_BQ_PEAKING:
    default: {
      b0 = 1.0 + alpha * A;
      b1 = -2.0 * cw;
      b2 = 1.0 - alpha * A;
      a0 = 1.0 + alpha / A;
      a1 = -2.0 * cw;
      a2 = 1.0 - alpha / A;
      break;
    }
  }

  if (!(a0 > 0.0) || !(a0 == a0)) a0 = 1.0;
  cv_biquad_set_raw(bq, b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
}
