#include "bass.h"

#include <math.h>
#include <string.h>

#include "dsp_util.h"

void cv_bass_init(cv_bass *bs, double sample_rate) {
  memset(bs, 0, sizeof(*bs));
  bs->sample_rate = cv_clamp_d(sample_rate, 8000.0, 192000.0);
  bs->crossover_hz = 80.0;
  bs->sub_shelf_gain_db = 5.0;
  bs->band_thr_lin = cv_db_to_lin(-1.0);
  for (int ch = 0; ch < 2; ch++) {
    for (int s = 0; s < 2; s++) {
      cv_biquad_init(&bs->lp[ch][s]);
      cv_biquad_init(&bs->hp[ch][s]);
    }
    cv_biquad_init(&bs->sub_shelf[ch]);
    cv_biquad_init(&bs->harm_hp[ch]);
  }
  bs->dirty = 1;
}

void cv_bass_set(cv_bass *bs, int enable, double intensity_percent,
                 double crossover_hz, int speaker_mode,
                 double sub_shelf_gain_db, double harmonic_drive_percent,
                 double lfe_gain_db) {
  int was_disabled = !bs->enable;
  bs->enable = enable ? 1 : 0;
  bs->intensity = cv_clamp_d(cv_sanitize_d(intensity_percent), 0.0, 100.0) / 100.0;
  double xo = cv_clamp_d(cv_sanitize_d(crossover_hz), 50.0, 160.0);
  if (xo != bs->crossover_hz) {
    bs->crossover_hz = xo;
    bs->dirty = 1;
  }
  int mode = speaker_mode;
  if (mode < 0 || mode > 2) mode = 0;
  if (mode != bs->speaker_mode) {
    bs->speaker_mode = mode;
    bs->dirty = 1;
  }
  bs->sub_shelf_gain_db = cv_clamp_d(cv_sanitize_d(sub_shelf_gain_db), -6.0, 9.0);
  double drive = cv_clamp_d(cv_sanitize_d(harmonic_drive_percent), 0.0, 100.0) / 100.0;
  if (bs->speaker_mode == 0 || bs->speaker_mode == 2) drive = 0.0; /* HP complets / casque : pas d'extension */
  if (drive != bs->harmonic_drive) {
    bs->harmonic_drive = drive;
    bs->dirty = 1;
  }
  bs->lfe_gain_db = cv_clamp_d(cv_sanitize_d(lfe_gain_db), -12.0, 6.0);
  if (was_disabled && bs->enable) bs->dirty = 1;
}

static void cv_bass_update_filters(cv_bass *bs) {
  double sr = bs->sample_rate;
  for (int ch = 0; ch < 2; ch++) {
    /* LR4 = 2 cascades Butterworth (Q 0.707). */
    for (int s = 0; s < 2; s++) {
      cv_biquad_set(&bs->lp[ch][s], CV_BQ_LOWPASS, bs->crossover_hz, 0.0, 0.7071, sr);
      cv_biquad_set(&bs->hp[ch][s], CV_BQ_HIGHPASS, bs->crossover_hz, 0.0, 0.7071, sr);
    }
    /* Sub-bass : lowshelf 50 Hz, gain effectif borné par l'intensité. */
    double sub_db = bs->sub_shelf_gain_db * bs->intensity;
    if (bs->speaker_mode == 2) sub_db *= 0.6; /* casque : plus retenu */
    if (bs->speaker_mode == 1) sub_db *= 0.8;
    cv_biquad_set(&bs->sub_shelf[ch], CV_BQ_LOWSHELF, 50.0, sub_db, 0.707, sr);
    /* Harmoniques : on ne garde que ce qui est au-dessus du crossover. */
    cv_biquad_set(&bs->harm_hp[ch], CV_BQ_HIGHPASS, bs->crossover_hz * 0.9, 0.0, 0.707, sr);
  }
  bs->dirty = 0;
}

void cv_bass_reset(cv_bass *bs) {
  for (int ch = 0; ch < 2; ch++) {
    for (int s = 0; s < 2; s++) {
      cv_biquad_reset_state(&bs->lp[ch][s]);
      cv_biquad_reset_state(&bs->hp[ch][s]);
    }
    cv_biquad_reset_state(&bs->sub_shelf[ch]);
    cv_biquad_reset_state(&bs->harm_hp[ch]);
  }
  bs->band_env = 0.0;
}

void cv_bass_process(cv_bass *bs, float *const *io, const float *lfe,
                     int frames) {
  if (!bs->enable) return;
  if (bs->dirty) cv_bass_update_filters(bs);
  double ramp = 1.0 - cv_onepole_coef(bs->sample_rate, 0.02);
  double rel = cv_onepole_coef(bs->sample_rate, 0.020); /* release limiteur de bande */
  double lfe_gain = lfe != NULL ? cv_db_to_lin(bs->lfe_gain_db) : 0.0;
  double drive_k = 1.0 + 2.0 * bs->harmonic_drive; /* douceur du saturateur */
  double drive_norm = tanh(drive_k);

  for (int i = 0; i < frames; i++) {
    double low[2], high[2];
    for (int ch = 0; ch < 2; ch++) {
      double x = cv_sanitize_f(io[ch][i]);
      double lp = cv_biquad_tick(&bs->lp[ch][0], x, ramp);
      lp = cv_biquad_tick(&bs->lp[ch][1], lp, ramp);
      double hp = cv_biquad_tick(&bs->hp[ch][0], x, ramp);
      hp = cv_biquad_tick(&bs->hp[ch][1], hp, ramp);
      low[ch] = lp;
      high[ch] = hp;
    }

    /* LFE (bass management) dans la voie basse. */
    if (lfe != NULL) {
      double l = cv_sanitize_f(lfe[i]) * lfe_gain;
      low[0] += l;
      low[1] += l;
    }

    /* Shelf sub-bass contrôlé. */
    for (int ch = 0; ch < 2; ch++) {
      low[ch] = cv_biquad_tick(&bs->sub_shelf[ch], low[ch], ramp);
    }

    /* Extension harmonique douce (petits haut-parleurs uniquement). */
    if (bs->harmonic_drive > 0.0) {
      for (int ch = 0; ch < 2; ch++) {
        double sat = tanh(low[ch] * drive_k) / drive_norm;
        double harm = sat - low[ch]; /* distorsion ≈ harmoniques */
        harm = cv_biquad_tick(&bs->harm_hp[ch], harm, ramp);
        high[ch] += harm * bs->harmonic_drive;
      }
    }

    /* Limiteur de bande rapide (protection des excès de grave). */
    double peak = fabs(low[0]) > fabs(low[1]) ? fabs(low[0]) : fabs(low[1]);
    double need = 1.0;
    if (peak > bs->band_thr_lin) need = bs->band_thr_lin / peak;
    if (need < bs->band_env) {
      bs->band_env = need; /* attaque immédiate */
    } else {
      bs->band_env = rel * bs->band_env + (1.0 - rel) * need;
    }
    low[0] *= bs->band_env;
    low[1] *= bs->band_env;

    /* Recombinaison phase-alignée (somme LR4). */
    io[0][i] = (float)(low[0] + high[0]);
    io[1][i] = (float)(low[1] + high[1]);
  }
}
