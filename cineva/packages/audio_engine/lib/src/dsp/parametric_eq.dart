/// Égaliseur paramétrique 6 bandes — miroir de `param_eq.c`.
library;

import 'biquad.dart' as dsp;
import 'biquad.dart' show Biquad;

const int eqBands = 6;

class ParametricEq {
  ParametricEq(this.sampleRate) {
    const defFreq = <double>[45, 90, 300, 1200, 3500, 10000];
    const defType = <int>[dsp.bqLowShelf, dsp.bqPeaking, dsp.bqPeaking,
        dsp.bqPeaking, dsp.bqPeaking, dsp.bqHighShelf];
    for (int i = 0; i < eqBands; i++) {
      types.add(defType[i]);
      freq.add(defFreq[i]);
      gainDb.add(0);
      q.add(0.9);
      bands.add(<Biquad>[Biquad(), Biquad()]);
      bands[i][0].init();
      bands[i][1].init();
    }
  }

  final double sampleRate;
  bool enable = false;
  final List<int> types = <int>[];
  final List<double> freq = <double>[];
  final List<double> gainDb = <double>[];
  final List<double> q = <double>[];
  final List<List<Biquad>> bands = <List<Biquad>>[];
  bool _dirty = true;

  void set(bool enable, List<int>? types, List<double>? freq, List<double>? gainDb,
      List<double>? q) {
    this.enable = enable;
    if (types != null && freq != null && gainDb != null && q != null) {
      for (int i = 0; i < eqBands; i++) {
        int t = types[i];
        if (t < dsp.bqLowShelf || t > dsp.bqHighPass) t = dsp.bqPeaking;
        final double f = dsp.clampD(dsp.sanitizeD(freq[i]), 20, 20000);
        final double g = dsp.clampD(dsp.sanitizeD(gainDb[i]), -15, 15);
        final double qq = dsp.clampD(dsp.sanitizeD(q[i]), 0.3, 4);
        if (t != this.types[i] ||
            f != this.freq[i] ||
            g != this.gainDb[i] ||
            qq != this.q[i]) {
          this.types[i] = t;
          this.freq[i] = f;
          this.gainDb[i] = g;
          this.q[i] = qq;
          _dirty = true;
        }
      }
    }
  }

  void reset() {
    for (int i = 0; i < eqBands; i++) {
      bands[i][0].resetState();
      bands[i][1].resetState();
    }
  }

  void process(List<Float32List> io, int channels, int frames) {
    if (!enable) return;
    if (channels < 1 || channels > 2) return;
    if (_dirty) {
      for (int i = 0; i < eqBands; i++) {
        for (int ch = 0; ch < 2; ch++) {
          bands[i][ch].set(types[i], freq[i], gainDb[i], q[i], sampleRate);
        }
      }
      _dirty = false;
    }
    final double ramp = 1 - dsp.onepoleCoef(sampleRate, 0.02);
    for (int i = 0; i < frames; i++) {
      double l = dsp.sanitizeD(io[0][i]);
      double r = channels > 1 ? dsp.sanitizeD(io[1][i]) : l;
      for (int b = 0; b < eqBands; b++) {
        l = bands[b][0].tick(l, ramp);
        r = bands[b][1].tick(r, ramp);
      }
      io[0][i] = l;
      if (channels > 1) io[1][i] = r;
    }
  }
}
