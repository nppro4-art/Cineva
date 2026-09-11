/// Compresseur soft-knee stéréo-linké — miroir de `drc.c`.
library;

import 'dart:math' as math;

import 'biquad.dart' as dsp;
import 'dart:typed_data';

class DynamicRangeCompressor {
  DynamicRangeCompressor(this.sampleRate) {
    set(false, -24, 2.5, 6, 15, 250, 0, 100, 1);
  }

  final double sampleRate;
  bool enable = false;
  double thresholdDb = -24;
  double ratio = 2.5;
  double kneeDb = 6;
  double attackMs = 15;
  double releaseMs = 250;
  double makeupDb = 0;
  double mix = 1;
  int detector = 1;

  double attCoef = 0;
  double relCoef = 0;
  double rmsCoef = 0;
  double envDb = -70;
  double gainDb = 0;
  double rmsStateCache = 0;

  void set(bool enable, double thresholdDb, double ratio, double kneeDb,
      double attackMs, double releaseMs, double makeupDb, double mixPercent,
      int detector) {
    this.enable = enable;
    this.thresholdDb = dsp.clampD(dsp.sanitizeD(thresholdDb), -60, 0);
    this.ratio = dsp.clampD(dsp.sanitizeD(ratio), 1, 20);
    this.kneeDb = dsp.clampD(dsp.sanitizeD(kneeDb), 0, 24);
    this.attackMs = dsp.clampD(dsp.sanitizeD(attackMs), 0.5, 200);
    this.releaseMs = dsp.clampD(dsp.sanitizeD(releaseMs), 20, 1000);
    this.makeupDb = dsp.clampD(dsp.sanitizeD(makeupDb), -6, 12);
    mix = dsp.clampD(dsp.sanitizeD(mixPercent), 0, 100) / 100;
    this.detector = detector == 0 ? 0 : 1;
    attCoef = dsp.onepoleCoef(sampleRate, this.attackMs / 1000);
    relCoef = dsp.onepoleCoef(sampleRate, this.releaseMs / 1000);
    rmsCoef = dsp.onepoleCoef(sampleRate, 0.010);
  }

  void reset() {
    envDb = -70;
    gainDb = 0;
    rmsStateCache = 0;
  }

  double _computeGainDb(double levelDb) {
    final double thr = thresholdDb;
    final double knee = kneeDb;
    final double slope = 1 / ratio - 1;
    final double over = levelDb - thr;
    if (knee > 0 && 2 * over < knee && 2 * over > -knee) {
      final double x = over + knee * 0.5;
      return slope * x * x / (2 * knee);
    }
    if (over <= 0) return 0;
    return slope * over;
  }

  void process(List<Float32List> io, int channels, int frames) {
    if (!enable) return;
    if (channels < 1 || channels > 2) return;
    double rmsState = rmsStateCache;
    final double makeup = dsp.dbToLin(makeupDb);
    final double dryMix = 1 - mix;

    for (int i = 0; i < frames; i++) {
      final double l = dsp.sanitizeD(io[0][i]);
      final double r = channels > 1 ? dsp.sanitizeD(io[1][i]) : l;

      double level;
      if (detector == 0) {
        final double al = l.abs();
        final double ar = r.abs();
        level = al > ar ? al : ar;
      } else {
        final double ms = (l * l + r * r) * 0.5;
        rmsState = rmsCoef * rmsState + (1 - rmsCoef) * ms;
        level = rmsState <= 0 ? 0 : math.sqrt(rmsState);
      }
      final double levelDb = dsp.linToDb(level);

      if (levelDb > envDb) {
        envDb = attCoef * envDb + (1 - attCoef) * levelDb;
      } else {
        envDb = relCoef * envDb + (1 - relCoef) * levelDb;
      }

      final double targetGain = _computeGainDb(envDb);
      if (targetGain < gainDb) {
        gainDb = attCoef * gainDb + (1 - attCoef) * targetGain;
      } else {
        gainDb = relCoef * gainDb + (1 - relCoef) * targetGain;
      }
      final double wetGain = dsp.dbToLin(gainDb) * makeup;
      final double g = dryMix + wetGain * mix;
      io[0][i] = l * g;
      if (channels > 1) io[1][i] = r * g;
    }
    rmsStateCache = rmsState;
  }
}
