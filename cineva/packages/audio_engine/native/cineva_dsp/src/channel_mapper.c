#include "channel_mapper.h"

#include <string.h>

#include "dsp_util.h"

int cv_layout_from_channels(int channels) {
  switch (channels) {
    case 1: return 0;
    case 2: return 1;
    case 4: return 2;
    case 6: return 3;
    case 8: return 4;
    default: return channels > 2 ? 4 : (channels < 1 ? 0 : 1);
  }
}

void cv_mapper_weights(int layout, int channels, double *weights) {
  for (int i = 0; i < CINEVA_DSP_MAX_CHANNELS; i++) weights[i] = 1.0;
  if (layout >= 3 && channels >= 6) {
    weights[4] = 1.4142135623730951; /* Ls */
    weights[5] = 1.4142135623730951; /* Rs */
    weights[3] = 0.0;                /* LFE exclu de la mesure */
  }
  if (layout >= 4 && channels >= 8) {
    weights[6] = 1.4142135623730951; /* Lb */
    weights[7] = 1.4142135623730951; /* Rb */
  }
}

void cv_mapper_downmix_itu(const float *const *in, int channels, int layout,
                           float *const *out, double lfe_gain_lin, int frames) {
  double lg = cv_sanitize_d(lfe_gain_lin);
  if (lg < 0.0) lg = 0.0;

  if (channels <= 1) {
    for (int i = 0; i < frames; i++) {
      float x = in[0][i];
      out[0][i] = x;
      out[1][i] = x;
    }
    return;
  }

  int has_center = layout >= 3 && channels >= 6;
  int has_surround = layout >= 2 && channels >= 4;
  int has_lfe = layout >= 3 && channels >= 6;
  int has_back = layout >= 4 && channels >= 8;

  for (int i = 0; i < frames; i++) {
    double l = cv_sanitize_f(in[0][i]);
    double r = cv_sanitize_f(in[1][i]);
    if (has_center) {
      double c = cv_sanitize_f(in[2][i]) * 0.7071067811865476;
      l += c;
      r += c;
    }
    if (has_surround) {
      l += cv_sanitize_f(in[4 % channels][i]) * 0.7071067811865476;
      r += cv_sanitize_f(in[5 % channels][i]) * 0.7071067811865476;
    }
    if (has_back) {
      l += cv_sanitize_f(in[6][i]) * 0.7071067811865476;
      r += cv_sanitize_f(in[7][i]) * 0.7071067811865476;
    }
    if (has_lfe && lg > 0.0) {
      double lfe = cv_sanitize_f(in[3][i]) * lg;
      l += lfe;
      r += lfe;
    }
    out[0][i] = (float)l;
    out[1][i] = (float)r;
  }
}
