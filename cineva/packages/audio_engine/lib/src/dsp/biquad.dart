/// Biquad RBJ — miroir exact de `native/cineva_dsp/src/biquad.c`.
/// Transposed direct form II, coefficients interpolés (anti-zipper).
library;

import 'dart:math' as math;
import 'math_ext.dart';

const int bqLowShelf = 0;
const int bqPeaking = 1;
const int bqHighShelf = 2;
const int bqLowPass = 3;
const int bqHighPass = 4;

/// Nombre maximal de canaux gérés par le moteur (miroir de
/// `CINEVA_DSP_MAX_CHANNELS` dans `native/cineva_dsp/include/cineva_dsp.h`).
const int maxChannels = 8;

class Biquad {
  double b0 = 1, b1 = 0, b2 = 0, a1 = 0, a2 = 0;
  double _tb0 = 1, _tb1 = 0, _tb2 = 0, _ta1 = 0, _ta2 = 0;
  double _s1 = 0, _s2 = 0;
  bool _ramp = false;

  void init() {
    b0 = 1; b1 = 0; b2 = 0; a1 = 0; a2 = 0;
    _tb0 = 1; _tb1 = 0; _tb2 = 0; _ta1 = 0; _ta2 = 0;
    _s1 = 0; _s2 = 0;
    _ramp = false;
  }

  void setRaw(double tb0, double tb1, double tb2, double ta1, double ta2) {
    _tb0 = tb0; _tb1 = tb1; _tb2 = tb2; _ta1 = ta1; _ta2 = ta2;
    _ramp = true;
  }

  void snap() {
    b0 = _tb0; b1 = _tb1; b2 = _tb2; a1 = _ta1; a2 = _ta2;
    _ramp = false;
  }

  void resetState() {
    _s1 = 0;
    _s2 = 0;
  }

  void set(int type, double freqHz, double gainDb, double q, double sampleRate) {
    final double fs = sampleRate > 0 ? sampleRate : 48000;
    final double f0 = freqHz.clamp(10.0, fs * 0.49);
    final double qq = q.clamp(0.1, 20.0);
    final double gg = gainDb.clamp(-40.0, 40.0);
    final double a = math.pow(10.0, gg / 40.0).toDouble();
    final double w0 = 2 * math.pi * f0 / fs;
    final double cw = math.cos(w0);
    final double sw = math.sin(w0);
    final double alpha = sw / (2 * qq);

    double b0 = 1, b1 = 0, b2 = 0, a0 = 1, a1 = 0, a2 = 0;
    switch (type) {
      case bqLowShelf:
        final double sq = 2 * math.sqrt(a) * alpha;
        b0 = a * ((a + 1) - (a - 1) * cw + sq);
        b1 = 2 * a * ((a - 1) - (a + 1) * cw);
        b2 = a * ((a + 1) - (a - 1) * cw - sq);
        a0 = (a + 1) + (a - 1) * cw + sq;
        a1 = -2 * ((a - 1) + (a + 1) * cw);
        a2 = (a + 1) + (a - 1) * cw - sq;
      case bqHighShelf:
        final double sq = 2 * math.sqrt(a) * alpha;
        b0 = a * ((a + 1) + (a - 1) * cw + sq);
        b1 = -2 * a * ((a - 1) + (a + 1) * cw);
        b2 = a * ((a + 1) + (a - 1) * cw - sq);
        a0 = (a + 1) - (a - 1) * cw + sq;
        a1 = 2 * ((a - 1) - (a + 1) * cw);
        a2 = (a + 1) - (a - 1) * cw - sq;
      case bqLowPass:
        b0 = (1 - cw) * 0.5;
        b1 = 1 - cw;
        b2 = (1 - cw) * 0.5;
        a0 = 1 + alpha;
        a1 = -2 * cw;
        a2 = 1 - alpha;
      case bqHighPass:
        b0 = (1 + cw) * 0.5;
        b1 = -(1 + cw);
        b2 = (1 + cw) * 0.5;
        a0 = 1 + alpha;
        a1 = -2 * cw;
        a2 = 1 - alpha;
      default: // peaking
        b0 = 1 + alpha * a;
        b1 = -2 * cw;
        b2 = 1 - alpha * a;
        a0 = 1 + alpha / a;
        a1 = -2 * cw;
        a2 = 1 - alpha / a;
    }
    if (!(a0 > 0) || a0.isNaN) a0 = 1;
    setRaw(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
  }

  double tick(double x, double rampCoef) {
    if (_ramp) {
      b0 += (_tb0 - b0) * rampCoef;
      b1 += (_tb1 - b1) * rampCoef;
      b2 += (_tb2 - b2) * rampCoef;
      a1 += (_ta1 - a1) * rampCoef;
      a2 += (_ta2 - a2) * rampCoef;
      final double e0 = b0 - _tb0;
      final double e1 = b1 - _tb1;
      final double e2 = b2 - _tb2;
      final double e3 = a1 - _ta1;
      final double e4 = a2 - _ta2;
      if (e0 * e0 + e1 * e1 + e2 * e2 + e3 * e3 + e4 * e4 < 1e-18) {
        snap();
      }
    }
    final double y = b0 * x + _s1;
    _s1 = b1 * x - a1 * y + _s2;
    _s2 = b2 * x - a2 * y;
    return y;
  }
}

/// Utilitaires DSP partagés (miroir de dsp_util.h).
double clampD(double v, double lo, double hi) {
  if (v.isNaN) return lo;
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}

double sanitizeD(double v) => (v.isFinite && v > -1e30 && v < 1e30) ? v : 0.0;

double dbToLin(double db) => math.pow(10.0, db / 20.0).toDouble();

double linToDb(double lin) => 20 * log10(lin > 1e-12 ? lin : 1e-12);

double onepoleCoef(double sampleRate, double tauSeconds) {
  if (tauSeconds <= 0 || sampleRate <= 0) return 0;
  return math.exp(-1 / (sampleRate * tauSeconds));
}
