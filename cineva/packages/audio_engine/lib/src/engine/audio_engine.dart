/// Orchestrateur du Cineva Audio Engine.
///
/// - indépendant de Flutter (utilisable depuis n'importe quelle couche) ;
/// - sélectionne automatiquement le cœur natif C (FFI) et retombe sur le
///   cœur Dart (équivalent, plus lent) si la bibliothèque est absente ;
/// - A/B instantané : [setBypass] bascule le traitement sans reconstruction.
library;

import '../config/audio_engine_config.dart';
import '../config/param_layout.dart';
import '../dsp/dsp_pipeline.dart';
import '../native/native_dsp.dart';

/// Métriques temps réel du moteur (pour l'UI / la télémétrie).
class AudioEngineMetrics {
  const AudioEngineMetrics({
    this.loudnessLufs = -70,
    this.truePeakDb = -999,
    this.loudnessGainDb = 0,
    this.limiterGainDb = 0,
    this.clippedSamples = 0,
    this.engineActive = false,
  });

  final double loudnessLufs;
  final double truePeakDb;
  final double loudnessGainDb;
  final double limiterGainDb;
  final double clippedSamples;
  final bool engineActive;
}

/// Format audio courant du moteur.
class AudioEngineFormat {
  const AudioEngineFormat({required this.sampleRate, required this.channels});

  final double sampleRate;
  final int channels;
}

class AudioEngine {
  /// [config] : configuration initiale (profil Cinéma par défaut).
  AudioEngine({AudioEngineConfig? config, this.sampleRate = 48000})
      : _config = (config ?? AudioEngineConfig.forProfile(CinevaAudioProfile.cinema)) {
    _dartPipeline = DartDspPipeline(sampleRate: sampleRate);
    _nativeCore = NativeDspCore.create(sampleRate);
    _applyConfig();
  }

  final double sampleRate;
  AudioEngineConfig _config;
  late DartDspPipeline _dartPipeline;
  NativeDspCore? _nativeCore;
  bool _bypass = false;
  int _channels = 2;

  /// Vrai si le cœur natif C est utilisé (sinon cœur Dart équivalent).
  bool get usingNativeCore => _nativeCore != null;

  AudioEngineConfig get config => _config;

  AudioEngineFormat get format =>
      AudioEngineFormat(sampleRate: sampleRate, channels: _channels);

  /// Applique une nouvelle configuration sans reconstruire le moteur :
  /// les paramètres sont lissés par le cœur (anti-zipper).
  void applyConfig(AudioEngineConfig config) {
    _config = config;
    _applyConfig();
  }

  /// Bascule A/B : true = sortie originale (bypass bit-exact côté cœur).
  void setBypass(bool bypass) {
    _bypass = bypass;
    _applyConfig();
  }

  bool get bypass => _bypass;

  /// Traite un bloc planar.
  /// [input] : `channels` Float32List de `frames` échantillons.
  /// [output] : 2 Float32List (stéréo).
  int process(List<Float32List> input, int channels, List<Float32List> output,
      int frames) {
    if (channels != _channels) {
      _channels = channels;
      _applyConfig();
    }
    final NativeDspCore? native = _nativeCore;
    if (native != null) {
      final int rc = native.process(input, channels, output, 2, frames);
      if (rc == 0) return 0;
      // Erreur native : repli silencieux sur le cœur Dart.
      _nativeCore = null;
    }
    return _dartPipeline.process(input, channels, output, 2, frames);
  }

  AudioEngineMetrics readMetrics() {
    final Float64List m =
        _nativeCore?.getMetrics() ?? _dartPipeline.getMetrics();
    return AudioEngineMetrics(
      loudnessLufs: m[DspMetric.loudnessLufs],
      truePeakDb: m[DspMetric.truePeakDb],
      loudnessGainDb: m[DspMetric.loudnessGainDb],
      limiterGainDb: m[DspMetric.limiterGainDb],
      clippedSamples: m[DspMetric.clippedSamples],
      engineActive: m[DspMetric.engineActive] != 0,
    );
  }

  /// Réinitialise les états (changement de piste, seek important).
  void reset() {
    _nativeCore?.reset();
    _dartPipeline.reset();
  }

  void dispose() {
    _nativeCore?.destroy();
    _nativeCore = null;
  }

  void _applyConfig() {
    final Float64List params =
        _config.toParams(sampleRate: sampleRate, channels: _channels);
    // Le bypass A/B (ou la désactivation) pilote masterEnable.
    params[DspParam.masterEnable] = _bypass || !_config.enabled ? 0 : 1;
    _nativeCore?.setParams(params);
    _dartPipeline.setParams(params);
  }
}
