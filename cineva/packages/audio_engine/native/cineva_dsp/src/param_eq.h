/* Égaliseur paramétrique 6 bandes (biquads RBJ, interpolation continue). */
#ifndef CINEVA_DSP_PARAM_EQ_H
#define CINEVA_DSP_PARAM_EQ_H

#include "biquad.h"

#define CV_EQ_BANDS 6

typedef struct {
  int enable;
  int types[CV_EQ_BANDS];     /* cv_biquad_type */
  double freq[CV_EQ_BANDS];
  double gain_db[CV_EQ_BANDS];
  double q[CV_EQ_BANDS];

  cv_biquad bands[CV_EQ_BANDS][2]; /* [bande][canal] */
  double sample_rate;
  int dirty;
} cv_param_eq;

void cv_param_eq_init(cv_param_eq *eq, double sample_rate);
void cv_param_eq_set(cv_param_eq *eq, int enable, const int *types,
                     const double *freq, const double *gain_db, const double *q);
void cv_param_eq_reset(cv_param_eq *eq);
void cv_param_eq_process(cv_param_eq *eq, float *const *io, int channels,
                         int frames);

#endif /* CINEVA_DSP_PARAM_EQ_H */
