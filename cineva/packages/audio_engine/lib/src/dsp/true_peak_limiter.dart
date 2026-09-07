/// Limiteur true-peak lookahead — miroir de `limiter.c`.
library;

import 'biquad.dart' as dsp;

const int _limiterMaxDelay = 4096;

class TruePeakLimiter {
  TruePeakLimiter(this.sampleRate) {
    set(false, -1, 5, 120);
    enable = false;
  }

  final double sampleRate;
  bool enable = false;
  double ceilingDb = -1;
  double lookaheadMs = 5;
  double releaseMs = 120;

  double ceilingLin = 0.891;
  int delaySmp = 240;
  final List<List<double>> delay = <List<double>>[
    List<double>.filled(_limiterMaxDelay, 0),
    List<double>.filled(_limiterMaxDelay, 0),
  ];
  int pos = 0;
  double envLin = 1;
  double attCoef = 0;
  double relCoef = 0;
  double currentGain = 1;

  void set(bool enable, double ceilingDb, double lookaheadMs, double releaseMs) {
    this.enable = enable;
    this.ceilingDb = dsp.clampD(dsp.sanitizeD(ceilingDb), -6, 0);
    this.lookaheadMs = dsp.clampD(dsp.sanitizeD(lookaheadMs), 1, 10);
    this.releaseMs = dsp.clampD(dsp.sanitizeD(releaseMs), 40, 500);
    ceilingLin = dsp.dbToLin(this.ceilingDb);
    int d = (this.lookaheadMs * 0.001 * sampleRate).toInt();
    if (d < 1) d = 1;
    if (d > _limiterMaxDelay) d = _limiterMaxDelay;
    if (d != delaySmp) {
      delaySmp = d;
      reset();
    }
    attCoef = dsp.onepoleCoef(sampleRate, this.lookaheadMs / 1000 / 3);
    relCoef = dsp.onepoleCoef(sampleRate, this.releaseMs / 1000);
  }

  void reset() {
    delay[0] = List<double>.filled(_limiterMaxDelay, 0);
    delay[1] = List<double>.filled(_limiterMaxDelay, 0);
    pos = 0;
    envLin = 1;
    currentGain = 1;
  }

  /// Crête sur-échantillonnée ×4, miroir exact de `cv_limiter_tp4`
  /// (appelé avec x3 = x2 côté C).
  static double _tp4(double x0, double x1, double x2) {
    final double a0 = -0.1875 * x0 + 0.5625 * x1 + 0.5625 * x2 - 0.1875 * x2;
    final double a1 = -0.5 * x1 + 0.5 * x2;
    final double a2 = 0.1875 * x0 - 0.75 * x1 + 0.75 * x2 - 0.1875 * x2;
    final double c0 = x1;
    final double c1 = a0 - 0.375 * a2 - c0;
    final double c2 = 0.25 * a2 - 0.5 * a1;
    double peak = c0.abs();
    for (int k = 1; k <= 3; k++) {
      final double t = k * 0.25;
      final double v = ((c2 * t + c1) * t + a1) * t + c0;
      final double av = v.abs();
      if (av > peak) peak = av;
    }
    return peak;
  }

  void process(List<Float32List> in_, List<Float32List> out, int frames) {
    if (!enable) {
      if (!identical(out[0], in_[0])) {
        for (int i = 0; i < frames; i++) {
          out[0][i] = in_[0][i];
        }
      }
      if (!identical(out[1], in_[1])) {
        for (int i = 0; i < frames; i++) {
          out[1][i] = in_[1][i];
        }
      }
      return;
    }
    final int d = delaySmp;
    const int len = _limiterMaxDelay;

    for (int i = 0; i < frames; i++) {
      final double l = dsp.sanitizeD(in_[0][i]);
      final double r = dsp.sanitizeD(in_[1][i]);

      final int p = pos;
      final int im1 = (p + len - 1) % len;
      final int im2 = (p + len - 2) % len;
      final double lp0 = delay[0][im2];
      final double lp1 = delay[0][im1];
      final double rp0 = delay[1][im2];
      final double rp1 = delay[1][im1];
      double peak = _tp4(lp0, lp1, l);
      final double peakR = _tp4(rp0, rp1, r);
      if (peakR > peak) peak = peakR;

      delay[0][p] = l;
      delay[1][p] = r;

      double need = 1;
      if (peak > ceilingLin) need = ceilingLin / peak;
      if (need < envLin) {
        envLin = need;
      } else {
        envLin = relCoef * envLin + (1 - relCoef) * need;
      }

      final double target = envLin;
      if (target < currentGain) {
        currentGain = attCoef * currentGain + (1 - attCoef) * target;
        if (currentGain < target) currentGain = target;
      } else {
        currentGain = relCoef * currentGain + (1 - relCoef) * target;
      }

      final int opos = (p + len - d) % len;
      out[0][i] = delay[0][opos] * currentGain;
      out[1][i] = delay[1][opos] * currentGain;

      pos = (p + 1) % len;
    }
  }

  double get gainDb => dsp.linToDb(currentGain);
}
