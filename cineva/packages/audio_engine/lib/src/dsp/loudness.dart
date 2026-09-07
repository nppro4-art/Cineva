/// Loudness ITU-R BS.1770-4 — miroir de `native/cineva_dsp/src/loudness.c`.
library;

import 'dart:math' as math;

import 'biquad.dart' as dsp;
import 'biquad.dart' show Biquad;

const int _loudnessHops = 600;
const int _loudnessSilenceBlocks = 10;
const double _loudnessOffset = -0.691;

class LoudnessProcessor {
  LoudnessProcessor(this.sampleRate) {
    hopLen = (sampleRate * 0.1).toInt();
    if (hopLen < 1) hopLen = 1;
    for (int i = 0; i < dsp.maxChannels; i++) {
      k1.add(Biquad());
      k2.add(Biquad());
      k1[i].init();
      k2[i].init();
      k1[i].set(2, 1681.97, 3.9998, 0.7071752369556, sampleRate); // high shelf
      k2[i].set(4, 38.13, 0, 0.5003270372833, sampleRate); // high pass RLB
      k1[i].snap();
      k2[i].snap();
      hopMs.add(0);
    }
    hopZ = List<double>.filled(_loudnessHops, 0);
    set(true, -16, 8, 8, 1.5);
  }

  final double sampleRate;
  bool enable = false;
  double targetLufs = -16;
  double maxGainDb = 8;
  double maxAttDb = 8;
  double adaptRateDbS = 1.5;

  late int hopLen;
  int hopPos = 0;
  final List<double> hopMs = <double>[];
  final List<Biquad> k1 = <Biquad>[];
  final List<Biquad> k2 = <Biquad>[];
  late List<double> hopZ;
  int hopCount = 0;
  int hopHead = 0;
  int silentRun = 0;

  double integratedLufs = -70;
  double gainDb = 0;
  double targetGainDb = 0;

  void set(bool enable, double targetLufs, double maxGainDb, double maxAttDb,
      double adaptRateDbS) {
    this.enable = enable;
    this.targetLufs = dsp.clampD(dsp.sanitizeD(targetLufs), -36, -8);
    this.maxGainDb = dsp.clampD(dsp.sanitizeD(maxGainDb), 0, 12);
    maxAttDb = dsp.clampD(dsp.sanitizeD(maxAttDb), 0, 12);
    this.maxAttDb = maxAttDb;
    this.adaptRateDbS = dsp.clampD(dsp.sanitizeD(adaptRateDbS), 0.1, 6);
  }

  void reset() {
    hopPos = 0;
    for (int i = 0; i < dsp.maxChannels; i++) {
      hopMs[i] = 0;
    }
    hopZ = List<double>.filled(_loudnessHops, 0);
    hopCount = 0;
    hopHead = 0;
    silentRun = 0;
    integratedLufs = -70;
    gainDb = 0;
    targetGainDb = 0;
    for (int i = 0; i < dsp.maxChannels; i++) {
      k1[i].resetState();
      k2[i].resetState();
    }
  }

  void _recompute() {
    final int n = hopCount;
    if (n <= 0) {
      integratedLufs = -70;
      return;
    }
    double sum = 0;
    int count = 0;
    for (int i = 0; i < n; i++) {
      final double z = hopZ[i];
      if (z <= 0) continue;
      final double lb = _loudnessOffset + 10 * _log10(z);
      if (lb > -70) {
        sum += z;
        count++;
      }
    }
    if (count == 0 || sum <= 0) {
      integratedLufs = -70;
      return;
    }
    final double meanZ = sum / count;
    final double relThreshold = _loudnessOffset + 10 * _log10(meanZ) - 10;
    double sum2 = 0;
    int count2 = 0;
    for (int i = 0; i < n; i++) {
      final double z = hopZ[i];
      if (z <= 0) continue;
      final double lb = _loudnessOffset + 10 * _log10(z);
      if (lb > -70 && lb > relThreshold) {
        sum2 += z;
        count2++;
      }
    }
    if (count2 == 0 || sum2 <= 0) {
      integratedLufs = -70;
      return;
    }
    integratedLufs = _loudnessOffset + 10 * _log10(sum2 / count2);
  }

  static double _log10(double x) => math.log(x) / math.ln10;

  void process(List<Float32List> in_, List<Float32List> out, int channels,
      int frames, List<double> weights) {
    if (channels < 1 || channels > dsp.maxChannels) return;
    final double ramp = 1 - dsp.onepoleCoef(sampleRate, 0.02);
    final double gainStepDb = adaptRateDbS / sampleRate;

    for (int ch = 0; ch < channels; ch++) {
      if (!identical(out[ch], in_[ch])) {
        for (int i = 0; i < frames; i++) {
          out[ch][i] = in_[ch][i];
        }
      }
    }

    if (!enable) {
      gainDb = 0;
      targetGainDb = 0;
      return;
    }

    for (int i = 0; i < frames; i++) {
      for (int ch = 0; ch < channels; ch++) {
        final double x = dsp.sanitizeD(in_[ch][i]);
        double y = k1[ch].tick(x, ramp);
        y = k2[ch].tick(y, ramp);
        hopMs[ch] += y * y;
      }

      hopPos++;
      if (hopPos >= hopLen) {
        hopPos = 0;
        double z = 0;
        for (int ch = 0; ch < channels; ch++) {
          final double ms = hopMs[ch] / hopLen;
          z += weights[ch] * ms;
          hopMs[ch] = 0;
        }
        hopZ[hopHead] = z;
        hopHead = (hopHead + 1) % _loudnessHops;
        if (hopCount < _loudnessHops) hopCount++;

        if (z < 1e-10) {
          silentRun++;
        } else {
          silentRun = 0;
        }
        _recompute();

        if (silentRun >= _loudnessSilenceBlocks || integratedLufs <= -69.9) {
          targetGainDb = gainDb; // gel pendant le silence
        } else {
          final double want = targetLufs - integratedLufs;
          targetGainDb = dsp.clampD(want, -maxAttDb, maxGainDb);
        }
      }

      if (gainDb < targetGainDb) {
        gainDb += gainStepDb;
        if (gainDb > targetGainDb) gainDb = targetGainDb;
      } else if (gainDb > targetGainDb) {
        gainDb -= gainStepDb;
        if (gainDb < targetGainDb) gainDb = targetGainDb;
      }

      final double g = dsp.dbToLin(gainDb);
      for (int ch = 0; ch < channels; ch++) {
        out[ch][i] = dsp.sanitizeD(out[ch][i]) * g;
      }
    }
  }
}

