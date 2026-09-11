#define _POSIX_C_SOURCE 199309L

/*
 * Benchmark du cœur DSP Cineva.
 * Mesure le temps CPU par bloc et le facteur temps réel sur des
 * configurations représentatives (48/96 kHz, stéréo/5.1, profils complets).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "../include/cineva_dsp.h"
#include "test_util.h"

static double now_seconds(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

static void fill_full_profile(double *p, double sr, int channels) {
  memset(p, 0, sizeof(double) * CINEVA_DSP_PARAM_COUNT);
  p[0] = CINEVA_DSP_PARAM_VERSION;
  p[1] = sr;
  p[2] = 1;
  p[3] = channels;
  p[4] = 2;
  p[5] = channels >= 6 ? 3 : (channels >= 4 ? 2 : (channels >= 2 ? 1 : 0));
  p[8] = 1; p[9] = -18; p[12] = 1.5;
  p[16] = 1;
  {
    static const int types[6] = {0, 1, 1, 1, 1, 2};
    static const double freqs[6] = {45, 90, 300, 1200, 3500, 10000};
    static const double gains[6] = {2, 1.5, -1, 0.5, 1, 2};
    for (int i = 0; i < 6; i++) {
      p[17 + 5 * i] = types[i];
      p[18 + 5 * i] = freqs[i];
      p[19 + 5 * i] = gains[i];
      p[20 + 5 * i] = 0.9;
    }
  }
  p[48] = 1; p[49] = -28; p[50] = 2; p[56] = 1;
  p[60] = 1; p[61] = 35;
  p[68] = 1; p[69] = 55; p[72] = 5.5; p[73] = 30;
  p[80] = 1;
  p[81] = channels > 2 ? 2 : 1;
  p[82] = 110; p[83] = 30; p[84] = 100;
  p[92] = 1; p[93] = 8;
  p[100] = 1; p[101] = -1; p[102] = 5; p[103] = 120;
}

static void run_case(const char *label, double sr, int channels, int block,
                     double seconds) {
  cineva_dsp *dsp = cineva_dsp_create(sr);
  double p[CINEVA_DSP_PARAM_COUNT];
  fill_full_profile(p, sr, channels);
  cineva_dsp_set_params(dsp, p, CINEVA_DSP_PARAM_COUNT);

  int total = (int)(seconds * sr);
  int blocks = (total + block - 1) / block;

  static float chans[CINEVA_DSP_MAX_CHANNELS][CINEVA_DSP_MAX_BLOCK];
  static float out[2][CINEVA_DSP_MAX_BLOCK];
  const float *in[CINEVA_DSP_MAX_CHANNELS];
  float *outp[2] = {out[0], out[1]};
  cv_rng_state = 424242ULL;
  for (int ch = 0; ch < channels; ch++) {
    in[ch] = chans[ch];
    for (int i = 0; i < block; i++) {
      chans[ch][i] = (float)(0.4 * (cv_rng_uniform() * 2.0 - 1.0));
    }
  }

  double t0 = now_seconds();
  for (int b = 0; b < blocks; b++) {
    cineva_dsp_process(dsp, in, channels, outp, 2, block);
  }
  double dt = now_seconds() - t0;
  double audio_seconds = (double)blocks * block / sr;
  double xrealtime = audio_seconds / dt;
  double us_per_block = dt * 1e6 / (double)blocks;
  printf("%-28s %6.2f s audio en %7.1f ms  →  %8.1f× temps réel  (%6.1f µs/bloc de %d)\n",
         label, audio_seconds, dt * 1e3, xrealtime, us_per_block, block);
  cineva_dsp_destroy(dsp);
}

int main(void) {
  printf("Cineva Audio Engine — benchmark du cœur DSP (%s)\n\n", cineva_dsp_version());
  run_case("stéréo 48 kHz, bloc 512", 48000, 2, 512, 10.0);
  run_case("stéréo 48 kHz, bloc 128", 48000, 2, 128, 10.0);
  run_case("5.1 48 kHz, bloc 512", 48000, 6, 512, 10.0);
  run_case("7.1 48 kHz, bloc 512", 48000, 8, 512, 10.0);
  run_case("stéréo 96 kHz, bloc 512", 96000, 2, 512, 10.0);
  run_case("5.1 96 kHz, bloc 1024", 96000, 6, 1024, 10.0);
  printf("\nUn facteur > 10× temps réel laisse une marge confortable pour un "
         "thread audio temps réel.\n");
  return 0;
}
