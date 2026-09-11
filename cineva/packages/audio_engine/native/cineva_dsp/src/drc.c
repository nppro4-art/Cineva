#include "drc.h"

#include <math.h>
#include <string.h>

#include "dsp_util.h"

void cv_drc_init(cv_drc *drc, double sample_rate) {
  memset(drc, 0, sizeof(*drc));
  drc->sample_rate = cv_clamp_d(sample_rate, 8000.0, 192000.0);
  drc->threshold_db = -24.0;
  drc->ratio = 2.5;
  drc->knee_db = 6.0;
  drc->attack_ms = 15.0;
  drc->release_ms = 250.0;
  drc->makeup_db = 0.0;
  drc->mix = 1.0;
  drc->detector = 1;
  drc->env_db = -70.0;
  drc->gain_db = 0.0;
  cv_drc_set(drc, drc->enable, drc->threshold_db, drc->ratio, drc->knee_db,
             drc->attack_ms, drc->release_ms, drc->makeup_db, drc->mix * 100.0,
             drc->detector);
}

void cv_drc_set(cv_drc *drc, int enable, double threshold_db, double ratio,
                double knee_db, double attack_ms, double release_ms,
                double makeup_db, double mix_percent, int detector) {
  drc->enable = enable ? 1 : 0;
  drc->threshold_db = cv_clamp_d(cv_sanitize_d(threshold_db), -60.0, 0.0);
  drc->ratio = cv_clamp_d(cv_sanitize_d(ratio), 1.0, 20.0);
  drc->knee_db = cv_clamp_d(cv_sanitize_d(knee_db), 0.0, 24.0);
  drc->attack_ms = cv_clamp_d(cv_sanitize_d(attack_ms), 0.5, 200.0);
  drc->release_ms = cv_clamp_d(cv_sanitize_d(release_ms), 20.0, 1000.0);
  drc->makeup_db = cv_clamp_d(cv_sanitize_d(makeup_db), -6.0, 12.0);
  drc->mix = cv_clamp_d(cv_sanitize_d(mix_percent), 0.0, 100.0) / 100.0;
  drc->detector = detector == 0 ? 0 : 1;
  drc->att_coef = cv_onepole_coef(drc->sample_rate, drc->attack_ms / 1000.0);
  drc->rel_coef = cv_onepole_coef(drc->sample_rate, drc->release_ms / 1000.0);
  drc->rms_coef = cv_onepole_coef(drc->sample_rate, 0.010);
}

void cv_drc_reset(cv_drc *drc) {
  drc->env_db = -70.0;
  drc->gain_db = 0.0;
}

/* Gain de compression (dB, <= 0) pour un niveau détecté (dB). */
static double cv_drc_compute_gain_db(const cv_drc *drc, double level_db) {
  double thr = drc->threshold_db;
  double knee = drc->knee_db;
  double slope = 1.0 / drc->ratio - 1.0; /* négatif */
  double over = level_db - thr;
  if (knee > 0.0 && 2.0 * over < knee && 2.0 * over > -knee) {
    /* Soft knee quadratique. */
    double x = over + knee * 0.5;
    double gr = slope * x * x / (2.0 * knee);
    return gr;
  }
  if (over <= 0.0) return 0.0;
  return slope * over;
}

void cv_drc_process(cv_drc *drc, float *const *io, int channels, int frames) {
  if (!drc->enable) return;
  if (channels < 1 || channels > 2) return;
  double rms_state = drc->rms_state_cache;
  double makeup = cv_db_to_lin(drc->makeup_db);
  double dry_mix = 1.0 - drc->mix;

  for (int i = 0; i < frames; i++) {
    double l = cv_sanitize_f(io[0][i]);
    double r = channels > 1 ? cv_sanitize_f(io[1][i]) : l;

    /* Détection linkée (un seul détecteur pour les deux canaux). */
    double level;
    if (drc->detector == 0) {
      double pk = fabs(l) > fabs(r) ? fabs(l) : fabs(r);
      level = pk;
    } else {
      double ms = (l * l + r * r) * 0.5;
      rms_state = drc->rms_coef * rms_state + (1.0 - drc->rms_coef) * ms;
      level = sqrt(rms_state);
    }
    double level_db = cv_lin_to_db(level);

    /* Enveloppe : montée rapide (attack), descente lente (release). */
    if (level_db > drc->env_db) {
      drc->env_db = drc->att_coef * drc->env_db + (1.0 - drc->att_coef) * level_db;
    } else {
      drc->env_db = drc->rel_coef * drc->env_db + (1.0 - drc->rel_coef) * level_db;
    }

    double target_gain = cv_drc_compute_gain_db(drc, drc->env_db);
    /* Lissage supplémentaire du gain (anti-pompage). */
    if (target_gain < drc->gain_db) {
      drc->gain_db = drc->att_coef * drc->gain_db + (1.0 - drc->att_coef) * target_gain;
    } else {
      drc->gain_db = drc->rel_coef * drc->gain_db + (1.0 - drc->rel_coef) * target_gain;
    }
    double wet_gain = cv_db_to_lin(drc->gain_db) * makeup;
    double gl = dry_mix + wet_gain * drc->mix;
    io[0][i] = (float)(l * gl);
    if (channels > 1) io[1][i] = (float)(r * gl);
  }
  drc->rms_state_cache = rms_state;
}

double cv_drc_gain_db(const cv_drc *drc) { return drc->gain_db; }
