/* Normalisation de loudness ITU-R BS.1770-4 (mesure K + gain adaptatif). */
#ifndef CINEVA_DSP_LOUDNESS_H
#define CINEVA_DSP_LOUDNESS_H

#include "biquad.h"
#include "cineva_dsp.h"

#define CV_LOUDNESS_HOPS 600   /* historique : 600 blocs de 100 ms = 60 s */
#define CV_LOUDNESS_SILENCE_BLOCKS 10

typedef struct {
  int enable;
  double target_lufs;
  double max_gain_db;
  double max_att_db;
  double adapt_rate_db_s;

  double sample_rate;
  int hop_len;         /* échantillons par bloc de 100 ms */
  int hop_pos;         /* position dans le bloc courant */
  double hop_ms[CINEVA_DSP_MAX_CHANNELS]; /* somme des carrés par canal */

  cv_biquad k1[CINEVA_DSP_MAX_CHANNELS]; /* shelf +4 dB */
  cv_biquad k2[CINEVA_DSP_MAX_CHANNELS]; /* high-pass RLB */

  double hop_z[CV_LOUDNESS_HOPS]; /* z (puissance de bloc) récents */
  int hop_count;                  /* nombre de blocs valides dans l'historique */
  int hop_head;                   /* index d'écriture */
  int silent_run;                 /* blocs silencieux consécutifs */

  double integrated_lufs;
  double gain_db;    /* gain appliqué actuellement */
  double target_gain_db;
} cv_loudness;

void cv_loudness_init(cv_loudness *ln, double sample_rate);
void cv_loudness_set(cv_loudness *ln, int enable, double target_lufs,
                     double max_gain_db, double max_att_db,
                     double adapt_rate_db_s);
void cv_loudness_reset(cv_loudness *ln);

/* weights : poids BS.1770 par canal (L/R/C = 1.0, Ls/Rs = 1.414…). */
void cv_loudness_process(cv_loudness *ln, const float *const *in,
                         float *const *out, int channels, int frames,
                         const double *weights);

double cv_loudness_integrated(const cv_loudness *ln);
double cv_loudness_gain_db(const cv_loudness *ln);

#endif /* CINEVA_DSP_LOUDNESS_H */
