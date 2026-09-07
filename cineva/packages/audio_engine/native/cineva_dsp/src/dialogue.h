/*
 * Dialogue Enhancer — intelligibilité vocale sans boost brutal des médiums.
 *
 * Stéréo : décomposition M/S ; boost de présence (1.2–4.5 kHz) sur le mid,
 * atténuation légère du bas-médian masquant (200–350 Hz), réduction subtile
 * du side dans la bande de présence (séparation voix/ambiance).
 * Multicanal : en plus, boost de présence du canal centre et légère
 * atténuation du bas-médian sur L/R.
 */
#ifndef CINEVA_DSP_DIALOGUE_H
#define CINEVA_DSP_DIALOGUE_H

#include "biquad.h"

typedef struct {
  int enable;
  double intensity; /* 0..1 */

  double sample_rate;
  /* Bande présence sur M (et C) : HP 1.2 kHz + LP 4.5 kHz. */
  cv_biquad hp_mid[2];
  cv_biquad lp_mid[2];
  /* Bande présence sur S. */
  cv_biquad hp_side[2];
  cv_biquad lp_side[2];
  /* Bas-médian masquant sur M (et L/R multicanal) : BP 200–350 Hz. */
  cv_biquad hp_mud[2];
  cv_biquad lp_mud[2];
  /* Bande présence du canal centre (multicanal). */
  cv_biquad hp_c;
  cv_biquad lp_c;
  cv_biquad hp_mud_lr[2];
  cv_biquad lp_mud_lr[2];
} cv_dialogue;

void cv_dialogue_init(cv_dialogue *dg, double sample_rate);
void cv_dialogue_set(cv_dialogue *dg, int enable, double intensity_percent);
void cv_dialogue_reset(cv_dialogue *dg);

/* in/out : bus moteur (1..8 canaux). layout_channels : nombre de canaux
 * réellement présents (>=3 ⇒ multicanal avec centre en index 2 ? non :
 * dispositions normalisées par le channel mapper). */
void cv_dialogue_process(cv_dialogue *dg, float *const *io, int channels,
                         int layout, int frames);

#endif /* CINEVA_DSP_DIALOGUE_H */
