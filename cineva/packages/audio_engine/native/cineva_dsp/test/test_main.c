/*
 * Suite de tests du cœur DSP Cineva.
 * Usage : cineva_dsp_test            → tests
 *         cineva_dsp_test <dir>      → régénère les golden files dans <dir>
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../include/cineva_dsp.h"
#include "../src/bass.h"
#include "../src/biquad.h"
#include "../src/channel_mapper.h"
#include "../src/dialogue.h"
#include "../src/drc.h"
#include "../src/limiter.h"
#include "../src/loudness.h"
#include "../src/param_eq.h"
#include "../src/room.h"
#include "../src/spatial.h"
#include "test_util.h"

#define SR 48000.0
#define N 4800

static void fill_params_base(double *p) {
  memset(p, 0, sizeof(double) * CINEVA_DSP_PARAM_COUNT);
  p[0] = CINEVA_DSP_PARAM_VERSION;
  p[1] = SR;
  p[2] = 1;
  p[3] = 2;
  p[4] = 2;
  p[5] = 1;
  p[8] = 1; p[9] = -16; p[10] = 8; p[11] = 8; p[12] = 1.5;
  p[16] = 1;
  {
    static const int types[6] = {0, 1, 1, 1, 1, 2};
    static const double freqs[6] = {45, 90, 300, 1200, 3500, 10000};
    for (int i = 0; i < 6; i++) {
      p[17 + 5 * i] = types[i];
      p[18 + 5 * i] = freqs[i];
      p[19 + 5 * i] = 0.0;
      p[20 + 5 * i] = 0.9;
    }
  }
  p[48] = 1; p[49] = -24; p[50] = 2.5; p[51] = 6; p[52] = 15; p[53] = 250;
  p[54] = 0; p[55] = 100; p[56] = 1;
  p[60] = 1; p[61] = 35;
  p[68] = 1; p[69] = 50; p[70] = 80; p[71] = 0; p[72] = 5; p[73] = 0; p[74] = 0;
  p[80] = 1; p[81] = 1; p[82] = 100; p[83] = 0; p[84] = 100;
  p[92] = 1; p[93] = 6; p[94] = 100;
  p[100] = 1; p[101] = -1; p[102] = 5; p[103] = 120;
}

/* Active un traitement à la fois pour des tests unitaires ciblés. */
static void only(double *p, int master, int idx_enable) {
  p[2] = master;
  int enables[] = {8, 16, 48, 60, 68, 80, 92, 100};
  for (int i = 0; i < 8; i++) p[enables[i]] = (enables[i] == idx_enable) ? 1 : 0;
}

static void test_create_and_version(void) {
  printf("test_create_and_version\n");
  CV_CHECK(strcmp(cineva_dsp_version(), "1.0.0") == 0, "version");
  cineva_dsp *d = cineva_dsp_create(SR);
  CV_CHECK(d != NULL, "création");
  double got[CINEVA_DSP_PARAM_COUNT];
  CV_CHECK(cineva_dsp_get_params(d, got, CINEVA_DSP_PARAM_COUNT) == 0, "get_params");
  CV_CHECK((int)got[0] == CINEVA_DSP_PARAM_VERSION, "version param");
  CV_CHECK(cineva_dsp_get_params(d, got, 5) == -1, "count invalide rejeté");
  cineva_dsp_destroy(d);
  cineva_dsp_destroy(NULL); /* doit être un no-op sûr */
}

static void test_param_validation(void) {
  printf("test_param_validation\n");
  cineva_dsp *d = cineva_dsp_create(SR);
  double p[CINEVA_DSP_PARAM_COUNT];
  fill_params_base(p);

  /* Version incorrecte. */
  double bad[CINEVA_DSP_PARAM_COUNT];
  memcpy(bad, p, sizeof(p));
  bad[0] = 99;
  CV_CHECK(cineva_dsp_set_params(d, bad, CINEVA_DSP_PARAM_COUNT) == -2, "mauvaise version rejetée");
  CV_CHECK(cineva_dsp_set_params(d, p, 10) == -1, "count incorrect rejeté");
  CV_CHECK(cineva_dsp_set_params(NULL, p, CINEVA_DSP_PARAM_COUNT) == -1, "null rejeté");

  /* NaN / Inf / valeurs extrêmes → clampés, pas de crash. */
  memcpy(bad, p, sizeof(p));
  bad[9] = NAN;   /* targetLufs */
  bad[19] = INFINITY; /* gain EQ 1 */
  bad[49] = -1e9; /* threshold */
  bad[50] = 1e9;  /* ratio */
  bad[82] = 1e9;  /* width */
  bad[101] = NAN; /* ceiling */
  CV_CHECK(cineva_dsp_set_params(d, bad, CINEVA_DSP_PARAM_COUNT) == 0, "params extrêmes acceptés (clampés)");
  double got[CINEVA_DSP_PARAM_COUNT];
  cineva_dsp_get_params(d, got, CINEVA_DSP_PARAM_COUNT);
  CV_CHECK(got[9] == got[9] && got[9] >= -36 && got[9] <= -8, "targetLufs clampé");
  CV_CHECK(got[19] <= 15.0, "gain EQ clampé");
  CV_CHECK(got[49] >= -60.0, "threshold clampé");
  CV_CHECK(got[50] <= 20.0, "ratio clampé");
  CV_CHECK(got[82] <= 150.0, "width clampé");
  CV_CHECK(got[101] == got[101] && got[101] <= 0.0, "ceiling clampé");

  /* Traitement avec params extrêmes : aucun NaN. */
  float in0[N], in1[N], out0[N], out1[N];
  for (int i = 0; i < N; i++) {
    in0[i] = (float)(0.3 * cv_sine_amp(440.0, SR, i));
    in1[i] = (float)(0.3 * cv_sine_amp(450.0, SR, i));
  }
  const float *in[2] = {in0, in1};
  float *out[2] = {out0, out1};
  CV_CHECK(cineva_dsp_process(d, in, 2, out, 2, N) == 0, "process ok");
  CV_CHECK(cv_all_finite(out0, N) && cv_all_finite(out1, N), "sortie finie avec params extrêmes");
  cineva_dsp_destroy(d);
}

static void test_silence(void) {
  printf("test_silence\n");
  cineva_dsp *d = cineva_dsp_create(SR);
  double p[CINEVA_DSP_PARAM_COUNT];
  fill_params_base(p);
  cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);
  float in0[N] = {0}, in1[N] = {0}, out0[N], out1[N];
  const float *in[2] = {in0, in1};
  float *out[2] = {out0, out1};
  for (int rep = 0; rep < 10; rep++) {
    CV_CHECK(cineva_dsp_process(d, in, 2, out, 2, N) == 0, "process silence");
    CV_CHECK(cv_all_finite(out0, N) && cv_all_finite(out1, N), "sortie finie (silence)");
  }
  double m[CINEVA_DSP_METRIC_COUNT];
  cineva_dsp_get_metrics(d, m, CINEVA_DSP_METRIC_COUNT);
  CV_CHECK(m[0] <= -69.0, "loudness intégré reste sous le gate (silence)");
  CV_CHECK(m[4] == 0.0, "aucun clipping sur silence");
  cineva_dsp_destroy(d);
}

static void test_bypass_bitexact(void) {
  printf("test_bypass_bitexact\n");
  cineva_dsp *d = cineva_dsp_create(SR);
  double p[CINEVA_DSP_PARAM_COUNT];
  fill_params_base(p);
  cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);
  float in0[N], in1[N], out0[N], out1[N];
  for (int i = 0; i < N; i++) {
    in0[i] = (float)(0.4 * cv_sine_amp(300.0, SR, i) + 0.05 * cv_rng_uniform());
    in1[i] = (float)(0.4 * cv_sine_amp(310.0, SR, i) - 0.05 * cv_rng_uniform());
  }
  const float *in[2] = {in0, in1};
  float *out[2] = {out0, out1};

  p[2] = 0; /* masterEnable = 0 → A/B original */
  cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);
  cineva_dsp_process(d, in, 2, out, 2, N);
  int same = 1;
  for (int i = 0; i < N; i++) {
    if (out[0][i] != in0[i] || out[1][i] != in1[i]) same = 0;
  }
  CV_CHECK(same, "bypass bit-exact (A/B original)");
  cineva_dsp_destroy(d);
}

static void test_loudness_measurement_and_gain(void) {
  printf("test_loudness_measurement_and_gain\n");
  cineva_dsp *d = cineva_dsp_create(SR);
  double p[CINEVA_DSP_PARAM_COUNT];
  fill_params_base(p);
  only(p, 1, 8); /* loudness seul */
  p[9] = -16; p[12] = 6.0; /* adaptation rapide pour le test */
  cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);

  /* Sine 1 kHz stéréo à -20 dBFS → BS.1770 ≈ -20.7 LUFS. */
  float in0[N], in1[N], out0[N], out1[N];
  const float *in[2] = {in0, in1};
  float *out[2] = {out0, out1};
  double amp = 0.1;
  for (int i = 0; i < N; i++) {
    in0[i] = (float)(amp * cv_sine_amp(1000.0, SR, i));
    in1[i] = in0[i];
  }
  double m[CINEVA_DSP_METRIC_COUNT];
  for (int rep = 0; rep < 12; rep++) { /* ~1.2 s */
    cineva_dsp_process(d, in, 2, out, 2, N);
    cineva_dsp_get_metrics(d, m, CINEVA_DSP_METRIC_COUNT);
  }
  CV_CHECK_NEAR(m[0], -20.69, 0.7, "loudness intégré du sine 1 kHz @ -20 dBFS");
  CV_CHECK(m[2] > 2.0, "gain appliqué positif (cible -16 LUFS)");
  CV_CHECK(m[2] <= 8.0 + 1e-6, "gain borné par maxGainDb");

  /* Le RMS de sortie a augmenté d'environ le gain appliqué. */
  double rms_in = cv_rms(out0, N); /* après stabilisation, sortie ≈ entrée × gain */
  double expect = amp * 0.7071 * pow(10.0, m[2] / 20.0);
  CV_CHECK_NEAR(rms_in, expect, expect * 0.15 + 1e-4, "RMS sortie ≈ entrée × gain");
  cineva_dsp_destroy(d);
}

static void test_limiter_ceiling(void) {
  printf("test_limiter_ceiling\n");
  cineva_dsp *d = cineva_dsp_create(SR);
  double p[CINEVA_DSP_PARAM_COUNT];
  fill_params_base(p);
  only(p, 1, 100); /* limiteur seul */
  p[101] = -1.0;
  cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);
  float in0[N], in1[N], out0[N], out1[N];
  const float *in[2] = {in0, in1};
  float *out[2] = {out0, out1};
  for (int i = 0; i < N; i++) {
    /* Signal chaud : 0 dBFS + bursts. */
    double s = 1.2 * cv_sine_amp(220.0, SR, i);
    in0[i] = (float)s;
    in1[i] = (float)-s;
  }
  double ceiling = pow(10.0, -1.0 / 20.0);
  double max_peak = 0.0;
  for (int rep = 0; rep < 6; rep++) {
    cineva_dsp_process(d, in, 2, out, 2, N);
    double pk = cv_peak_abs(out0, N);
    if (pk > max_peak) max_peak = pk;
    pk = cv_peak_abs(out1, N);
    if (pk > max_peak) max_peak = pk;
  }
  CV_CHECK(max_peak <= ceiling * 1.02, "sortie sous le plafond true-peak");
  double m[CINEVA_DSP_METRIC_COUNT];
  cineva_dsp_get_metrics(d, m, CINEVA_DSP_METRIC_COUNT);
  CV_CHECK(m[3] < -0.05, "réduction de gain du limiteur active");
  CV_CHECK(m[4] == 0.0, "aucun clamp dur (le limiteur protège)");
  cineva_dsp_destroy(d);
}

static void test_drc_reduces_dynamics(void) {
  printf("test_drc_reduces_dynamics\n");
  cineva_dsp *d = cineva_dsp_create(SR);
  double p[CINEVA_DSP_PARAM_COUNT];
  fill_params_base(p);
  only(p, 1, 48); /* DRC seul */
  p[49] = -30; p[50] = 4; p[51] = 6; p[52] = 5; p[53] = 150; p[54] = 0; p[55] = 100;
  cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);

  float in0[N], in1[N], out0[N], out1[N];
  const float *in[2] = {in0, in1};
  float *out[2] = {out0, out1};
  double hot = 0.0, hot_in = 0.0;
  for (int rep = 0; rep < 8; rep++) {
    for (int i = 0; i < N; i++) {
      double env = 0.9 * cv_sine_amp(200.0, SR, i);
      in0[i] = (float)env;
      in1[i] = (float)env;
    }
    cineva_dsp_process(d, in, 2, out, 2, N);
    double rms_out = cv_rms(out0, N);
    double rms_in = cv_rms(in0, N);
    hot = rms_out;
    hot_in = rms_in;
  }
  /* 0.9 amplitude sine @ 200 Hz : RMS in ≈ 0.64 ; au-dessus du threshold -30 dB
     avec ratio 4:1 → réduction attendue > 6 dB sur les crêtes. */
  CV_CHECK(hot < hot_in * 0.72, "le compresseur réduit le niveau fort");
  cineva_dsp_destroy(d);
}

static void test_eq_band_gains(void) {
  printf("test_eq_band_gains\n");
  cineva_dsp *d = cineva_dsp_create(SR);
  double p[CINEVA_DSP_PARAM_COUNT];
  fill_params_base(p);
  only(p, 1, 16); /* EQ seul */
  /* Bass +6 dB @ 90 Hz (bande 1), treble -6 dB @ 10 kHz (bande 5). */
  p[19 + 5 * 1] = 6.0;
  p[19 + 5 * 5] = -6.0;
  cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);

  float in0[N], in1[N], out0[N], out1[N];
  const float *in[2] = {in0, in1};
  float *out[2] = {out0, out1};

  /* Mesure directe des modules (pas de dépendance au fichier .so).
     La rampe anti-zipper des coefficients dure ~200 ms : on chauffe d'abord. */
  cv_param_eq eq;
  cv_param_eq_init(&eq, SR);
  int types[6] = {0, 1, 1, 1, 1, 2};
  double freqs[6] = {45, 90, 300, 1200, 3500, 10000};
  double gains[6] = {0, 6, 0, 0, 0, -6};
  double qs[6] = {0.9, 0.9, 0.9, 0.9, 0.9, 0.9};
  cv_param_eq_set(&eq, 1, types, freqs, gains, qs);
  float *ch[2] = {in0, in1};
  for (int warm = 0; warm < 4; warm++) {
    for (int i = 0; i < N; i++) {
      in0[i] = (float)(0.25 * cv_sine_amp(90.0, SR, i));
      in1[i] = in0[i];
    }
    cv_param_eq_process(&eq, ch, 2, N);
  }
  double rms_low = cv_rms(in0, N);
  double expect_low = 0.25 * 0.7071 * pow(10.0, 6.0 / 20.0);
  CV_CHECK_NEAR(rms_low, expect_low, expect_low * 0.08, "gain +6 dB @ 90 Hz appliqué");

  /* Vérif via le moteur complet : sortie ≠ entrée, finie (chauffe la rampe). */
  fill_params_base(p);
  only(p, 1, 16);
  p[19 + 5 * 1] = 6.0;
  cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);
  for (int warm = 0; warm < 3; warm++) {
    cineva_dsp_process(d, in, 2, out, 2, N);
  }
  cineva_dsp_process(d, in, 2, out, 2, N);
  CV_CHECK(cv_all_finite(out0, N), "EQ : sortie finie");
  CV_CHECK(cv_rms(out0, N) > 0.25 * 0.7071 * 1.2, "EQ : énergie basse augmentée");
  cineva_dsp_destroy(d);
}

static void test_dialogue_ms(void) {
  printf("test_dialogue_ms\n");
  cv_dialogue dg;
  cv_dialogue_init(&dg, SR);
  cv_dialogue_set(&dg, 1, 100.0);
  int n = N;
  float *ch[2];
  float l[N], r[N];
  ch[0] = l; ch[1] = r;

  /* Signal mid pur à 2 kHz (voix en phase) → doit être renforcé. */
  for (int i = 0; i < n; i++) {
    double s = 0.3 * cv_sine_amp(2000.0, SR, i);
    l[i] = (float)s;
    r[i] = (float)s;
  }
  cv_dialogue_process(&dg, ch, 2, 1, n);
  double rms_after = cv_rms(l, n);
  double rms_before = 0.3 * 0.7071;
  CV_CHECK(rms_after > rms_before * 1.15, "dialogue : mid 2 kHz renforcé");

  /* Signal side pur à 2 kHz (anti-phase) → doit être atténué. */
  cv_dialogue_reset(&dg);
  for (int i = 0; i < n; i++) {
    double s = 0.3 * cv_sine_amp(2000.0, SR, i);
    l[i] = (float)s;
    r[i] = (float)-s;
  }
  cv_dialogue_process(&dg, ch, 2, 1, n);
  rms_after = cv_rms(l, n);
  CV_CHECK(rms_after < rms_before * 0.95, "dialogue : side 2 kHz atténué");

  /* Hors bande de présence (300 Hz) : quasi inchangé. */
  cv_dialogue_reset(&dg);
  for (int i = 0; i < n; i++) {
    double s = 0.3 * cv_sine_amp(3000.0, SR, i) * 0.0; /* placeholder */
    (void)s;
    double t = 0.3 * cv_sine_amp(120.0, SR, i);
    l[i] = (float)t;
    r[i] = (float)t;
  }
  cv_dialogue_process(&dg, ch, 2, 1, n);
  rms_after = cv_rms(l, n);
  CV_CHECK(rms_after > rms_before * 0.9 && rms_after < rms_before * 1.05,
           "dialogue : bande hors présence quasi inchangée");
}

static void test_bass_management(void) {
  printf("test_bass_management\n");
  cv_bass bs;
  cv_bass_init(&bs, SR);
  cv_bass_set(&bs, 1, 100.0, 80.0, 0, 6.0, 0.0, 0.0);
  float *ch[2];
  float l[N], r[N];
  ch[0] = l; ch[1] = r;
  for (int i = 0; i < N; i++) {
    double s = 0.4 * cv_sine_amp(40.0, SR, i);
    l[i] = (float)s;
    r[i] = (float)s;
  }
  double rms_in = cv_rms(l, N);
  cv_bass_process(&bs, ch, NULL, N);
  double rms_out = cv_rms(l, N);
  CV_CHECK(rms_out > rms_in * 1.3, "bass : énergie 40 Hz renforcée (shelf +6 dB)");
  CV_CHECK(cv_all_finite(l, N), "bass : sortie finie");

  /* Harmoniques en mode petit haut-parleur : la différence entre drive 0 et
     drive 80 ne peut venir que de l'extension harmonique. */
  cv_bass_reset(&bs);
  cv_bass_set(&bs, 1, 100.0, 80.0, 1, 0.0, 0.0, 0.0);
  for (int i = 0; i < N; i++) {
    double s = 0.5 * cv_sine_amp(40.0, SR, i);
    l[i] = (float)s;
    r[i] = (float)s;
  }
  float no_drive[N];
  memcpy(no_drive, l, sizeof(l));
  cv_bass_process(&bs, ch, NULL, N);

  cv_bass_reset(&bs);
  cv_bass_set(&bs, 1, 100.0, 80.0, 1, 0.0, 80.0, 0.0);
  for (int i = 0; i < N; i++) {
    double s = 0.5 * cv_sine_amp(40.0, SR, i);
    l[i] = (float)s;
    r[i] = (float)s;
  }
  cv_bass_process(&bs, ch, NULL, N);
  double harm_energy = 0.0;
  for (int i = 0; i < N; i++) {
    double diff = (double)l[i] - (double)no_drive[i];
    harm_energy += diff * diff;
  }
  CV_CHECK(harm_energy / N > 1e-6, "bass : extension harmonique active (mode small)");
  CV_CHECK(cv_all_finite(l, N), "bass small : sortie finie");
}

static void test_spatial_width_and_binaural(void) {
  printf("test_spatial_width_and_binaural\n");
  cv_spatial sp;
  cv_spatial_init(&sp, SR);

  /* Width 50 % sur un signal side pur → amplitude divisée. */
  cv_spatial_set(&sp, 1, CV_SPATIAL_MODE_WIDTH, 50.0, 0.0, 100.0);
  float in0[N], in1[N], out0[N], out1[N];
  const float *in[2] = {in0, in1};
  float *out[2] = {out0, out1};
  for (int i = 0; i < N; i++) {
    double s = 0.3 * cv_sine_amp(1000.0, SR, i);
    in0[i] = (float)s;
    in1[i] = (float)-s;
  }
  cv_spatial_process(&sp, in, 2, 1, out, 0.0, N);
  double rms_out = cv_rms(out0, N);
  double rms_in = cv_rms(in0, N);
  CV_CHECK_NEAR(rms_out, rms_in * 0.5, rms_in * 0.12, "spatial : width 50 % sur side");

  /* Binaural 5.1 : impulsion sur Rs doit produire de l'énergie à gauche
     (voie controlatérale retardée) et à droite (ipsilatérale). */
  cv_spatial_reset(&sp);
  cv_spatial_set(&sp, 1, CV_SPATIAL_MODE_BINAURAL, 100.0, 0.0, 100.0);
  float c6[6][N];
  const float *in6[6] = {c6[0], c6[1], c6[2], c6[3], c6[4], c6[5]};
  memset(c6, 0, sizeof(c6));
  for (int k = 0; k * 100 < N; k++) c6[5][k * 100] = 0.9f; /* impulsions Rs */
  cv_spatial_process(&sp, in6, 6, 3, out, 0.0, N);
  CV_CHECK(cv_all_finite(out0, N) && cv_all_finite(out1, N), "binaural : sortie finie");
  double e_r = 0.0, e_l = 0.0;
  for (int i = 0; i < N; i++) {
    e_r += (double)out1[i] * out1[i];
    e_l += (double)out0[i] * out0[i];
  }
  CV_CHECK(e_r > 1e-3, "binaural : ipsilatéral (R) présent pour Rs");
  CV_CHECK(e_l > 1e-4, "binaural : controlatéral (L) présent pour Rs (ITD/ILD)");
  CV_CHECK(e_l < e_r, "binaural : ipsilatéral > controlatéral");

  /* Crossfeed stéréo : signal R pur → fuite filtrée vers L. */
  cv_spatial_reset(&sp);
  cv_spatial_set(&sp, 1, CV_SPATIAL_MODE_BINAURAL_CROSSFEED, 100.0, 100.0, 100.0);
  for (int i = 0; i < N; i++) {
    in0[i] = 0.0f;
    in1[i] = (float)(0.4 * cv_sine_amp(500.0, SR, i));
  }
  cv_spatial_process(&sp, in, 2, 1, out, 0.0, N);
  double leak = cv_rms(out0, N);
  CV_CHECK(leak > 1e-4, "crossfeed : fuite R → L présente");
  CV_CHECK(leak < 0.2, "crossfeed : fuite raisonnable");
}

static void test_room_early_reflections(void) {
  printf("test_room_early_reflections\n");
  cv_room rm;
  cv_room_init(&rm, SR);
  cv_room_set(&rm, 1, 10.0, 100.0);
  float *ch[2];
  float l[N], r[N];
  ch[0] = l; ch[1] = r;
  memset(l, 0, sizeof(l));
  memset(r, 0, sizeof(r));
  l[0] = 1.0f; /* impulsion */
  r[0] = 1.0f;
  cv_room_process(&rm, ch, N);
  /* Des taps doivent exister entre ~5 ms et ~40 ms. */
  int taps_found = 0;
  for (int i = (int)(0.004 * SR); i < (int)(0.045 * SR) && i < N; i++) {
    if (fabs((double)l[i]) > 0.0005 || fabs((double)r[i]) > 0.0005) taps_found++;
  }
  CV_CHECK(taps_found >= 4, "room : réflexions précoces présentes");
  /* Rien après 60 ms (pas de queue de réverbération). */
  int late = 0;
  for (int i = (int)(0.06 * SR); i < N; i++) {
    if (fabs((double)l[i]) > 1e-6) late++;
  }
  CV_CHECK(late == 0, "room : aucune queue après 60 ms");

  /* Wet 0 % → transparent (recopie exacte). */
  cv_room_reset(&rm);
  cv_room_set(&rm, 1, 0.0, 100.0);
  for (int i = 0; i < N; i++) {
    l[i] = (float)(0.2 * cv_sine_amp(600.0, SR, i));
    r[i] = (float)(0.2 * cv_sine_amp(601.0, SR, i));
  }
  float l_ref[N], r_ref[N];
  memcpy(l_ref, l, sizeof(l));
  memcpy(r_ref, r, sizeof(r));
  cv_room_process(&rm, ch, N);
  int same = 1;
  for (int i = 0; i < N; i++) {
    if (l[i] != l_ref[i] || r[i] != r_ref[i]) same = 0;
  }
  CV_CHECK(same, "room : wet 0 % = transparent");
}

static void test_channel_mapper(void) {
  printf("test_channel_mapper\n");
  CV_CHECK(cv_layout_from_channels(1) == 0, "layout mono");
  CV_CHECK(cv_layout_from_channels(2) == 1, "layout stéréo");
  CV_CHECK(cv_layout_from_channels(6) == 3, "layout 5.1");
  CV_CHECK(cv_layout_from_channels(8) == 4, "layout 7.1");

  const int n = 64;
  float c6[6][64];
  const float *in6[6] = {c6[0], c6[1], c6[2], c6[3], c6[4], c6[5]};
  float lo[64], ro[64];
  float *out[2] = {lo, ro};
  memset(c6, 0, sizeof(c6));
  for (int i = 0; i < n; i++) c6[2][i] = 1.0f; /* centre constant */
  cv_mapper_downmix_itu(in6, 6, 3, out, 0.0, n);
  CV_CHECK_NEAR(lo[10], 0.7071, 1e-5, "downmix ITU : C → L à 0.707");
  CV_CHECK_NEAR(ro[10], 0.7071, 1e-5, "downmix ITU : C → R à 0.707");

  double w[8];
  cv_mapper_weights(3, 6, w);
  CV_CHECK_NEAR(w[4], 1.4142135623730951, 1e-12, "poids BS.1770 Ls = √2");
  CV_CHECK_NEAR(w[3], 0.0, 1e-12, "poids BS.1770 LFE = 0");
}

static void test_full_pipeline_stereo_and_multichannel(void) {
  printf("test_full_pipeline_stereo_and_multichannel\n");
  cineva_dsp *d = cineva_dsp_create(SR);
  double p[CINEVA_DSP_PARAM_COUNT];
  fill_params_base(p);
  p[81] = 2; /* binaural */
  p[83] = 40; /* crossfeed léger */
  cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);

  float in0[N], in1[N], out0[N], out1[N];
  const float *in[2] = {in0, in1};
  float *out[2] = {out0, out1};
  for (int i = 0; i < N; i++) {
    in0[i] = (float)(0.35 * cv_sine_amp(150.0, SR, i) + 0.1 * (cv_rng_uniform() - 0.5));
    in1[i] = (float)(0.35 * cv_sine_amp(1500.0, SR, i) + 0.1 * (cv_rng_uniform() - 0.5));
  }
  for (int rep = 0; rep < 4; rep++) {
    CV_CHECK(cineva_dsp_process(d, in, 2, out, 2, N) == 0, "process stéréo");
    CV_CHECK(cv_all_finite(out0, N) && cv_all_finite(out1, N), "pipeline stéréo fini");
    CV_CHECK(cv_peak_abs(out0, N) <= 1.0, "pipeline stéréo sans clip");
    CV_CHECK(cv_peak_abs(out1, N) <= 1.0, "pipeline stéréo sans clip R");
  }

  /* 5.1 bruité. */
  p[3] = 6; p[5] = 3;
  cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);
  cineva_dsp_reset(d);
  float c6[6][N];
  const float *in6[6] = {c6[0], c6[1], c6[2], c6[3], c6[4], c6[5]};
  for (int i = 0; i < N; i++) {
    for (int ch = 0; ch < 6; ch++) {
      c6[ch][i] = (float)(0.25 * (cv_rng_uniform() * 2.0 - 1.0));
    }
  }
  for (int rep = 0; rep < 4; rep++) {
    CV_CHECK(cineva_dsp_process(d, in6, 6, out, 2, N) == 0, "process 5.1");
    CV_CHECK(cv_all_finite(out0, N) && cv_all_finite(out1, N), "pipeline 5.1 fini");
    CV_CHECK(cv_peak_abs(out0, N) <= 1.0, "pipeline 5.1 sans clip L");
    CV_CHECK(cv_peak_abs(out1, N) <= 1.0, "pipeline 5.1 sans clip R");
  }
  cineva_dsp_destroy(d);
}

static void test_low_and_high_levels(void) {
  printf("test_low_and_high_levels\n");
  cineva_dsp *d = cineva_dsp_create(SR);
  double p[CINEVA_DSP_PARAM_COUNT];
  fill_params_base(p);
  cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);
  float in0[N], in1[N], out0[N], out1[N];
  const float *in[2] = {in0, in1};
  float *out[2] = {out0, out1};

  /* Niveau très faible (-60 dBFS). */
  for (int i = 0; i < N; i++) {
    in0[i] = (float)(0.001 * cv_sine_amp(500.0, SR, i));
    in1[i] = in0[i];
  }
  for (int rep = 0; rep < 3; rep++) {
    cineva_dsp_process(d, in, 2, out, 2, N);
    CV_CHECK(cv_all_finite(out0, N) && cv_all_finite(out1, N), "niveau faible : fini");
  }
  double m[CINEVA_DSP_METRIC_COUNT];
  cineva_dsp_get_metrics(d, m, CINEVA_DSP_METRIC_COUNT);
  CV_CHECK(m[4] == 0.0, "niveau faible : pas de clipping");

  /* Niveau très élevé (+2 dBFS, entrée hors échelle). */
  for (int i = 0; i < N; i++) {
    in0[i] = (float)(1.26 * cv_sine_amp(300.0, SR, i));
    in1[i] = (float)(1.26 * cv_sine_amp(300.0, SR, i));
  }
  for (int rep = 0; rep < 5; rep++) {
    cineva_dsp_process(d, in, 2, out, 2, N);
    CV_CHECK(cv_all_finite(out0, N) && cv_all_finite(out1, N), "niveau élevé : fini");
    CV_CHECK(cv_peak_abs(out0, N) <= 1.0, "niveau élevé : borné (limiteur)");
    CV_CHECK(cv_peak_abs(out1, N) <= 1.0, "niveau élevé : borné R");
  }
  cineva_dsp_destroy(d);
}

static void test_nan_input(void) {
  printf("test_nan_input\n");
  cineva_dsp *d = cineva_dsp_create(SR);
  double p[CINEVA_DSP_PARAM_COUNT];
  fill_params_base(p);
  cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);
  float in0[N], in1[N], out0[N], out1[N];
  const float *in[2] = {in0, in1};
  float *out[2] = {out0, out1};
  for (int i = 0; i < N; i++) {
    in0[i] = (float)(0.3 * cv_sine_amp(440.0, SR, i));
    in1[i] = in0[i];
  }
  in0[100] = NAN;
  in0[101] = INFINITY;
  in1[200] = NAN;
  cineva_dsp_process(d, in, 2, out, 2, N);
  CV_CHECK(cv_all_finite(out0, N) && cv_all_finite(out1, N), "entrée NaN/Inf → sortie finie");
  cineva_dsp_destroy(d);
}

static void test_param_changes_during_playback(void) {
  printf("test_param_changes_during_playback\n");
  cineva_dsp *d = cineva_dsp_create(SR);
  double p[CINEVA_DSP_PARAM_COUNT];
  fill_params_base(p);
  cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);
  float in0[N], in1[N], out0[N], out1[N];
  const float *in[2] = {in0, in1};
  float *out[2] = {out0, out1};
  double prev_last = 0.0;
  for (int rep = 0; rep < 12; rep++) {
    for (int i = 0; i < N; i++) {
      in0[i] = (float)(0.4 * cv_sine_amp(220.0 + rep * 37.0, SR, i));
      in1[i] = (float)(0.4 * cv_sine_amp(221.0 + rep * 37.0, SR, i));
    }
    /* Changements agressifs à chaque bloc. */
    p[19 + 5 * (rep % 6)] = (rep % 2 == 0) ? 8.0 : -8.0;
    p[61] = 10.0 + rep * 8.0;
    p[69] = 10.0 + rep * 8.0;
    p[82] = 60.0 + rep * 9.0;
    p[93] = (rep % 4) * 5.0;
    if (rep == 6) p[2] = 0; /* toggle A/B pendant la lecture */
    if (rep == 8) p[2] = 1;
    cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);
    CV_CHECK(cineva_dsp_process(d, in, 2, out, 2, N) == 0, "process avec params changeants");
    CV_CHECK(cv_all_finite(out0, N) && cv_all_finite(out1, N), "params changeants : sortie finie");
    CV_CHECK(cv_peak_abs(out0, N) <= 1.0, "params changeants : borné");
    /* Pas de saut monstrueux entre blocs (anti-zipper, pas d'explosion). */
    if (rep > 0) {
      double jump = fabs((double)out0[0] - prev_last);
      CV_CHECK(jump < 0.9, "transition inter-blocs raisonnable");
    }
    prev_last = out0[N - 1];
  }
  cineva_dsp_destroy(d);
}

static void test_reset(void) {
  printf("test_reset\n");
  cineva_dsp *d = cineva_dsp_create(SR);
  double p[CINEVA_DSP_PARAM_COUNT];
  fill_params_base(p);
  cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);
  float in0[N], in1[N], out0[N], out1[N];
  const float *in[2] = {in0, in1};
  float *out[2] = {out0, out1};
  for (int i = 0; i < N; i++) {
    in0[i] = (float)(0.5 * cv_sine_amp(120.0, SR, i));
    in1[i] = (float)(0.5 * cv_sine_amp(120.0, SR, i));
  }
  cineva_dsp_process(d, in, 2, out, 2, N);
  CV_CHECK(cineva_dsp_reset(d) == 0, "reset ok");
  double m[CINEVA_DSP_METRIC_COUNT];
  cineva_dsp_get_metrics(d, m, CINEVA_DSP_METRIC_COUNT);
  CV_CHECK(m[4] == 0.0, "clippedSamples remis à zéro");
  memset(in0, 0, sizeof(in0));
  memset(in1, 0, sizeof(in1));
  cineva_dsp_process(d, in, 2, out, 2, N);
  CV_CHECK(cv_all_finite(out0, N), "après reset : sortie finie");
  double silence_rms = cv_rms(out0, N);
  CV_CHECK(silence_rms < 1e-4, "après reset : silence → silence");
  cineva_dsp_destroy(d);
}

static void test_metrics_truepeak_reset(void) {
  printf("test_metrics_truepeak_reset\n");
  cineva_dsp *d = cineva_dsp_create(SR);
  double p[CINEVA_DSP_PARAM_COUNT];
  fill_params_base(p);
  cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);
  float in0[N], in1[N], out0[N], out1[N];
  const float *in[2] = {in0, in1};
  float *out[2] = {out0, out1};
  for (int i = 0; i < N; i++) {
    in0[i] = (float)(0.5 * cv_sine_amp(120.0, SR, i));
    in1[i] = in0[i];
  }
  cineva_dsp_process(d, in, 2, out, 2, N);
  double m[CINEVA_DSP_METRIC_COUNT];
  cineva_dsp_get_metrics(d, m, CINEVA_DSP_METRIC_COUNT);
  double first = m[1];
  CV_CHECK(first > -60.0, "true peak mesuré");
  cineva_dsp_get_metrics(d, m, CINEVA_DSP_METRIC_COUNT);
  /* Après lecture, le true peak est remis ; en silence il repart de -inf. */
  CV_CHECK(m[1] < first, "true peak remis après lecture");
  cineva_dsp_destroy(d);
}

static void test_fuzz_stress(void) {
  printf("test_fuzz_stress\n");
  cineva_dsp *d = cineva_dsp_create(SR);
  double p[CINEVA_DSP_PARAM_COUNT];
  float in0[N], in1[N], quad[4][N / 2], out0[N], out1[N];
  float *out[2] = {out0, out1};
  for (int rep = 0; rep < 300; rep++) {
    fill_params_base(p);
    /* Fuzz déterministe : chaque param aléatoire dans une plage délirante. */
    int n_params = 40 + (int)(cv_rng_uniform() * 40);
    for (int k = 0; k < n_params; k++) {
      int idx = (int)(cv_rng_uniform() * CINEVA_DSP_PARAM_COUNT);
      double v = (cv_rng_uniform() * 2.0 - 1.0) * 1e6;
      if (cv_rng_uniform() < 0.1) v = NAN;
      p[idx] = v;
    }
    p[0] = CINEVA_DSP_PARAM_VERSION; /* version préservée */
    p[1] = SR;
    cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);

    int ch = (int)(cv_rng_uniform() * 4); /* 1..4 canaux d'entrée */
    if (ch < 1) ch = 1;
    for (int i = 0; i < N; i++) {
      in0[i] = (float)(cv_rng_uniform() * 2.4 - 1.2);
      in1[i] = (float)(cv_rng_uniform() * 2.4 - 1.2);
    }
    const float *in[2] = {in0, in1};
    if (ch <= 2) {
      CV_CHECK(cineva_dsp_process(d, in, ch, out, 2, N / 2) == 0, "fuzz process");
    } else {
      const float *in4[4] = {quad[0], quad[1], quad[2], quad[3]};
      for (int i = 0; i < N / 2; i++) {
        for (int c = 0; c < 4; c++) quad[c][i] = (float)(cv_rng_uniform() * 2.0 - 1.0);
      }
      CV_CHECK(cineva_dsp_process(d, in4, 4, out, 2, N / 2) == 0, "fuzz process quad");
    }
    CV_CHECK(cv_all_finite(out0, N / 2), "fuzz : sortie L finie");
    CV_CHECK(cv_all_finite(out1, N / 2), "fuzz : sortie R finie");
    CV_CHECK(cv_peak_abs(out0, N / 2) <= 1.0, "fuzz : sortie L bornée");
    CV_CHECK(cv_peak_abs(out1, N / 2) <= 1.0, "fuzz : sortie R bornée");
  }
  cineva_dsp_destroy(d);
}

static void test_sample_rate_change(void) {
  printf("test_sample_rate_change\n");
  cineva_dsp *d = cineva_dsp_create(44100.0);
  double p[CINEVA_DSP_PARAM_COUNT];
  fill_params_base(p);
  p[1] = 44100.0;
  cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);
  float in0[N], in1[N], out0[N], out1[N];
  const float *in[2] = {in0, in1};
  float *out[2] = {out0, out1};
  for (int i = 0; i < N; i++) {
    in0[i] = (float)(0.4 * cv_sine_amp(440.0, 44100.0, i));
    in1[i] = in0[i];
  }
  CV_CHECK(cineva_dsp_process(d, in, 2, out, 2, N) == 0, "44.1 kHz ok");

  p[1] = 96000.0;
  cineva_dsp_set_params(d, p, CINEVA_DSP_PARAM_COUNT);
  for (int i = 0; i < N; i++) {
    in0[i] = (float)(0.4 * cv_sine_amp(440.0, 96000.0, i));
    in1[i] = in0[i];
  }
  CV_CHECK(cineva_dsp_process(d, in, 2, out, 2, N) == 0, "96 kHz ok");
  CV_CHECK(cv_all_finite(out0, N), "96 kHz : sortie finie");
  cineva_dsp_destroy(d);
}

/* ── Golden files (contrat d'équivalence C/Dart/JS) ─────────────────── */

static void golden_write_file(const char *dir, const char *name, const void *data,
                              size_t size) {
  char path[512];
  snprintf(path, sizeof(path), "%s/%s", dir, name);
  FILE *f = fopen(path, "wb");
  if (f == NULL) {
    printf("  ÉCHEC écriture %s\n", path);
    cv_test_failures++;
    return;
  }
  fwrite(data, 1, size, f);
  fclose(f);
}

static void golden_render_case(const char *dir, const char *tag, const double *params,
                               const float *const *input, int channels, int frames) {
  cineva_dsp *d = cineva_dsp_create(params[1]);
  cineva_dsp_set_params(d, params, CINEVA_DSP_PARAM_COUNT);
  cineva_dsp_reset(d);
  float out0[frames], out1[frames];
  float *out[2] = {out0, out1};
  cineva_dsp_process(d, input, channels, out, 2, frames);

  char name[256];
  snprintf(name, sizeof(name), "%s_params.f64", tag);
  golden_write_file(dir, name, params, sizeof(double) * CINEVA_DSP_PARAM_COUNT);
  snprintf(name, sizeof(name), "%s_output.f32", tag);
  float *inter = (float *)malloc(sizeof(float) * 2 * frames);
  for (int i = 0; i < frames; i++) {
    inter[2 * i] = out0[i];
    inter[2 * i + 1] = out1[i];
  }
  golden_write_file(dir, name, inter, sizeof(float) * 2 * frames);
  free(inter);
  cineva_dsp_destroy(d);
}

static int generate_goldens(const char *dir) {
  printf("génération des golden files dans %s\n", dir);
  enum { G_FRAMES = 24000 }; /* 0.5 s @ 48 kHz */

  /* Entrée 1 : bruit stéréo déterministe. */
  float in_l[G_FRAMES], in_r[G_FRAMES];
  cv_rng_state = 0xC1E4A77BULL; /* déterministe */
  for (int i = 0; i < G_FRAMES; i++) {
    in_l[i] = (float)(0.5 * (cv_rng_uniform() * 2.0 - 1.0));
    in_r[i] = (float)(0.5 * (cv_rng_uniform() * 2.0 - 1.0));
  }
  {
    float *inter = (float *)malloc(sizeof(float) * 2 * G_FRAMES);
    for (int i = 0; i < G_FRAMES; i++) {
      inter[2 * i] = in_l[i];
      inter[2 * i + 1] = in_r[i];
    }
    golden_write_file(dir, "input_stereo_noise.f32", inter, sizeof(float) * 2 * G_FRAMES);
    free(inter);
  }

  /* Entrée 2 : 5.1 multitone. */
  float c6[6][G_FRAMES];
  for (int i = 0; i < G_FRAMES; i++) {
    double t = (double)i / 48000.0;
    c6[0][i] = (float)(0.4 * cv_sine_amp(250.0, 48000.0, i));
    c6[1][i] = (float)(0.4 * cv_sine_amp(300.0, 48000.0, i));
    c6[2][i] = (float)(0.5 * cv_sine_amp(1200.0, 48000.0, i) * (0.7 + 0.3 * sin(2 * 3.14159265 * 3.0 * t)));
    c6[3][i] = (float)(0.4 * cv_sine_amp(45.0, 48000.0, i));
    c6[4][i] = (float)(0.3 * (cv_rng_uniform() * 2.0 - 1.0));
    c6[5][i] = (float)(0.3 * (cv_rng_uniform() * 2.0 - 1.0));
  }
  {
    float *flat = (float *)malloc(sizeof(float) * 6 * G_FRAMES);
    for (int i = 0; i < G_FRAMES; i++) {
      for (int c = 0; c < 6; c++) flat[6 * i + c] = c6[c][i];
    }
    golden_write_file(dir, "input_51_multitone.f32", flat, sizeof(float) * 6 * G_FRAMES);
    free(flat);
  }

  const float *in_st[2] = {in_l, in_r};
  const float *in_51[6] = {c6[0], c6[1], c6[2], c6[3], c6[4], c6[5]};

  double p[CINEVA_DSP_PARAM_COUNT];

  /* Cas 1 : profil Cinema stéréo. */
  fill_params_base(p);
  p[9] = -18; p[49] = -28; p[50] = 2.0; p[51] = 6; p[52] = 15; p[53] = 250;
  p[61] = 35; p[69] = 55; p[72] = 5.5; p[81] = 1; p[82] = 100; p[93] = 8;
  p[101] = -0.5;
  golden_render_case(dir, "cinema_stereo_noise", p, in_st, 2, G_FRAMES);

  /* Cas 2 : profil Night stéréo. */
  fill_params_base(p);
  p[9] = -15; p[49] = -34; p[50] = 4.0; p[52] = 5; p[53] = 150; p[55] = 30;
  p[61] = 55; p[69] = 25; p[72] = 3; p[81] = 1; p[82] = 100; p[93] = 3;
  p[101] = -1;
  golden_render_case(dir, "night_stereo_noise", p, in_st, 2, G_FRAMES);

  /* Cas 3 : binaural 5.1 (Immersive). */
  fill_params_base(p);
  p[3] = 6; p[5] = 3; p[9] = -17; p[49] = -28; p[61] = 30; p[69] = 45;
  p[81] = 3; p[83] = 35; p[84] = 100; p[93] = 10; p[101] = -1;
  golden_render_case(dir, "immersive_51_multitone", p, in_51, 6, G_FRAMES);

  /* Cas 4 : bypass A/B (masterEnable = 0). */
  fill_params_base(p);
  p[2] = 0;
  golden_render_case(dir, "bypass_stereo_noise", p, in_st, 2, G_FRAMES);

  /* Cas 5 : Original-like (tout désactivé sauf limiter léger). */
  fill_params_base(p);
  int enables[] = {8, 16, 48, 60, 68, 80, 92};
  for (int i = 0; i < 7; i++) p[enables[i]] = 0;
  golden_render_case(dir, "original_stereo_noise", p, in_st, 2, G_FRAMES);

  return 0;
}

int main(int argc, char **argv) {
  if (argc >= 2) {
    return generate_goldens(argv[1]);
  }

  test_create_and_version();
  test_param_validation();
  test_silence();
  test_bypass_bitexact();
  test_loudness_measurement_and_gain();
  test_limiter_ceiling();
  test_drc_reduces_dynamics();
  test_eq_band_gains();
  test_dialogue_ms();
  test_bass_management();
  test_spatial_width_and_binaural();
  test_room_early_reflections();
  test_channel_mapper();
  test_full_pipeline_stereo_and_multichannel();
  test_low_and_high_levels();
  test_nan_input();
  test_param_changes_during_playback();
  test_reset();
  test_metrics_truepeak_reset();
  test_fuzz_stress();
  test_sample_rate_change();

  printf("\n%d vérifications, %d échec(s)\n", cv_test_checks, cv_test_failures);
  return cv_test_failures == 0 ? 0 : 1;
}
