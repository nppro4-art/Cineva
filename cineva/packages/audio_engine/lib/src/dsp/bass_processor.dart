/// Bass Processor — miroir de `bass.c`.
library;

import 'dart:math' as math;

import 'biquad.dart' as dsp;
import 'biquad.dart' show Biquad;

class BassProcessor {
  BassProcessor(this.sampleRate) {
    for (int ch = 0; ch < 2; ch++) {
      lp.add(<Biquad>[Biquad(), Biquad()]);
      hp.add(<Biquad>[Biquad(), Biquad()]);
      subShelf.add(Biquad());
      harmHp.add(Biquad());
      for (int s = 0; s < 2; s++) {
        lp[ch][s].init();
        hp[ch][s].init();
      }
      subShelf[ch].init();
      harmHp[ch].init();
    }
  }

  final double sampleRate;
  bool enable = false;
  double intensity = 0.5;
  double crossoverHz = 80;
  int speakerMode = 0;
  double subShelfGainDb = 5;
  double harmonicDrive = 0;
  double lfeGainDb = 0;

  final List<List<Biquad>> lp = <List<Biquad>>[];
  final List<List<Biquad>> hp = <List<Biquad>>[];
  final List<Biquad> subShelf = <Biquad>[];
  final List<Biquad> harmHp = <Biquad>[];
  double bandEnv = 0;
  final double bandThrLin = dsp.dbToLin(-1);
  bool _dirty = true;

  void set(bool enable, double intensityPercent, double crossoverHz,
      int speakerMode, double subShelfGainDb, double harmonicDrivePercent,
      double lfeGainDb) {
    final bool wasDisabled = !this.enable;
    this.enable = enable;
    intensity = dsp.clampD(dsp.sanitizeD(intensityPercent), 0, 100) / 100;
    final double xo = dsp.clampD(dsp.sanitizeD(crossoverHz), 50, 160);
    if (xo != this.crossoverHz) {
      this.crossoverHz = xo;
      _dirty = true;
    }
    int mode = speakerMode;
    if (mode < 0 || mode > 2) mode = 0;
    if (mode != this.speakerMode) {
      this.speakerMode = mode;
      _dirty = true;
    }
    this.subShelfGainDb = dsp.clampD(dsp.sanitizeD(subShelfGainDb), -6, 9);
    double drive = dsp.clampD(dsp.sanitizeD(harmonicDrivePercent), 0, 100) / 100;
    if (this.speakerMode == 0 || this.speakerMode == 2) drive = 0;
    if (drive != harmonicDrive) {
      harmonicDrive = drive;
      _dirty = true;
    }
    this.lfeGainDb = dsp.clampD(dsp.sanitizeD(lfeGainDb), -12, 6);
    if (wasDisabled && this.enable) _dirty = true;
  }

  void _updateFilters() {
    for (int ch = 0; ch < 2; ch++) {
      for (int s = 0; s < 2; s++) {
        lp[ch][s].set(dsp.bqLowPass, crossoverHz, 0, 0.7071, sampleRate);
        hp[ch][s].set(dsp.bqHighPass, crossoverHz, 0, 0.7071, sampleRate);
      }
      double subDb = subShelfGainDb * intensity;
      if (speakerMode == 2) subDb *= 0.6;
      if (speakerMode == 1) subDb *= 0.8;
      subShelf[ch].set(dsp.bqLowShelf, 50, subDb, 0.707, sampleRate);
      harmHp[ch].set(dsp.bqHighPass, crossoverHz * 0.9, 0, 0.707, sampleRate);
    }
    _dirty = false;
  }

  void reset() {
    for (int ch = 0; ch < 2; ch++) {
      for (int s = 0; s < 2; s++) {
        lp[ch][s].resetState();
        hp[ch][s].resetState();
      }
      subShelf[ch].resetState();
      harmHp[ch].resetState();
    }
    bandEnv = 0;
  }

  void process(List<Float32List> io, Float32List? lfe, int frames) {
    if (!enable) return;
    if (_dirty) _updateFilters();
    final double ramp = 1 - dsp.onepoleCoef(sampleRate, 0.02);
    final double rel = dsp.onepoleCoef(sampleRate, 0.020);
    final double lfeGain = lfe != null ? dsp.dbToLin(lfeGainDb) : 0;
    final double driveK = 1 + 2 * harmonicDrive;
    final double driveNorm = math.tanh(driveK);

    final List<double> low = <double>[0, 0];
    final List<double> high = <double>[0, 0];

    for (int i = 0; i < frames; i++) {
      for (int ch = 0; ch < 2; ch++) {
        final double x = dsp.sanitizeD(io[ch][i]);
        double l = lp[ch][0].tick(x, ramp);
        l = lp[ch][1].tick(l, ramp);
        double h = hp[ch][0].tick(x, ramp);
        h = hp[ch][1].tick(h, ramp);
        low[ch] = l;
        high[ch] = h;
      }

      if (lfe != null) {
        final double l = dsp.sanitizeD(lfe[i]) * lfeGain;
        low[0] += l;
        low[1] += l;
      }

      low[0] = subShelf[0].tick(low[0], ramp);
      low[1] = subShelf[1].tick(low[1], ramp);

      if (harmonicDrive > 0) {
        for (int ch = 0; ch < 2; ch++) {
          final double sat = math.tanh(low[ch] * driveK) / driveNorm;
          double harm = sat - low[ch];
          harm = harmHp[ch].tick(harm, ramp);
          high[ch] += harm * harmonicDrive;
        }
      }

      final double al = low[0].abs();
      final double ar = low[1].abs();
      final double peak = al > ar ? al : ar;
      double need = 1;
      if (peak > bandThrLin) need = bandThrLin / peak;
      if (need < bandEnv) {
        bandEnv = need;
      } else {
        bandEnv = rel * bandEnv + (1 - rel) * need;
      }
      io[0][i] = low[0] * bandEnv + high[0];
      io[1][i] = low[1] * bandEnv + high[1];
    }
  }
}
