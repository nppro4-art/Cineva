import 'package:cineva_audio_engine/cineva_audio_engine.dart' as engine;
import 'package:cineva_models/cineva_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// État UI du Cineva Audio Engine.
class AudioEngineUiState extends Equatable {
  const AudioEngineUiState({
    required this.settings,
    required this.backendAvailable,
    required this.attached,
    required this.backendLabel,
    this.backendDetail,
  });

  factory AudioEngineUiState.initial(CinevaAudioSettings settings) {
    return AudioEngineUiState(
      settings: settings,
      backendAvailable: false,
      attached: false,
      backendLabel: '',
    );
  }

  /// Réglages persistés (source de vérité : AppSettingsModel.audioSettings).
  final CinevaAudioSettings settings;

  /// La plateforme peut réellement acheminer l'audio dans le moteur.
  final bool backendAvailable;

  /// Le moteur est branché au média courant.
  final bool attached;

  final String backendLabel;
  final String? backendDetail;

  /// Traitement réellement actif (moteur activé + branché + pas en A/B).
  bool get processingActive =>
      backendAvailable && attached && settings.enabled && !settings.abCompare;

  AudioEngineUiState copyWith({
    CinevaAudioSettings? settings,
    bool? backendAvailable,
    bool? attached,
    String? backendLabel,
    String? backendDetail,
  }) {
    return AudioEngineUiState(
      settings: settings ?? this.settings,
      backendAvailable: backendAvailable ?? this.backendAvailable,
      attached: attached ?? this.attached,
      backendLabel: backendLabel ?? this.backendLabel,
      backendDetail: backendDetail ?? this.backendDetail,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[settings, backendAvailable, attached, backendLabel, backendDetail];
}

/// Traduit les réglages utilisateur persistés en configuration du moteur.
///
/// Le profil fournit la base ; les curseurs utilisateur (dialogue, bass,
/// dynamique, loudness, sortie, avancé) ajustent les valeurs du profil sans
/// jamais réactiver un étage que le profil désactive (ex. « Original »).
engine.AudioEngineConfig buildAudioEngineConfig(CinevaAudioSettings settings) {
  final engine.AudioEngineConfig base = engine.AudioEngineConfig.forProfile(
    engine.CinevaAudioProfileX.fromName(settings.profile.name),
  );
  final CinevaAudioAdvancedSettings? adv = settings.advanced;
  final bool headphone = settings.output == CinevaAudioOutput.headphone;

  final engine.DrcConfig drc = engine.DrcConfig.forMode(
    engine.DynamicRangeModeX.fromName(settings.dynamicRange.name),
  );

  // EQ : gains des 6 bandes (ou ceux du profil si pas de réglages avancés).
  final List<engine.EqBandConfig> bands = <engine.EqBandConfig>[];
  for (int i = 0; i < base.eq.bands.length; i++) {
    final engine.EqBandConfig band = base.eq.bands[i];
    final double? gainOverride =
        (adv != null && i < adv.eqBandGains.length && adv.eqEnabled)
            ? adv.eqBandGains[i]
            : null;
    bands.add(engine.EqBandConfig(
      type: band.type,
      freqHz: band.freqHz,
      gainDb: gainOverride ?? band.gainDb,
      q: band.q,
    ));
  }

  // Casque : crossfeed léger pour éviter l'image trop large.
  final double crossfeed = headphone
      ? (base.spatial.crossfeedPercent > 0 ? base.spatial.crossfeedPercent : 20)
      : base.spatial.crossfeedPercent;

  return base.copyWith(
    enabled: settings.enabled && !settings.abCompare,
    loudness: engine.LoudnessConfig(
      enabled: settings.loudnessEnabled && base.loudness.enabled,
      targetLufs: base.loudness.targetLufs,
      maxGainDb: base.loudness.maxGainDb,
      maxAttenuationDb: base.loudness.maxAttenuationDb,
      adaptRateDbPerSec: base.loudness.adaptRateDbPerSec,
    ),
    eq: engine.EqConfig(bands: bands),
    drc: engine.DrcConfig(
      enabled: base.drc.enabled,
      thresholdDb: drc.thresholdDb,
      ratio: drc.ratio,
      kneeDb: drc.kneeDb,
      attackMs: drc.attackMs,
      releaseMs: drc.releaseMs,
      makeupDb: base.drc.makeupDb,
      mixPercent: drc.mixPercent,
    ),
    dialogue: engine.DialogueConfig(
      enabled: base.dialogue.enabled,
      intensityPercent: settings.dialogueAmount,
    ),
    bass: engine.BassConfig(
      enabled: base.bass.enabled,
      intensityPercent: settings.bassAmount,
      crossoverHz: adv?.crossoverHz ?? base.bass.crossoverHz,
      speakerMode: switch (settings.output) {
        CinevaAudioOutput.headphone => engine.AudioSpeakerMode.headphone,
        CinevaAudioOutput.tv => engine.AudioSpeakerMode.small,
        CinevaAudioOutput.speakers => base.bass.speakerMode,
      },
      subShelfGainDb: adv?.subShelfGainDb ?? base.bass.subShelfGainDb,
      harmonicDrivePercent: base.bass.harmonicDrivePercent,
      lfeGainDb: base.bass.lfeGainDb,
    ),
    spatial: engine.SpatialConfig(
      enabled: settings.spatialEnabled && base.spatial.enabled,
      widthPercent: base.spatial.widthPercent,
      crossfeedPercent: crossfeed,
      binauralAmountPercent: base.spatial.binauralAmountPercent,
    ),
    room: engine.RoomConfig(
      enabled: base.room.enabled,
      wetPercent: adv?.roomWetPercent ?? base.room.wetPercent,
      sizePercent: base.room.sizePercent,
    ),
    limiter: engine.LimiterConfig(
      enabled: base.limiter.enabled,
      ceilingDb: adv?.limiterCeilingDb ?? base.limiter.ceilingDb,
      lookaheadMs: base.limiter.lookaheadMs,
      releaseMs: base.limiter.releaseMs,
    ),
  );
}

/// Contrôleur du moteur audio : synchronise réglages persistés ↔ backend
/// (AudioWorklet sur web) et expose l'état réel de traitement.
class AudioEngineController extends StateNotifier<AudioEngineUiState> {
  AudioEngineController({
    required engine.CinevaAudioBackend backend,
    required Future<void> Function(CinevaAudioSettings settings) persist,
  })  : _backend = backend,
        _persist = persist,
        super(AudioEngineUiState.initial(CinevaAudioSettings.defaults())) {
    state = state.copyWith(
      backendAvailable: _backend.capabilities.available,
      backendLabel: _backend.capabilities.label,
      backendDetail: _backend.capabilities.detail,
    );
  }

  final engine.CinevaAudioBackend _backend;
  final Future<void> Function(CinevaAudioSettings settings) _persist;

  /// Fréquence d'échantillonnage réelle du contexte audio (après attach).
  double _sampleRate = 48000;

  bool _pushingParams = false;

  /// Synchronise l'état depuis les réglages persistés (chargement initial,
  /// changements externes) et pousse la configuration au backend.
  void syncFromSettings(CinevaAudioSettings? settings) {
    if (settings == null) return;
    if (settings == state.settings && state.backendLabel.isNotEmpty) return;
    state = state.copyWith(settings: settings);
    _pushParams();
  }

  /// Attache le moteur au média actif (appelé par le player). Idempotent.
  Future<bool> ensureAttached() async {
    if (!_backend.capabilities.available || state.attached) {
      return state.attached;
    }
    final bool attached = await _backend.attach();
    state = state.copyWith(
      attached: attached,
      backendDetail: _backend.capabilities.detail,
    );
    if (attached) {
      _refreshSampleRate();
      _pushParams();
    }
    return attached;
  }

  /// Détache le moteur (fin de lecture).
  Future<void> detach() async {
    await _backend.detach();
    state = state.copyWith(attached: false);
  }

  Future<void> updateEnabled(bool enabled) => _update(
        state.settings.copyWith(enabled: enabled),
      );

  Future<void> updateProfile(CinevaAudioProfile profile) => _update(
        state.settings.copyWith(profile: profile),
      );

  Future<void> updateSpatial(bool enabled) => _update(
        state.settings.copyWith(spatialEnabled: enabled),
      );

  Future<void> updateDialogueAmount(double amount) => _update(
        state.settings.copyWith(dialogueAmount: amount),
      );

  Future<void> updateBassAmount(double amount) => _update(
        state.settings.copyWith(bassAmount: amount),
      );

  Future<void> updateDynamicRange(CinevaAudioDynamicRange range) => _update(
        state.settings.copyWith(dynamicRange: range),
      );

  Future<void> updateLoudness(bool enabled) => _update(
        state.settings.copyWith(loudnessEnabled: enabled),
      );

  Future<void> updateOutput(CinevaAudioOutput output) => _update(
        state.settings.copyWith(output: output),
      );

  /// Bascule A/B : bypass instantané pour comparer avec le son d'origine.
  Future<void> toggleAbCompare() => _update(
        state.settings.copyWith(abCompare: !state.settings.abCompare),
      );

  Future<void> updateAdvanced(CinevaAudioAdvancedSettings? advanced) => _update(
        advanced == null
            ? state.settings.copyWith(clearAdvanced: true)
            : state.settings.copyWith(advanced: advanced),
      );

  /// Abandonne les réglages avancés : retour aux valeurs du profil.
  Future<void> updateAdvancedReset() => _update(
        state.settings.copyWith(clearAdvanced: true),
      );

  Future<void> _update(CinevaAudioSettings settings) async {
    state = state.copyWith(settings: settings);
    _pushParams();
    try {
      await _persist(settings);
    } catch (_) {
      // La persistance peut échouer (hors ligne) : le moteur reste à jour.
    }
  }

  void _pushParams() {
    if (_pushingParams) return;
    _pushingParams = true;
    try {
      final engine.AudioEngineConfig config = buildAudioEngineConfig(state.settings);
      _backend.setParams(config.toParams(sampleRate: _sampleRate).toList());
    } finally {
      _pushingParams = false;
    }
  }

  void _refreshSampleRate() {
    if (_backend is engine.WebAudioBackend) {
      final Map<String, Object?> status =
          (_backend as engine.WebAudioBackend).getStatus();
      final Object? sr = status['sampleRate'];
      if (sr is num && sr > 0) {
        _sampleRate = sr.toDouble();
      }
    }
  }

  /// Métriques brutes du worklet (16 doubles) si le backend web est actif.
  List<double> readMetrics() {
    if (_backend is engine.WebAudioBackend) {
      (_backend as engine.WebAudioBackend).requestMetrics();
      return (_backend as engine.WebAudioBackend).getMetrics();
    }
    return const <double>[];
  }
}
