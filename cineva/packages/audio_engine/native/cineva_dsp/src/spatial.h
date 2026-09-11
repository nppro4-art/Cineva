/*
 * Spatial Processor.
 *
 * - Multicanal → stéréo/casque : downmix binaural (ILD par filtres shelf,
 *   ITD par délai fractionnaire, coloration frontale/arrière, indice pinna)
 *   fondu avec le downmix ITU-R BS.775 selon binauralAmount.
 * - Stéréo : élargissement M/S contrôlé (aucun upmix artificiel).
 * - Crossfeed casque : copie controlatérale retardée (0.25 ms) et filtrée.
 *
 * Positions (degrés) : L -30, R +30, C 0, Ls -105, Rs +105, Lb -140, Rb +140.
 */
#ifndef CINEVA_DSP_SPATIAL_H
#define CINEVA_DSP_SPATIAL_H

#include "biquad.h"
#include "cineva_dsp.h"

#define CV_SPATIAL_MODE_OFF 0
#define CV_SPATIAL_MODE_WIDTH 1
#define CV_SPATIAL_MODE_BINAURAL 2
#define CV_SPATIAL_MODE_BINAURAL_CROSSFEED 3

#define CV_SPATIAL_MAX_DELAY 512 /* échantillons ; 0.002 s @ 256 kHz max */

typedef struct {
  int enable;
  int mode;
  double width;           /* 0..1.5 */
  double crossfeed;       /* 0..1 */
  double binaural_amount; /* 0..1 */

  double sample_rate;
  int channels;
  int layout;

  /* Chaînes binaurales par canal source. */
  cv_biquad contra_shelf[CINEVA_DSP_MAX_CHANNELS]; /* ILD contralatéral */
  cv_biquad rear_muffle[CINEVA_DSP_MAX_CHANNELS];  /* amortissement arrière */
  cv_biquad front_peak[CINEVA_DSP_MAX_CHANNELS];   /* indice pinna avant */
  double delay_line[CINEVA_DSP_MAX_CHANNELS][CV_SPATIAL_MAX_DELAY];
  double delay_pos[CINEVA_DSP_MAX_CHANNELS];
  double contra_delay_smp[CINEVA_DSP_MAX_CHANNELS];

  /* Crossfeed. */
  double cf_line[2][CV_SPATIAL_MAX_DELAY];
  double cf_pos[2];
  cv_biquad cf_lp[2];

  double itu_mix[CINEVA_DSP_MAX_CHANNELS];   /* gains ITU L */
  double bina_mix[CINEVA_DSP_MAX_CHANNELS];  /* gains binauraux ipsi */
  int ch_is_rear[CINEVA_DSP_MAX_CHANNELS];
  int ch_has_contra[CINEVA_DSP_MAX_CHANNELS];
  double lfe_gain_lin;
  int dirty;
} cv_spatial;

void cv_spatial_init(cv_spatial *sp, double sample_rate);
void cv_spatial_set(cv_spatial *sp, int enable, int mode, double width_percent,
                    double crossfeed_percent, double binaural_amount_percent);
void cv_spatial_reset(cv_spatial *sp);

/* layout/channels : entrée normalisée par le channel mapper.
 * lfe_gain_lin : gain d'injection LFE dans le downmix (0 = ignoré,
 * le bass management s'en charge). out doit être un tampon stéréo distinct. */
void cv_spatial_process(cv_spatial *sp, const float *const *in, int channels,
                        int layout, float *const *out, double lfe_gain_lin,
                        int frames);

#endif /* CINEVA_DSP_SPATIAL_H */
