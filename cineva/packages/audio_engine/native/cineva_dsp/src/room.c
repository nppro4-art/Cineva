#include "room.h"

#include <math.h>
#include <string.h>

#include "dsp_util.h"

void cv_room_init(cv_room *rm, double sample_rate) {
  memset(rm, 0, sizeof(*rm));
  rm->sample_rate = cv_clamp_d(sample_rate, 8000.0, 192000.0);
  static const double tap_ms[CV_ROOM_TAPS] = {4.8, 9.1, 13.7, 18.3, 23.6, 29.2, 33.8, 38.4};
  static const double tap_db[CV_ROOM_TAPS] = {-16.0, -19.0, -21.0, -23.0, -25.0, -26.5, -28.0, -29.5};
  for (int t = 0; t < CV_ROOM_TAPS; t++) {
    rm->delay_smp[t] = tap_ms[t] * 0.001 * rm->sample_rate;
    rm->gain[t] = cv_db_to_lin(tap_db[t]);
    cv_biquad_init(&rm->lp[t]);
    /* Les taps plus lointains sont plus sourds (absorption). */
    double lp_hz = 3200.0 - t * 250.0;
    cv_biquad_set(&rm->lp[t], CV_BQ_LOWPASS, lp_hz, 0.0, 0.707, rm->sample_rate);
    cv_biquad_snap(&rm->lp[t]);
  }
}

void cv_room_set(cv_room *rm, int enable, double wet_percent, double size_percent) {
  rm->enable = enable ? 1 : 0;
  rm->wet = cv_clamp_d(cv_sanitize_d(wet_percent), 0.0, 15.0) / 100.0;
  rm->size = cv_clamp_d(cv_sanitize_d(size_percent), 50.0, 150.0) / 100.0;
}

void cv_room_reset(cv_room *rm) {
  for (int t = 0; t < CV_ROOM_TAPS; t++) cv_biquad_reset_state(&rm->lp[t]);
  memset(rm->line, 0, sizeof(rm->line));
  rm->pos = 0.0;
}

void cv_room_process(cv_room *rm, float *const *io, int frames) {
  if (!rm->enable || rm->wet <= 0.0) return;
  double ramp = 1.0 - cv_onepole_coef(rm->sample_rate, 0.02);
  int len = CV_ROOM_MAX_DELAY;
  double wet_gain = rm->wet * 4.0; /* normalisation douce (somme des taps ≈ 0.25) */
  double dry_gain = 1.0 - rm->wet * 1.5; /* très légère compensation */

  for (int i = 0; i < frames; i++) {
    double l = cv_sanitize_f(io[0][i]);
    double r = cv_sanitize_f(io[1][i]);

    int wpos = (int)rm->pos;
    rm->line[0][wpos] = l;
    rm->line[1][wpos] = r;

    double wet_l = 0.0, wet_r = 0.0;
    for (int t = 0; t < CV_ROOM_TAPS; t++) {
      double d = rm->delay_smp[t] * rm->size;
      if (d >= (double)len) d = (double)len - 1.0;
      double read = (double)wpos - d;
      if (read < 0.0) read += (double)len;
      int i0 = (int)read;
      double frac = read - (double)i0;
      int i1 = i0 - 1;
      if (i1 < 0) i1 += len;
      double src_l = rm->line[0][i0] + (rm->line[0][i1] - rm->line[0][i0]) * frac;
      double src_r = rm->line[1][i0] + (rm->line[1][i1] - rm->line[1][i0]) * frac;

      double tap = cv_biquad_tick(&rm->lp[t], (src_l + src_r) * 0.5, ramp);
      /* Ping-pong : taps alternés renvoyés côté opposé (largeur). */
      if ((t & 1) == 0) {
        wet_l += tap * rm->gain[t] * 0.75;
        wet_r += tap * rm->gain[t];
      } else {
        wet_l += tap * rm->gain[t];
        wet_r += tap * rm->gain[t] * 0.75;
      }
    }

    io[0][i] = (float)(l * dry_gain + wet_l * wet_gain);
    io[1][i] = (float)(r * dry_gain + wet_r * wet_gain);

    rm->pos = fmod(rm->pos + 1.0, (double)len);
  }
}
