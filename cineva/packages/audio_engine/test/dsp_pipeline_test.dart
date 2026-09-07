import 'dart:io';
import 'dart:math' as math;

import 'package:cineva_audio_engine/cineva_audio_engine.dart';
import 'package:test/test.dart';

/// Générateur pseudo-aléatoire déterministe (xorshift64) — identique au C.
class Rng {
  Rng(this.state);

  int state;

  double next() {
    int x = state;
    x ^= x << 13;
    x &= 0xFFFFFFFFFFFFFFFF;
    x ^= x >>> 7;
    x ^= x << 17;
    x &= 0xFFFFFFFFFFFFFFFF;
    state = x;
    return (x >> 11) / 9007199254740992.0;
  }
}

double sine(double freq, double sampleRate, int i) =>
    math.sin(2 * math.pi * freq * i / sampleRate);

bool allFinite(Float32List buf) {
  for (final double v in buf) {
    if (!v.isFinite) return false;
  }
  return true;
}

double peakAbs(Float32List buf) {
  double p = 0;
  for (final double v in buf) {
    final double a = v.abs();
    if (a > p) p = a;
  }
  return p;
}

double rms(Float32List buf, [int? n]) {
  final int count = n ?? buf.length;
  double s = 0;
  for (int i = 0; i < count; i++) {
    s += buf[i] * buf[i];
  }
  return count > 0 ? math.sqrt(s / count) : 0;
}

void main() {
  const double sr = 48000;
  const int n = 4800;

  group('DartDspPipeline — comportement', () {
    test('silence → silence, aucune métrique d\'erreur', () {
      final DartDspPipeline p = DartDspPipeline(sampleRate: sr);
      final Float32List inL = Float32List(n);
      final Float32List inR = Float32List(n);
      final Float32List outL = Float32List(n);
      final Float32List outR = Float32List(n);
      for (int rep = 0; rep < 10; rep++) {
        expect(
            p.process(<Float32List>[inL, inR], 2, <Float32List>[outL, outR], 2, n),
            0);
        expect(allFinite(outL) && allFinite(outR), isTrue);
      }
      final Float64List m = p.getMetrics();
      expect(m[DspMetric.clippedSamples], 0);
    });

    test('bypass A/B bit-exact', () {
      final DartDspPipeline p = DartDspPipeline(sampleRate: sr);
      final Float64List params = neutralParams();
      params[DspParam.masterEnable] = 0;
      expect(p.setParams(params), 0);
      final Rng rng = Rng(123);
      final Float32List inL = Float32List(n);
      final Float32List inR = Float32List(n);
      for (int i = 0; i < n; i++) {
        inL[i] = 0.4 * sine(300, sr, i) + 0.05 * rng.next();
        inR[i] = 0.4 * sine(310, sr, i) - 0.05 * rng.next();
      }
      final Float32List outL = Float32List(n);
      final Float32List outR = Float32List(n);
      p.process(<Float32List>[inL, inR], 2, <Float32List>[outL, outR], 2, n);
      for (int i = 0; i < n; i++) {
        expect(outL[i], inL[i]);
        expect(outR[i], inR[i]);
      }
    });

    test('version de paramètres incorrecte rejetée', () {
      final DartDspPipeline p = DartDspPipeline(sampleRate: sr);
      final Float64List bad = neutralParams();
      bad[DspParam.layoutVersion] = 99;
      expect(p.setParams(bad), -2);
      expect(p.setParams(Float64List(10)), -1);
    });

    test('entrée NaN/Inf → sortie finie', () {
      final DartDspPipeline p = DartDspPipeline(sampleRate: sr);
      final Float32List inL = Float32List(n);
      final Float32List inR = Float32List(n);
      for (int i = 0; i < n; i++) {
        inL[i] = 0.3 * sine(440, sr, i);
        inR[i] = inL[i];
      }
      inL[100] = double.nan;
      inL[101] = double.infinity;
      inR[200] = double.nan;
      final Float32List outL = Float32List(n);
      final Float32List outR = Float32List(n);
      p.process(<Float32List>[inL, inR], 2, <Float32List>[outL, outR], 2, n);
      expect(allFinite(outL) && allFinite(outR), isTrue);
    });

    test('niveau élevé : sortie bornée par le limiteur', () {
      final DartDspPipeline p = DartDspPipeline(sampleRate: sr);
      final Float32List inL = Float32List(n);
      final Float32List inR = Float32List(n);
      for (int i = 0; i < n; i++) {
        inL[i] = 1.26 * sine(300, sr, i);
        inR[i] = 1.26 * sine(300, sr, i);
      }
      final Float32List outL = Float32List(n);
      final Float32List outR = Float32List(n);
      for (int rep = 0; rep < 5; rep++) {
        p.process(<Float32List>[inL, inR], 2, <Float32List>[outL, outR], 2, n);
        expect(peakAbs(outL), lessThan(1.0));
        expect(peakAbs(outR), lessThan(1.0));
        expect(allFinite(outL), isTrue);
      }
    });

    test('changement de paramètres pendant la lecture : stable', () {
      final DartDspPipeline p = DartDspPipeline(sampleRate: sr);
      final Float64List params = neutralParams();
      final Float32List inL = Float32List(n);
      final Float32List inR = Float32List(n);
      final Float32List outL = Float32List(n);
      final Float32List outR = Float32List(n);
      for (int rep = 0; rep < 12; rep++) {
        for (int i = 0; i < n; i++) {
          inL[i] = 0.4 * sine(220.0 + rep * 37, sr, i);
          inR[i] = 0.4 * sine(221.0 + rep * 37, sr, i);
        }
        params[DspParam.eqGainDb(rep % 6)] = rep.isEven ? 8.0 : -8.0;
        params[DspParam.dialogueIntensityPercent] = 10.0 + rep * 8;
        params[DspParam.spatialWidthPercent] = 60.0 + rep * 9;
        if (rep == 6) params[DspParam.masterEnable] = 0;
        if (rep == 8) params[DspParam.masterEnable] = 1;
        expect(p.setParams(params), 0);
        expect(
            p.process(<Float32List>[inL, inR], 2, <Float32List>[outL, outR], 2, n),
            0);
        expect(allFinite(outL) && allFinite(outR), isTrue);
        expect(peakAbs(outL), lessThan(1.0));
      }
    });

    test('5.1 : binaural + bass management, sortie finie et bornée', () {
      final DartDspPipeline p = DartDspPipeline(sampleRate: sr);
      final Float64List params = neutralParams(channels: 6);
      params[DspParam.spatialMode] = 3; // binaural + crossfeed
      params[DspParam.spatialCrossfeedPercent] = 40;
      expect(p.setParams(params), 0);
      final Rng rng = Rng(777);
      final List<Float32List> in51 = <Float32List>[
        for (int c = 0; c < 6; c++) Float32List(n),
      ];
      for (int c = 0; c < 6; c++) {
        for (int i = 0; i < n; i++) {
          in51[c][i] = 0.25 * (rng.next() * 2 - 1);
        }
      }
      final Float32List outL = Float32List(n);
      final Float32List outR = Float32List(n);
      for (int rep = 0; rep < 4; rep++) {
        expect(p.process(in51, 6, <Float32List>[outL, outR], 2, n), 0);
        expect(allFinite(outL) && allFinite(outR), isTrue);
        expect(peakAbs(outL), lessThan(1.0));
        expect(peakAbs(outR), lessThan(1.0));
      }
    });

    test('mono → stéréo dupliquée en bypass', () {
      final DartDspPipeline p = DartDspPipeline(sampleRate: sr);
      final Float64List params = neutralParams(channels: 1);
      params[DspParam.masterEnable] = 0;
      p.setParams(params);
      final Float32List inM = Float32List(n);
      for (int i = 0; i < n; i++) {
        inM[i] = 0.3 * sine(500, sr, i);
      }
      final Float32List outL = Float32List(n);
      final Float32List outR = Float32List(n);
      p.process(<Float32List>[inM], 1, <Float32List>[outL, outR], 2, n);
      for (int i = 0; i < n; i++) {
        expect(outL[i], inM[i]);
        expect(outR[i], inM[i]);
      }
    });

    test('loudness : mesure correcte d\'un sine 1 kHz à -20 dBFS', () {
      final DartDspPipeline p = DartDspPipeline(sampleRate: sr);
      final Float64List params = neutralParams();
      // Loudness seul.
      params[DspParam.eqEnable] = 0;
      params[DspParam.drcEnable] = 0;
      params[DspParam.dialogueEnable] = 0;
      params[DspParam.bassEnable] = 0;
      params[DspParam.spatialEnable] = 0;
      params[DspParam.roomEnable] = 0;
      params[DspParam.limiterEnable] = 0;
      params[DspParam.loudnessAdaptRateDbPerSec] = 6;
      expect(p.setParams(params), 0);
      final Float32List inL = Float32List(n);
      for (int i = 0; i < n; i++) {
        inL[i] = 0.1 * sine(1000, sr, i);
      }
      final Float32List outL = Float32List(n);
      final Float32List outR = Float32List(n);
      for (int rep = 0; rep < 12; rep++) {
        p.process(<Float32List>[inL, inL], 2, <Float32List>[outL, outR], 2, n);
      }
      final Float64List m = p.getMetrics();
      // BS.1770 : sine stéréo 1 kHz à -20 dBFS ≈ -20.69 LUFS.
      expect(m[DspMetric.loudnessLufs], closeTo(-20.69, 0.7));
      expect(m[DspMetric.loudnessGainDb], greaterThan(2.0));
      expect(m[DspMetric.loudnessGainDb], lessThanOrEqualTo(8.0));
    });
  });

  group('Golden tests — équivalence avec le cœur C', () {
    final Directory goldenDir =
        Directory('test/goldens');
    final bool goldensAvailable = goldenDir.existsSync();

    test('goldens présents', () {
      // Les goldens sont générés par `make goldens` côté C.
      expect(goldensAvailable, isTrue,
          reason:
              'lancez: cd native/cineva_dsp && make goldens DIR=../../test/goldens');
    }, skip: goldensAvailable ? false : 'goldens absents');

    void checkGolden(String tag, int inputChannels) {
      test('golden $tag correspond à la sortie du cœur C', () {
        final File paramsFile =
            File('${goldenDir.path}/${tag}_params.f64');
        final File outputFile =
            File('${goldenDir.path}/${tag}_output.f32');
        final File inputFile = File(
            '${goldenDir.path}/${inputChannels == 6 ? 'input_51_multitone.f32' : 'input_stereo_noise.f32'}');
        expect(paramsFile.existsSync(), isTrue, reason: paramsFile.path);
        expect(outputFile.existsSync(), isTrue, reason: outputFile.path);
        expect(inputFile.existsSync(), isTrue, reason: inputFile.path);

        final Float64List params =
            Float64List.view(paramsFile.readAsBytesSync().buffer);
        final Float32List inputInterleaved =
            Float32List.view(inputFile.readAsBytesSync().buffer);
        final Float32List expected =
            Float32List.view(outputFile.readAsBytesSync().buffer);

        final int frames = inputInterleaved.length ~/ inputChannels;
        final List<Float32List> in_ = <Float32List>[
          for (int c = 0; c < inputChannels; c++) Float32List(frames),
        ];
        for (int i = 0; i < frames; i++) {
          for (int c = 0; c < inputChannels; c++) {
            in_[c][i] = inputInterleaved[i * inputChannels + c];
          }
        }

        final DartDspPipeline p = DartDspPipeline(sampleRate: params[DspParam.sampleRate]);
        expect(p.setParams(params), 0);
        final Float32List outL = Float32List(frames);
        final Float32List outR = Float32List(frames);
        expect(p.process(in_, inputChannels, <Float32List>[outL, outR], 2, frames), 0);

        double maxDiff = 0;
        double sumSqExpected = 0;
        double sumSqDiff = 0;
        for (int i = 0; i < frames; i++) {
          final double dl = (outL[i] - expected[2 * i]).abs();
          final double dr = (outR[i] - expected[2 * i + 1]).abs();
          if (dl > maxDiff) maxDiff = dl;
          if (dr > maxDiff) maxDiff = dr;
          sumSqExpected += expected[2 * i] * expected[2 * i] + expected[2 * i + 1] * expected[2 * i + 1];
          sumSqDiff += dl * dl + dr * dr;
        }
        // Tolérance : écart absolu max < 2e-4 (arrondis float/libm) et
        // énergie d'erreur négligeable (< -60 dB par rapport au signal).
        expect(maxDiff, lessThan(2e-4),
            reason: 'écart max Dart↔C trop grand ($maxDiff)');
        final double errorRatio =
            sumSqExpected > 0 ? math.sqrt(sumSqDiff / sumSqExpected) : 0;
        expect(errorRatio, lessThan(1e-3),
            reason: 'énergie d\'erreur Dart↔C trop grande');
      }, skip: goldensAvailable ? false : 'goldens absents');
    }

    checkGolden('cinema_stereo_noise', 2);
    checkGolden('night_stereo_noise', 2);
    checkGolden('immersive_51_multitone', 6);
    checkGolden('bypass_stereo_noise', 2);
    checkGolden('original_stereo_noise', 2);
  });
}
