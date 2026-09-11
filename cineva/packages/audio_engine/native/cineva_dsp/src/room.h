/*
 * Room / Cinema Effect — réflexions précoces uniquement, mix wet très faible.
 * 8 taps ping-pong (4–38 ms), filtrés passe-bas, jamais de queue de réverbération.
 */
#ifndef CINEVA_DSP_ROOM_H
#define CINEVA_DSP_ROOM_H

#include "biquad.h"

#define CV_ROOM_TAPS 8
#define CV_ROOM_MAX_DELAY 8192 /* échantillons (38 ms * 1.5 @ 192 kHz ≈ 11000 → 16384) */

typedef struct {
  int enable;
  double wet;   /* 0..0.15 */
  double size;  /* 0.5..1.5 */

  double sample_rate;
  double delay_smp[CV_ROOM_TAPS];
  double gain[CV_ROOM_TAPS];
  cv_biquad lp[CV_ROOM_TAPS];
  double line[2][CV_ROOM_MAX_DELAY];
  double pos;
} cv_room;

void cv_room_init(cv_room *rm, double sample_rate);
void cv_room_set(cv_room *rm, int enable, double wet_percent, double size_percent);
void cv_room_reset(cv_room *rm);
void cv_room_process(cv_room *rm, float *const *io, int frames);

#endif /* CINEVA_DSP_ROOM_H */
