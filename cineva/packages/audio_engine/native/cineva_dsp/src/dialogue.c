#include "dialogue.h"

#include <string.h>

#include "dsp_util.h"

/* Dispositions normalisées (voir channel_mapper.h) :
 * mono [L] ; stéréo [L,R] ; quad [L,R,Ls,Rs] ;
 * 5.1 [L,R,C,LFE,Ls,Rs] ; 7.1 [L,R,C,LFE,Ls,Rs,Lb,Rb]. */
#define CV_LAYOUT_5_1_CENTER 2

void cv_dialogue_init(cv_dialogue *dg, double sample_rate) {
  memset(dg, 0, sizeof(*dg));
  dg->sample_rate = cv_clamp_d(sample_rate, 8000.0, 192000.0);
  double sr = dg->sample_rate;
  for (int i = 0; i < 2; i++) {
    cv_biquad_init(&dg->hp_mid[i]);
    cv_biquad_init(&dg->lp_mid[i]);
    cv_biquad_init(&dg->hp_side[i]);
    cv_biquad_init(&dg->lp_side[i]);
    cv_biquad_init(&dg->hp_mud[i]);
    cv_biquad_init(&dg->lp_mud[i]);
    cv_biquad_init(&dg->hp_mud_lr[i]);
    cv_biquad_init(&dg->lp_mud_lr[i]);
    cv_biquad_set(&dg->hp_mid[i], CV_BQ_HIGHPASS, 1200.0, 0.0, 0.707, sr);
    cv_biquad_set(&dg->lp_mid[i], CV_BQ_LOWPASS, 4500.0, 0.0, 0.707, sr);
    cv_biquad_set(&dg->hp_side[i], CV_BQ_HIGHPASS, 1200.0, 0.0, 0.707, sr);
    cv_biquad_set(&dg->lp_side[i], CV_BQ_LOWPASS, 4500.0, 0.0, 0.707, sr);
    cv_biquad_set(&dg->hp_mud[i], CV_BQ_HIGHPASS, 200.0, 0.0, 0.707, sr);
    cv_biquad_set(&dg->lp_mud[i], CV_BQ_LOWPASS, 350.0, 0.0, 0.707, sr);
    cv_biquad_set(&dg->hp_mud_lr[i], CV_BQ_HIGHPASS, 200.0, 0.0, 0.707, sr);
    cv_biquad_set(&dg->lp_mud_lr[i], CV_BQ_LOWPASS, 350.0, 0.0, 0.707, sr);
    cv_biquad_snap(&dg->hp_mid[i]);
    cv_biquad_snap(&dg->lp_mid[i]);
    cv_biquad_snap(&dg->hp_side[i]);
    cv_biquad_snap(&dg->lp_side[i]);
    cv_biquad_snap(&dg->hp_mud[i]);
    cv_biquad_snap(&dg->lp_mud[i]);
    cv_biquad_snap(&dg->hp_mud_lr[i]);
    cv_biquad_snap(&dg->lp_mud_lr[i]);
  }
  cv_biquad_init(&dg->hp_c);
  cv_biquad_init(&dg->lp_c);
  cv_biquad_set(&dg->hp_c, CV_BQ_HIGHPASS, 1200.0, 0.0, 0.707, sr);
  cv_biquad_set(&dg->lp_c, CV_BQ_LOWPASS, 4500.0, 0.0, 0.707, sr);
  cv_biquad_snap(&dg->hp_c);
  cv_biquad_snap(&dg->lp_c);
}

void cv_dialogue_set(cv_dialogue *dg, int enable, double intensity_percent) {
  dg->enable = enable ? 1 : 0;
  dg->intensity = cv_clamp_d(cv_sanitize_d(intensity_percent), 0.0, 100.0) / 100.0;
}

void cv_dialogue_reset(cv_dialogue *dg) {
  cv_biquad_reset_state(&dg->hp_c);
  cv_biquad_reset_state(&dg->lp_c);
  for (int i = 0; i < 2; i++) {
    cv_biquad_reset_state(&dg->hp_mid[i]);
    cv_biquad_reset_state(&dg->lp_mid[i]);
    cv_biquad_reset_state(&dg->hp_side[i]);
    cv_biquad_reset_state(&dg->lp_side[i]);
    cv_biquad_reset_state(&dg->hp_mud[i]);
    cv_biquad_reset_state(&dg->lp_mud[i]);
    cv_biquad_reset_state(&dg->hp_mud_lr[i]);
    cv_biquad_reset_state(&dg->lp_mud_lr[i]);
  }
}

void cv_dialogue_process(cv_dialogue *dg, float *const *io, int channels,
                         int layout, int frames) {
  if (!dg->enable || dg->intensity <= 0.0) return;
  if (channels < 1 || frames <= 0) return;
  double ramp = 1.0 - cv_onepole_coef(dg->sample_rate, 0.02);
  double amt = dg->intensity;

  /* Boost de présence max +4 dB, dip bas-médian max -2 dB, dip side -1.5 dB. */
  double presence_add = (cv_db_to_lin(4.0) - 1.0) * amt;
  double mud_sub = (1.0 - cv_db_to_lin(-2.0)) * amt;
  double side_sub = (1.0 - cv_db_to_lin(-1.5)) * amt;

  int multichannel = (layout >= 3) && channels >= 6; /* 5.1 / 7.1 */

  for (int i = 0; i < frames; i++) {
    if (multichannel) {
      /* Centre : boost de présence (voix). */
      double c = cv_sanitize_f(io[CV_LAYOUT_5_1_CENTER][i]);
      double cp = cv_biquad_tick(&dg->hp_c, c, ramp);
      cp = cv_biquad_tick(&dg->lp_c, cp, ramp);
      io[CV_LAYOUT_5_1_CENTER][i] = (float)(c + cp * presence_add);
      /* L/R : léger retrait du bas-médian concurrent. */
      for (int ch = 0; ch < 2; ch++) {
        double x = cv_sanitize_f(io[ch][i]);
        double mud = cv_biquad_tick(&dg->hp_mud_lr[ch], x, ramp);
        mud = cv_biquad_tick(&dg->lp_mud_lr[ch], mud, ramp);
        io[ch][i] = (float)(x - mud * mud_sub);
      }
    }

    if (channels >= 2) {
      double l = cv_sanitize_f(io[0][i]);
      double r = cv_sanitize_f(io[1][i]);
      double m = (l + r) * 0.5;
      double s = (l - r) * 0.5;

      double mp = cv_biquad_tick(&dg->hp_mid[0], m, ramp);
      mp = cv_biquad_tick(&dg->lp_mid[0], mp, ramp);
      m += mp * presence_add;

      double mmud = cv_biquad_tick(&dg->hp_mud[0], m, ramp);
      mmud = cv_biquad_tick(&dg->lp_mud[0], mmud, ramp);
      m -= mmud * mud_sub;

      double sp = cv_biquad_tick(&dg->hp_side[0], s, ramp);
      sp = cv_biquad_tick(&dg->lp_side[0], sp, ramp);
      s -= sp * side_sub;

      io[0][i] = (float)(m + s);
      io[1][i] = (float)(m - s);
    }
  }
}
