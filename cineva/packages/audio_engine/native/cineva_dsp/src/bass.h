/*
 * Bass Processor — basses profondes mais contrôlées.
 *
 * Crossover Linkwitz-Riley 4ᵉ ordre, shelf sub-bass piloté par l'intensité,
 * extension harmonique douce (mode petit haut-parleur), fusion LFE,
 * limiteur de bande bas rapide, recombinaison phase-alignée.
 */
#ifndef CINEVA_DSP_BASS_H
#define CINEVA_DSP_BASS_H

#include "biquad.h"

typedef struct {
  int enable;
  double intensity;          /* 0..1 */
  double crossover_hz;
  int speaker_mode;          /* 0 full, 1 small, 2 headphone */
  double sub_shelf_gain_db;
  double harmonic_drive;     /* 0..1 */
  double lfe_gain_db;

  double sample_rate;
  cv_biquad lp[2][2];  /* LR4 : 2 étages × 2 canaux */
  cv_biquad hp[2][2];
  cv_biquad sub_shelf[2];
  cv_biquad harm_hp[2]; /* filtre des harmoniques générées */
  double band_env;      /* enveloppe du limiteur de bande */
  double band_thr_lin;
  int dirty;
} cv_bass;

void cv_bass_init(cv_bass *bs, double sample_rate);
void cv_bass_set(cv_bass *bs, int enable, double intensity_percent,
                 double crossover_hz, int speaker_mode,
                 double sub_shelf_gain_db, double harmonic_drive_percent,
                 double lfe_gain_db);
void cv_bass_reset(cv_bass *bs);

/* Traite une paire stéréo. lfe : tampon LFE optionnel (peut être NULL),
 * mélangé dans la voie basse avant le limiteur de bande. */
void cv_bass_process(cv_bass *bs, float *const *io, const float *lfe,
                     int frames);

#endif /* CINEVA_DSP_BASS_H */
