/// Room / Cinema Effect — miroir de `room.c`.
library;

import 'biquad.dart' as dsp;
import 'biquad.dart' show Biquad;
import 'dart:typed_data';

const int roomTaps = 8;
const int _roomMaxDelay = 8192;

class RoomProcessor {
  RoomProcessor(this.sampleRate) {
    const tapMs = <double>[4.8, 9.1, 13.7, 18.3, 23.6, 29.2, 33.8, 38.4];
    const tapDb = <double>[-16, -19, -21, -23, -25, -26.5, -28, -29.5];
    for (int t = 0; t < roomTaps; t++) {
      delaySmp.add(tapMs[t] * 0.001 * sampleRate);
      gain.add(dsp.dbToLin(tapDb[t]));
      lp.add(Biquad());
      lp[t].init();
      final double lpHz = 3200 - t * 250;
      lp[t].set(dsp.bqLowPass, lpHz, 0, 0.707, sampleRate);
      lp[t].snap();
    }
    line.add(List<double>.filled(_roomMaxDelay, 0));
    line.add(List<double>.filled(_roomMaxDelay, 0));
  }

  final double sampleRate;
  bool enable = false;
  double wet = 0.06;
  double size = 1.0;

  final List<double> delaySmp = <double>[];
  final List<double> gain = <double>[];
  final List<Biquad> lp = <Biquad>[];
  final List<List<double>> line = <List<double>>[];
  double pos = 0;

  void set(bool enable, double wetPercent, double sizePercent) {
    this.enable = enable;
    wet = dsp.clampD(dsp.sanitizeD(wetPercent), 0, 15) / 100;
    size = dsp.clampD(dsp.sanitizeD(sizePercent), 50, 150) / 100;
  }

  void reset() {
    for (int t = 0; t < roomTaps; t++) {
      lp[t].resetState();
    }
    line[0] = List<double>.filled(_roomMaxDelay, 0);
    line[1] = List<double>.filled(_roomMaxDelay, 0);
    pos = 0;
  }

  void process(List<Float32List> io, int frames) {
    if (!enable || wet <= 0) return;
    final double ramp = 1 - dsp.onepoleCoef(sampleRate, 0.02);
    const int len = _roomMaxDelay;
    final double wetGain = wet * 4;
    final double dryGain = 1 - wet * 1.5;

    for (int i = 0; i < frames; i++) {
      final double l = dsp.sanitizeD(io[0][i]);
      final double r = dsp.sanitizeD(io[1][i]);

      final int wpos = pos.toInt();
      line[0][wpos] = l;
      line[1][wpos] = r;

      double wetL = 0, wetR = 0;
      for (int t = 0; t < roomTaps; t++) {
        double d = delaySmp[t] * size;
        if (d >= len) d = len - 1.0;
        double read = wpos - d;
        if (read < 0) read += len;
        final int i0 = read.toInt();
        final double frac = read - i0;
        int i1 = i0 - 1;
        if (i1 < 0) i1 += len;
        final double srcL = line[0][i0] + (line[0][i1] - line[0][i0]) * frac;
        final double srcR = line[1][i0] + (line[1][i1] - line[1][i0]) * frac;
        final double srcAvg = (srcL + srcR) * 0.5;

        final double tap = lp[t].tick(srcAvg, ramp);
        if ((t & 1) == 0) {
          wetL += tap * gain[t] * 0.75;
          wetR += tap * gain[t];
        } else {
          wetL += tap * gain[t];
          wetR += tap * gain[t] * 0.75;
        }
      }

      io[0][i] = l * dryGain + wetL * wetGain;
      io[1][i] = r * dryGain + wetR * wetGain;

      pos += 1;
      if (pos >= len) pos = 0;
    }
  }
}
