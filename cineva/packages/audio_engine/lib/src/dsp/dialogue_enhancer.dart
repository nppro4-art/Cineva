/// Dialogue Enhancer — miroir de `dialogue.c`.
library;

import 'biquad.dart' as dsp;
import 'biquad.dart' show Biquad;
import 'channel_mapper.dart' show layout51;

class DialogueEnhancer {
  DialogueEnhancer(this.sampleRate) {
    final double sr = sampleRate;
    for (int i = 0; i < 2; i++) {
      hpMid.add(Biquad());
      lpMid.add(Biquad());
      hpSide.add(Biquad());
      lpSide.add(Biquad());
      hpMud.add(Biquad());
      lpMud.add(Biquad());
      hpMudLr.add(Biquad());
      lpMudLr.add(Biquad());
      for (final Biquad b in <Biquad>[
        hpMid[i], lpMid[i], hpSide[i], lpSide[i], hpMud[i], lpMud[i], hpMudLr[i], lpMudLr[i],
      ]) {
        b.init();
      }
      hpMid[i].set(dsp.bqHighPass, 1200, 0, 0.707, sr);
      lpMid[i].set(dsp.bqLowPass, 4500, 0, 0.707, sr);
      hpSide[i].set(dsp.bqHighPass, 1200, 0, 0.707, sr);
      lpSide[i].set(dsp.bqLowPass, 4500, 0, 0.707, sr);
      hpMud[i].set(dsp.bqHighPass, 200, 0, 0.707, sr);
      lpMud[i].set(dsp.bqLowPass, 350, 0, 0.707, sr);
      hpMudLr[i].set(dsp.bqHighPass, 200, 0, 0.707, sr);
      lpMudLr[i].set(dsp.bqLowPass, 350, 0, 0.707, sr);
      for (final Biquad b in <Biquad>[
        hpMid[i], lpMid[i], hpSide[i], lpSide[i], hpMud[i], lpMud[i], hpMudLr[i], lpMudLr[i],
      ]) {
        b.snap();
      }
    }
    hpC.init();
    lpC.init();
    hpC.set(dsp.bqHighPass, 1200, 0, 0.707, sr);
    lpC.set(dsp.bqLowPass, 4500, 0, 0.707, sr);
    hpC.snap();
    lpC.snap();
  }

  final double sampleRate;
  bool enable = false;
  double intensity = 0.35;

  final List<Biquad> hpMid = <Biquad>[];
  final List<Biquad> lpMid = <Biquad>[];
  final List<Biquad> hpSide = <Biquad>[];
  final List<Biquad> lpSide = <Biquad>[];
  final List<Biquad> hpMud = <Biquad>[];
  final List<Biquad> lpMud = <Biquad>[];
  final List<Biquad> hpMudLr = <Biquad>[];
  final List<Biquad> lpMudLr = <Biquad>[];
  final Biquad hpC = Biquad();
  final Biquad lpC = Biquad();

  void set(bool enable, double intensityPercent) {
    this.enable = enable;
    intensity = dsp.clampD(dsp.sanitizeD(intensityPercent), 0, 100) / 100;
  }

  void reset() {
    hpC.resetState();
    lpC.resetState();
    for (int i = 0; i < 2; i++) {
      hpMid[i].resetState();
      lpMid[i].resetState();
      hpSide[i].resetState();
      lpSide[i].resetState();
      hpMud[i].resetState();
      lpMud[i].resetState();
      hpMudLr[i].resetState();
      lpMudLr[i].resetState();
    }
  }

  void process(List<Float32List> io, int channels, int layout, int frames) {
    if (!enable || intensity <= 0) return;
    if (channels < 1 || frames <= 0) return;
    final double ramp = 1 - dsp.onepoleCoef(sampleRate, 0.02);
    final double amt = intensity;

    final double presenceAdd = (dsp.dbToLin(4) - 1) * amt;
    final double mudSub = (1 - dsp.dbToLin(-2)) * amt;
    final double sideSub = (1 - dsp.dbToLin(-1.5)) * amt;

    final bool multichannel = layout >= layout51 && channels >= 6;
    const int centerIndex = 2;

    for (int i = 0; i < frames; i++) {
      if (multichannel) {
        final double c = dsp.sanitizeD(io[centerIndex][i]);
        double cp = hpC.tick(c, ramp);
        cp = lpC.tick(cp, ramp);
        io[centerIndex][i] = c + cp * presenceAdd;
        for (int ch = 0; ch < 2; ch++) {
          final double x = dsp.sanitizeD(io[ch][i]);
          double mud = hpMudLr[ch].tick(x, ramp);
          mud = lpMudLr[ch].tick(mud, ramp);
          io[ch][i] = x - mud * mudSub;
        }
      }

      if (channels >= 2) {
        final double l = dsp.sanitizeD(io[0][i]);
        final double r = dsp.sanitizeD(io[1][i]);
        double m = (l + r) * 0.5;
        double s = (l - r) * 0.5;

        double mp = hpMid[0].tick(m, ramp);
        mp = lpMid[0].tick(mp, ramp);
        m += mp * presenceAdd;

        double mmud = hpMud[0].tick(m, ramp);
        mmud = lpMud[0].tick(mmud, ramp);
        m -= mmud * mudSub;

        double sp = hpSide[0].tick(s, ramp);
        sp = lpSide[0].tick(sp, ramp);
        s -= sp * sideSub;

        io[0][i] = m + s;
        io[1][i] = m - s;
      }
    }
  }
}
