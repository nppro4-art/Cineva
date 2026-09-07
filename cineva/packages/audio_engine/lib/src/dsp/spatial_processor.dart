/// Spatial Processor — miroir de `spatial.c`.
library;

import 'dart:math' as math;

import 'biquad.dart' as dsp;
import 'biquad.dart' show Biquad;
import 'channel_mapper.dart' as mapper;

const int spatialModeOff = 0;
const int spatialModeWidth = 1;
const int spatialModeBinaural = 2;
const int spatialModeBinauralCrossfeed = 3;

const int _maxDelay = 512;

double _azimuthFor(int layout, int ch) {
  switch (layout) {
    case 2: // quad
      switch (ch) {
        case 0:
          return -30;
        case 1:
          return 30;
        case 2:
          return -105;
        default:
          return 105;
      }
    case 3:
    case 4: // 5.1 / 7.1
      switch (ch) {
        case 0:
          return -30;
        case 1:
          return 30;
        case 2:
          return 0;
        case 3:
          return 0; // LFE non spatialisé
        case 4:
          return -105;
        case 5:
          return 105;
        case 6:
          return -140;
        default:
          return 140;
      }
    default:
      return ch == 0 ? -30 : 30;
  }
}

class SpatialProcessor {
  SpatialProcessor(this.sampleRate) {
    for (int ch = 0; ch < dsp.maxChannels; ch++) {
      contraShelf.add(Biquad());
      rearMuffle.add(Biquad());
      frontPeak.add(Biquad());
      delayLine.add(List<double>.filled(_maxDelay, 0));
      delayPos.add(0);
      contraDelaySmp.add(0);
      ituMix.add(0);
      binaMix.add(0);
      chIsRear.add(false);
      for (final Biquad b in <Biquad>[contraShelf[ch], rearMuffle[ch], frontPeak[ch]]) {
        b.init();
      }
    }
    for (int e = 0; e < 2; e++) {
      cfLine.add(List<double>.filled(_maxDelay, 0));
      cfPos.add(0);
      cfLp.add(Biquad());
      cfLp[e].init();
    }
  }

  final double sampleRate;
  bool enable = false;
  int mode = spatialModeWidth;
  double width = 1;
  double crossfeed = 0;
  double binauralAmount = 1;

  final List<Biquad> contraShelf = <Biquad>[];
  final List<Biquad> rearMuffle = <Biquad>[];
  final List<Biquad> frontPeak = <Biquad>[];
  final List<List<double>> delayLine = <List<double>>[];
  final List<double> delayPos = <double>[];
  final List<double> contraDelaySmp = <double>[];
  final List<Biquad> cfLp = <Biquad>[];
  final List<List<double>> cfLine = <List<double>>[];
  final List<double> cfPos = <double>[];

  final List<double> ituMix = <double>[];
  final List<double> binaMix = <double>[];
  final List<bool> chIsRear = <bool>[];
  double lfeGainLin = 0;

  int _channels = 0;
  int _layout = -1;
  double _widthCfg = -1;
  bool _dirty = true;

  void set(bool enable, int mode, double widthPercent, double crossfeedPercent,
      double binauralAmountPercent) {
    this.enable = enable;
    int m = mode;
    if (m < spatialModeOff || m > spatialModeBinauralCrossfeed) {
      m = spatialModeWidth;
    }
    if (m != this.mode) {
      this.mode = m;
      _dirty = true;
    }
    _widthCfg = widthPercent;
    width = dsp.clampD(dsp.sanitizeD(widthPercent), 0, 150) / 100;
    crossfeed = dsp.clampD(dsp.sanitizeD(crossfeedPercent), 0, 100) / 100;
    binauralAmount = dsp.clampD(dsp.sanitizeD(binauralAmountPercent), 0, 100) / 100;
  }

  void _configure(int channels, int layout) {
    _channels = channels;
    _layout = layout;
    for (int ch = 0; ch < dsp.maxChannels; ch++) {
      ituMix[ch] = 0;
      binaMix[ch] = 0;
      chIsRear[ch] = false;
      contraDelaySmp[ch] = 0;
    }
    for (int ch = 0; ch < channels; ch++) {
      final double az = _azimuthFor(layout, ch);
      final bool isLfe = layout >= mapper.layout51 && ch == 3;
      if (isLfe) continue;
      final bool isCenter = layout >= mapper.layout51 && ch == 2;
      final bool isRear = az.abs() >= 90;
      chIsRear[ch] = isRear;

      ituMix[ch] = 0.707;

      double ipsi = 1;
      if (isCenter) ipsi = 0.85;
      if (isRear) ipsi = 0.75;
      binaMix[ch] = ipsi;

      if (az.abs() > 1) {
        final double itdS = 0.00065 * _sin(az.abs() * 3.14159265358979323846 / 180);
        contraDelaySmp[ch] = itdS * sampleRate;
      }

      final double ild = isRear ? 10.0 : 7.0;
      contraShelf[ch].set(dsp.bqHighShelf, 2000, -ild, 0.707, sampleRate);

      if (isRear) {
        rearMuffle[ch].set(dsp.bqLowShelf, 5000, -4, 0.707, sampleRate);
      } else {
        rearMuffle[ch].setRaw(1, 0, 0, 0, 0);
      }

      if (!isRear && !isCenter) {
        frontPeak[ch].set(dsp.bqPeaking, 5500, 1.5, 1.2, sampleRate);
      } else if (isCenter) {
        frontPeak[ch].set(dsp.bqPeaking, 5500, 0.8, 1.2, sampleRate);
      } else {
        frontPeak[ch].setRaw(1, 0, 0, 0, 0);
      }
    }
    for (int i = 0; i < 2; i++) {
      cfLp[i].set(dsp.bqLowPass, 700, 0, 0.707, sampleRate);
    }
    _dirty = false;
  }

  void reset() {
    for (int ch = 0; ch < dsp.maxChannels; ch++) {
      contraShelf[ch].resetState();
      rearMuffle[ch].resetState();
      frontPeak[ch].resetState();
      delayLine[ch] = List<double>.filled(_maxDelay, 0);
      delayPos[ch] = 0;
    }
    for (int i = 0; i < 2; i++) {
      cfLp[i].resetState();
      cfLine[i] = List<double>.filled(_maxDelay, 0);
      cfPos[i] = 0;
    }
    _dirty = true;
  }

  static double _sin(double x) => math.sin(x);

  void process(List<Float32List> in_, int channels, int layout,
      List<Float32List> out, double lfeGainLin, int frames) {
    if (!enable || channels < 1 || frames <= 0) {
      for (int i = 0; i < frames; i++) {
        out[0][i] = in_[0][i];
        out[1][i] = channels > 1 ? in_[1][i] : in_[0][i];
      }
      return;
    }
    this.lfeGainLin = dsp.sanitizeD(lfeGainLin).clamp(0, double.infinity);

    final bool stereoIn = channels <= 2;

    if (stereoIn) {
      final double w = mode == spatialModeOff ? 1.0 : width;
      final double ramp = 1 - dsp.onepoleCoef(sampleRate, 0.02);
      final double cfGain = crossfeed * dsp.dbToLin(-8);
      final double cfDelay = 0.00025 * sampleRate;
      final bool doCf = cfGain > 0.0001 && layout != mapper.layoutMono;

      for (int i = 0; i < frames; i++) {
        double l = dsp.sanitizeD(in_[0][i]);
        double r = channels > 1 ? dsp.sanitizeD(in_[1][i]) : l;
        final double m = (l + r) * 0.5;
        final double s = (l - r) * 0.5 * w;
        l = m + s;
        r = m - s;

        if (doCf) {
          cfLine[0][cfPos[0].toInt()] = r;
          cfLine[1][cfPos[1].toInt()] = l;
          double cr = _delayRead(cfLine[0], cfPos[0].toInt(), cfDelay);
          double cl = _delayRead(cfLine[1], cfPos[1].toInt(), cfDelay);
          cr = cfLp[0].tick(cr, ramp);
          cl = cfLp[1].tick(cl, ramp);
          l += cr * cfGain;
          r += cl * cfGain;
          cfPos[0] = _wrap(cfPos[0] + 1);
          cfPos[1] = _wrap(cfPos[1] + 1);
        }

        out[0][i] = l;
        out[1][i] = r;
      }
      return;
    }

    if (_dirty || _channels != channels || _layout != layout) {
      _configure(channels, layout);
    }
    final double ramp = 1 - dsp.onepoleCoef(sampleRate, 0.02);
    final double amt = mode >= spatialModeBinaural ? binauralAmount : 0.0;
    final double itu = 1 - amt;

    for (int i = 0; i < frames; i++) {
      double ituL = 0, ituR = 0;
      double binL = 0, binR = 0;
      double lfeL = 0, lfeR = 0;

      for (int ch = 0; ch < channels; ch++) {
        final double x = dsp.sanitizeD(in_[ch][i]);

        final bool isLfe = _layout >= mapper.layout51 && ch == 3;
        if (isLfe) {
          if (this.lfeGainLin > 0) {
            lfeL += x * this.lfeGainLin;
            lfeR += x * this.lfeGainLin;
          }
          continue;
        }

        final double az = _azimuthFor(_layout, ch);
        final bool right = az > 0;
        final bool center = _layout >= mapper.layout51 && ch == 2;

        final double ituX = x * ituMix[ch];
        if (center) {
          ituL += ituX;
          ituR += ituX;
        } else if (right) {
          ituR += ituX;
          ituL += ituX * 0.15;
        } else {
          ituL += ituX;
          ituR += ituX * 0.15;
        }

        if (amt > 0) {
          final double xs = rearMuffle[ch].tick(x, ramp);
          final double ipsi = frontPeak[ch].tick(xs * binaMix[ch], ramp);
          double contra = xs * (binaMix[ch] * 0.85);
          final int wpos = delayPos[ch].toInt();
          delayLine[ch][wpos] = contra;
          contra = _delayRead(delayLine[ch], wpos, contraDelaySmp[ch]);
          contra = contraShelf[ch].tick(contra, ramp);

          if (center) {
            binL += ipsi;
            binR += ipsi;
          } else if (right) {
            binR += ipsi;
            binL += contra;
          } else {
            binL += ipsi;
            binR += contra;
          }
          delayPos[ch] = _wrap(delayPos[ch] + 1);
        }
      }

      out[0][i] = ituL * itu + binL * amt + lfeL;
      out[1][i] = ituR * itu + binR * amt + lfeR;
    }
  }
}

double _delayRead(List<double> line, int write, double delaySmp) {
  const int len = _maxDelay;
  double read = write - delaySmp;
  if (read < 0) read += len;
  final int i0 = read.toInt();
  final double frac = read - i0;
  int i1 = i0 - 1;
  if (i1 < 0) i1 += len;
  final double a = line[i0];
  final double b = line[i1];
  return a + (b - a) * frac;
}

double _wrap(double pos) {
  const int len = _maxDelay;
  double p = pos;
  while (p >= len) {
    p -= len;
  }
  return p;
}
