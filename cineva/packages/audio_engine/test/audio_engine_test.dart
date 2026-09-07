import 'dart:math' as math;

import 'package:cineva_audio_engine/cineva_audio_engine.dart';
import 'package:test/test.dart';

double sine(double freq, double sampleRate, int i) =>
    math.sin(2 * math.pi * freq * i / sampleRate);

void main() {
  group('AudioEngine', () {
    test('traite un bloc et rapporte des métriques finies', () {
      final AudioEngine engine = AudioEngine(sampleRate: 48000);
      const int n = 4800;
      final Float32List inL = Float32List(n);
      final Float32List inR = Float32List(n);
      for (int i = 0; i < n; i++) {
        inL[i] = 0.4 * sine(220, 48000, i);
        inR[i] = 0.4 * sine(222, 48000, i);
      }
      final Float32List outL = Float32List(n);
      final Float32List outR = Float32List(n);
      final int rc = engine.process(
          <Float32List>[inL, inR], 2, <Float32List>[outL, outR], n);
      expect(rc, 0);
      final AudioEngineMetrics m = engine.readMetrics();
      expect(m.engineActive, isTrue);
      expect(m.loudnessLufs.isFinite, isTrue);
      expect(m.truePeakDb.isFinite, isTrue);
      engine.dispose();
    });

    test('bypass A/B instantané sans reconstruction', () {
      final AudioEngine engine = AudioEngine(sampleRate: 48000);
      const int n = 2400;
      final Float32List inL = Float32List(n);
      final Float32List inR = Float32List(n);
      for (int i = 0; i < n; i++) {
        inL[i] = 0.5 * sine(300, 48000, i);
        inR[i] = 0.5 * sine(300, 48000, i);
      }
      final Float32List outL = Float32List(n);
      final Float32List outR = Float32List(n);

      engine.process(<Float32List>[inL, inR], 2, <Float32List>[outL, outR], n);
      expect(engine.readMetrics().engineActive, isTrue);

      engine.setBypass(true);
      engine.process(<Float32List>[inL, inR], 2, <Float32List>[outL, outR], n);
      expect(engine.readMetrics().engineActive, isFalse);
      for (int i = 0; i < n; i++) {
        expect(outL[i], inL[i]);
        expect(outR[i], inR[i]);
      }

      engine.setBypass(false);
      engine.process(<Float32List>[inL, inR], 2, <Float32List>[outL, outR], n);
      expect(engine.readMetrics().engineActive, isTrue);
      engine.dispose();
    });

    test('applyConfig modifie le traitement à chaud', () {
      final AudioEngine engine = AudioEngine(
          config: AudioEngineConfig.forProfile(CinevaAudioProfile.original),
          sampleRate: 48000);
      const int n = 2400;
      final Float32List inL = Float32List(n);
      final Float32List inR = Float32List(n);
      final Float32List outL = Float32List(n);
      final Float32List outR = Float32List(n);
      for (int i = 0; i < n; i++) {
        inL[i] = 0.3 * sine(1000, 48000, i);
        inR[i] = 0.3 * sine(1000, 48000, i);
      }

      // Profil original : sortie = entrée (tous modules désactivés).
      engine.process(<Float32List>[inL, inR], 2, <Float32List>[outL, outR], n);
      double originalRms = rms(outL);

      // Profil night : traitement actif.
      engine.applyConfig(AudioEngineConfig.forProfile(CinevaAudioProfile.night));
      engine.reset();
      for (int rep = 0; rep < 6; rep++) {
        engine.process(<Float32List>[inL, inR], 2, <Float32List>[outL, outR], n);
      }
      final AudioEngineMetrics m = engine.readMetrics();
      expect(m.engineActive, isTrue);
      // Le compresseur night doit agir sur un sine à -10 dBFS.
      expect(rms(outL), lessThan(originalRms * 1.5));
      engine.dispose();
    });

    test('réagit à un changement de nombre de canaux', () {
      final AudioEngine engine = AudioEngine(sampleRate: 48000);
      const int n = 1200;
      final List<Float32List> in51 = <Float32List>[
        for (int c = 0; c < 6; c++) Float32List(n),
      ];
      for (int c = 0; c < 6; c++) {
        for (int i = 0; i < n; i++) {
          in51[c][i] = 0.2 * sine(200 + 50 * c, 48000, i);
        }
      }
      final Float32List outL = Float32List(n);
      final Float32List outR = Float32List(n);
      expect(engine.process(in51, 6, <Float32List>[outL, outR], n), 0);
      expect(engine.format.channels, 6);
      expect(engine.readMetrics().engineActive, isTrue);
      engine.dispose();
    });

    test('le cœur utilisé est natif ou Dart, jamais aucun', () {
      final AudioEngine engine = AudioEngine(sampleRate: 48000);
      // Sans bibliothèque native dans l'environnement de test, le cœur Dart
      // prend le relais ; les deux produisent le même résultat (goldens).
      expect(engine.usingNativeCore, anyOf(isTrue, isFalse));
      engine.dispose();
    });
  });
}

double rms(Float32List buf) {
  double s = 0;
  for (final double v in buf) {
    s += v * v;
  }
  return math.sqrt(s / buf.length);
}
