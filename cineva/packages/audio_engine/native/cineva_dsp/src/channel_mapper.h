/*
 * Channel Mapper — normalisation des dispositions d'entrée.
 *
 * Dispositions normalisées :
 *   0 mono   [L]
 *   1 stéréo [L, R]
 *   2 quad   [L, R, Ls, Rs]
 *   3 5.1    [L, R, C, LFE, Ls, Rs]
 *   4 7.1    [L, R, C, LFE, Ls, Rs, Lb, Rb]
 *
 * Fournit le downmix ITU-R BS.775 (utilisée quand la spatialisation est
 * désactivée, et comme base du fondu binaural).
 */
#ifndef CINEVA_DSP_CHANNEL_MAPPER_H
#define CINEVA_DSP_CHANNEL_MAPPER_H

#include "cineva_dsp.h"

/* Devine la disposition à partir du nombre de canaux. */
int cv_layout_from_channels(int channels);

/* Poids BS.1770 par canal pour la mesure de loudness (L/R/C = 1, Ls/Rs/Lb/Rb = √2). */
void cv_mapper_weights(int layout, int channels, double *weights /* [8] */);

/* Downmix ITU vers la stéréo. lfe_gain_lin = 0 ⇒ LFE ignoré (ITU). */
void cv_mapper_downmix_itu(const float *const *in, int channels, int layout,
                           float *const *out, double lfe_gain_lin, int frames);

#endif /* CINEVA_DSP_CHANNEL_MAPPER_H */
