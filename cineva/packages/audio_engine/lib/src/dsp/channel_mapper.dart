/// Channel Mapper — miroir de `native/cineva_dsp/src/channel_mapper.c`.
library;

import 'biquad.dart' as dsp;

const int layoutMono = 0;
const int layoutStereo = 1;
const int layoutQuad = 2;
const int layout51 = 3;
const int layout71 = 4;

const int maxChannels = 8;

int layoutFromChannels(int channels) {
  switch (channels) {
    case 1:
      return layoutMono;
    case 2:
      return layoutStereo;
    case 4:
      return layoutQuad;
    case 6:
      return layout51;
    case 8:
      return layout71;
    default:
      return channels > 2 ? layout71 : (channels < 1 ? layoutMono : layoutStereo);
  }
}

/// Poids BS.1770 par canal (L/R/C = 1, surrounds = √2, LFE = 0).
void mapperWeights(int layout, int channels, List<double> weights) {
  for (int i = 0; i < maxChannels; i++) {
    weights[i] = 1.0;
  }
  if (layout >= layout51 && channels >= 6) {
    weights[4] = 1.4142135623730951; // Ls
    weights[5] = 1.4142135623730951; // Rs
    weights[3] = 0.0; // LFE exclu de la mesure
  }
  if (layout >= layout71 && channels >= 8) {
    weights[6] = 1.4142135623730951; // Lb
    weights[7] = 1.4142135623730951; // Rb
  }
}

/// Downmix ITU-R BS.775 vers la stéréo. `lfeGainLin` = 0 ⇒ LFE ignoré.
void downmixItu(
  List<Float32List> in_,
  int channels,
  int layout,
  List<Float32List> out,
  double lfeGainLin,
  int frames,
) {
  final double lg = dsp.sanitizeD(lfeGainLin).clamp(0.0, double.infinity);
  if (channels <= 1) {
    for (int i = 0; i < frames; i++) {
      out[0][i] = in_[0][i];
      out[1][i] = in_[0][i];
    }
    return;
  }
  final bool hasCenter = layout >= layout51 && channels >= 6;
  final bool hasSurround = layout >= layoutQuad && channels >= 4;
  final bool hasLfe = layout >= layout51 && channels >= 6;
  final bool hasBack = layout >= layout71 && channels >= 8;
  for (int i = 0; i < frames; i++) {
    double l = dsp.sanitizeD(in_[0][i]);
    double r = dsp.sanitizeD(in_[1][i]);
    if (hasCenter) {
      final double c = dsp.sanitizeD(in_[2][i]) * 0.7071067811865476;
      l += c;
      r += c;
    }
    if (hasSurround) {
      l += dsp.sanitizeD(in_[4 % channels][i]) * 0.7071067811865476;
      r += dsp.sanitizeD(in_[5 % channels][i]) * 0.7071067811865476;
    }
    if (hasBack) {
      l += dsp.sanitizeD(in_[6][i]) * 0.7071067811865476;
      r += dsp.sanitizeD(in_[7][i]) * 0.7071067811865476;
    }
    if (hasLfe && lg > 0) {
      final double lfe = dsp.sanitizeD(in_[3][i]) * lg;
      l += lfe;
      r += lfe;
    }
    out[0][i] = l;
    out[1][i] = r;
  }
}
