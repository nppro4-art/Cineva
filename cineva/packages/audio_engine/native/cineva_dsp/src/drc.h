/* Contrôle dynamique : compresseur soft-knee, stéréo-linké, mix parallèle. */
#ifndef CINEVA_DSP_DRC_H
#define CINEVA_DSP_DRC_H

typedef struct {
  int enable;
  double threshold_db;
  double ratio;
  double knee_db;
  double attack_ms;
  double release_ms;
  double makeup_db;
  double mix;        /* 0..1 (compression parallèle) */
  int detector;      /* 0 peak, 1 rms */

  double sample_rate;
  double att_coef, rel_coef, rms_coef;
  double env_db;     /* niveau détecté lissé (dB) */
  double gain_db;    /* gain du compresseur (<= 0) */
  double rms_state_cache; /* mémoire RMS du détecteur */
} cv_drc;

void cv_drc_init(cv_drc *drc, double sample_rate);
void cv_drc_set(cv_drc *drc, int enable, double threshold_db, double ratio,
                double knee_db, double attack_ms, double release_ms,
                double makeup_db, double mix_percent, int detector);
void cv_drc_reset(cv_drc *drc);
void cv_drc_process(cv_drc *drc, float *const *io, int channels, int frames);
double cv_drc_gain_db(const cv_drc *drc);

#endif /* CINEVA_DSP_DRC_H */
