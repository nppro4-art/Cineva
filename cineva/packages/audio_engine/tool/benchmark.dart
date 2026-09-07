/// Benchmark du Cineva Audio Engine (cœur Dart).
///
/// Usage : dart run tool/benchmark.dart
/// (le benchmark du cœur C, plus représentatif de la production,
///  se lance avec `make bench` dans native/cineva_dsp.)
library;

import 'dart:math' as math;

import 'package:cineva_audio_engine/cineva_audio_engine.dart';

class _Rng {
  _Rng(this.state);
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

void runCase(String label, double sampleRate, int channels, int block,
    double seconds, AudioEngineConfig config) {
  final AudioEngine engine = AudioEngine(config: config, sampleRate: sampleRate);
  final int total = (seconds * sampleRate).toInt();
  final int blocks = (total + block - 1) ~/ block;

  final List<Float32List> input = <Float32List>[
    for (int c = 0; c < channels; c++) Float32List(block)
  ];
  final Float32List outL = Float32List(block);
  final Float32List outR = Float32List(block);
  final List<Float32List> output = <Float32List>[outL, outR];
  final _Rng rng = _Rng(424242);
  for (int c = 0; c < channels; c++) {
    for (int i = 0; i < block; i++) {
      input[c][i] = 0.4 * (rng.next() * 2 - 1);
    }
  }

  final Stopwatch sw = Stopwatch()..start();
  for (int b = 0; b < blocks; b++) {
    engine.process(input, channels, output, block);
  }
  final int elapsedUs = sw.elapsedMicroseconds;
  final double audioSeconds = blocks * block / sampleRate;
  final double xRealtime = audioSeconds / (elapsedUs / 1e6);
  // ignore: avoid_print
  print('${label.padRight(30)} ${audioSeconds.toStringAsFixed(2).padLeft(6)} s audio '
      'en ${(elapsedUs / 1000).toStringAsFixed(1).padLeft(8)} ms '
      '→ ${xRealtime.toStringAsFixed(1).padLeft(8)}× temps réel '
      '(cœur ${engine.usingNativeCore ? 'natif C' : 'Dart'})');
  engine.dispose();
}

void main() {
  // ignore: avoid_print
  print('Cineva Audio Engine — benchmark (profil Cinéma complet)\n');
  final AudioEngineConfig cinema =
      AudioEngineConfig.forProfile(CinevaAudioProfile.cinema);
  runCase('stéréo 48 kHz, bloc 512', 48000, 2, 512, 5, cinema);
  runCase('stéréo 48 kHz, bloc 128', 48000, 2, 128, 5, cinema);
  runCase('5.1 48 kHz, bloc 512', 48000, 6, 512, 5, cinema);
  runCase('stéréo 96 kHz, bloc 512', 96000, 2, 512, 5, cinema);
  // ignore: avoid_print
  print('\nUn facteur > 10× temps réel laisse une marge confortable '
      'pour un thread audio temps réel.');
  // ignore: avoid_print
  print('Note math : ${math.sin(0).toString()}');
}
