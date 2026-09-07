/// Configuration centralisée du Cineva Audio Engine.
///
/// Source de vérité unique entre l'UI, la persistance et le cœur DSP.
/// Toutes les valeurs sont validées/clampées : aucune valeur NaN, Inf ou
/// hors plage ne peut atteindre le DSP.
library;

import 'package:equatable/equatable.dart';

import 'param_layout.dart';

/// Profils du Cineva Audio Engine.
enum CinevaAudioProfile { cinema, immersive, tv, night, original }

extension CinevaAudioProfileX on CinevaAudioProfile {
  String get label => switch (this) {
        CinevaAudioProfile.cinema => 'Cinéma',
        CinevaAudioProfile.immersive => 'Immersif',
        CinevaAudioProfile.tv => 'TV',
        CinevaAudioProfile.night => 'Night',
        CinevaAudioProfile.original => 'Original',
      };

  String get description => switch (this) {
        CinevaAudioProfile.cinema => 'Dynamique, basses profondes, dialogues clairs, scène large.',
        CinevaAudioProfile.immersive => 'Spatialisation renforcée pour le casque, profondeur et largeur.',
        CinevaAudioProfile.tv => 'Optimisé pour les haut-parleurs de TV : dialogues en avant, basses maîtrisées.',
        CinevaAudioProfile.night => 'Dynamique compressée : explosions adoucies, dialogues toujours clairs.',
        CinevaAudioProfile.original => 'Aucun traitement — comparaison avec le son d’origine.',
      };

  String get name => switch (this) {
        CinevaAudioProfile.cinema => 'cinema',
        CinevaAudioProfile.immersive => 'immersive',
        CinevaAudioProfile.tv => 'tv',
        CinevaAudioProfile.night => 'night',
        CinevaAudioProfile.original => 'original',
      };

  static CinevaAudioProfile fromName(String? name) => switch (name) {
        'immersive' => CinevaAudioProfile.immersive,
        'tv' => CinevaAudioProfile.tv,
        'night' => CinevaAudioProfile.night,
        'original' => CinevaAudioProfile.original,
        _ => CinevaAudioProfile.cinema,
      };
}

/// Mode de dynamique (compréhensible côté UI).
enum DynamicRangeMode { cinema, standard, night }

extension DynamicRangeModeX on DynamicRangeMode {
  String get label => switch (this) {
        DynamicRangeMode.cinema => 'Cinéma',
        DynamicRangeMode.standard => 'Standard',
        DynamicRangeMode.night => 'Night',
      };

  String get name => switch (this) {
        DynamicRangeMode.cinema => 'cinema',
        DynamicRangeMode.standard => 'standard',
        DynamicRangeMode.night => 'night',
    };

  static DynamicRangeMode fromName(String? name) => switch (name) {
        'standard' => DynamicRangeMode.standard,
        'night' => DynamicRangeMode.night,
        _ => DynamicRangeMode.cinema,
      };
}

/// Type de sortie (adapte le traitement bass/spatial).
enum AudioSpeakerMode { full, small, headphone }

extension AudioSpeakerModeX on AudioSpeakerMode {
  String get label => switch (this) {
        AudioSpeakerMode.full => 'Système complet',
        AudioSpeakerMode.small => 'Petits haut-parleurs',
        AudioSpeakerMode.headphone => 'Casque',
      };

  int get dspValue => switch (this) {
        AudioSpeakerMode.full => 0,
        AudioSpeakerMode.small => 1,
        AudioSpeakerMode.headphone => 2,
      };

  String get name => switch (this) {
        AudioSpeakerMode.full => 'full',
        AudioSpeakerMode.small => 'small',
        AudioSpeakerMode.headphone => 'headphone',
      };

  static AudioSpeakerMode fromName(String? name) => switch (name) {
        'small' => AudioSpeakerMode.small,
        'headphone' => AudioSpeakerMode.headphone,
        _ => AudioSpeakerMode.full,
      };
}

double _clampNum(dynamic v, double def, double lo, double hi) {
  final double d = v is num ? v.toDouble() : def;
  if (d.isNaN || d < -1e30 || d > 1e30) return def;
  if (d < lo) return lo;
  if (d > hi) return hi;
  return d;
}

bool _clampBool(dynamic v, bool def) => v is bool ? v : def;

class LoudnessConfig extends Equatable {
  const LoudnessConfig({
    this.enabled = true,
    this.targetLufs = -16,
    this.maxGainDb = 8,
    this.maxAttenuationDb = 8,
    this.adaptRateDbPerSec = 1.5,
  });

  final bool enabled;
  final double targetLufs;
  final double maxGainDb;
  final double maxAttenuationDb;
  final double adaptRateDbPerSec;

  LoudnessConfig sanitized() => LoudnessConfig(
        enabled: enabled,
        targetLufs: _clampNum(targetLufs, -16, -36, -8),
        maxGainDb: _clampNum(maxGainDb, 8, 0, 12),
        maxAttenuationDb: _clampNum(maxAttenuationDb, 8, 0, 12),
        adaptRateDbPerSec: _clampNum(adaptRateDbPerSec, 1.5, 0.1, 6),
      );

  @override
  List<Object?> get props => <Object?>[enabled, targetLufs, maxGainDb, maxAttenuationDb, adaptRateDbPerSec];
}

class EqBandConfig extends Equatable {
  const EqBandConfig({
    required this.type,
    required this.freqHz,
    required this.gainDb,
    required this.q,
  });

  /// 0 lowshelf, 1 peaking, 2 highshelf.
  final int type;
  final double freqHz;
  final double gainDb;
  final double q;

  EqBandConfig sanitized() => EqBandConfig(
        type: type < 0 || type > 2 ? 1 : type,
        freqHz: _clampNum(freqHz, 1000, 20, 20000),
        gainDb: _clampNum(gainDb, 0, -15, 15),
        q: _clampNum(q, 0.9, 0.3, 4),
      );

  @override
  List<Object?> get props => <Object?>[type, freqHz, gainDb, q];
}

class EqConfig extends Equatable {
  const EqConfig({required this.bands});

  final List<EqBandConfig> bands;

  EqConfig sanitized() => EqConfig(
        bands: bands.map((EqBandConfig b) => b.sanitized()).toList(),
      );

  @override
  List<Object?> get props => <Object?>[bands];
}

class DrcConfig extends Equatable {
  const DrcConfig({
    this.enabled = true,
    this.thresholdDb = -24,
    this.ratio = 2.5,
    this.kneeDb = 6,
    this.attackMs = 15,
    this.releaseMs = 250,
    this.makeupDb = 0,
    this.mixPercent = 100,
  });

  final bool enabled;
  final double thresholdDb;
  final double ratio;
  final double kneeDb;
  final double attackMs;
  final double releaseMs;
  final double makeupDb;
  final double mixPercent;

  DrcConfig sanitized() => DrcConfig(
        enabled: enabled,
        thresholdDb: _clampNum(thresholdDb, -24, -60, 0),
        ratio: _clampNum(ratio, 2.5, 1, 20),
        kneeDb: _clampNum(kneeDb, 6, 0, 24),
        attackMs: _clampNum(attackMs, 15, 0.5, 200),
        releaseMs: _clampNum(releaseMs, 250, 20, 1000),
        makeupDb: _clampNum(makeupDb, 0, -6, 12),
        mixPercent: _clampNum(mixPercent, 100, 0, 100),
      );

  static DrcConfig forMode(DynamicRangeMode mode) => switch (mode) {
        DynamicRangeMode.cinema => const DrcConfig(
            thresholdDb: -28, ratio: 2, kneeDb: 6, attackMs: 15, releaseMs: 250),
        DynamicRangeMode.standard => const DrcConfig(
            thresholdDb: -24, ratio: 2.5, kneeDb: 8, attackMs: 10, releaseMs: 200),
        DynamicRangeMode.night => const DrcConfig(
            thresholdDb: -34, ratio: 4, kneeDb: 10, attackMs: 5, releaseMs: 150, mixPercent: 30),
      };

  @override
  List<Object?> get props => <Object?>[
        enabled, thresholdDb, ratio, kneeDb, attackMs, releaseMs, makeupDb, mixPercent,
      ];
}

class DialogueConfig extends Equatable {
  const DialogueConfig({this.enabled = true, this.intensityPercent = 35});

  final bool enabled;
  final double intensityPercent;

  DialogueConfig sanitized() => DialogueConfig(
        enabled: enabled,
        intensityPercent: _clampNum(intensityPercent, 35, 0, 100),
      );

  @override
  List<Object?> get props => <Object?>[enabled, intensityPercent];
}

class BassConfig extends Equatable {
  const BassConfig({
    this.enabled = true,
    this.intensityPercent = 50,
    this.crossoverHz = 80,
    this.speakerMode = AudioSpeakerMode.full,
    this.subShelfGainDb = 5,
    this.harmonicDrivePercent = 0,
    this.lfeGainDb = 0,
  });

  final bool enabled;
  final double intensityPercent;
  final double crossoverHz;
  final AudioSpeakerMode speakerMode;
  final double subShelfGainDb;
  final double harmonicDrivePercent;
  final double lfeGainDb;

  BassConfig sanitized() => BassConfig(
        enabled: enabled,
        intensityPercent: _clampNum(intensityPercent, 50, 0, 100),
        crossoverHz: _clampNum(crossoverHz, 80, 50, 160),
        speakerMode: speakerMode,
        subShelfGainDb: _clampNum(subShelfGainDb, 5, -6, 9),
        harmonicDrivePercent: _clampNum(harmonicDrivePercent, 0, 0, 100),
        lfeGainDb: _clampNum(lfeGainDb, 0, -12, 6),
      );

  @override
  List<Object?> get props => <Object?>[
        enabled, intensityPercent, crossoverHz, speakerMode,
        subShelfGainDb, harmonicDrivePercent, lfeGainDb,
      ];
}

class SpatialConfig extends Equatable {
  const SpatialConfig({
    this.enabled = true,
    this.widthPercent = 100,
    this.crossfeedPercent = 0,
    this.binauralAmountPercent = 100,
  });

  final bool enabled;
  final double widthPercent;
  final double crossfeedPercent;
  final double binauralAmountPercent;

  /// Le mode binaural est actif dès que le crossfeed ou la source multicanale
  /// l'exige ; le cœur DSP gère les deux chemins.
  int get dspMode =>
      crossfeedPercent > 0 || binauralAmountPercent > 0 ? 3 : 1;

  SpatialConfig sanitized() => SpatialConfig(
        enabled: enabled,
        widthPercent: _clampNum(widthPercent, 100, 0, 150),
        crossfeedPercent: _clampNum(crossfeedPercent, 0, 0, 100),
        binauralAmountPercent: _clampNum(binauralAmountPercent, 100, 0, 100),
      );

  @override
  List<Object?> get props => <Object?>[enabled, widthPercent, crossfeedPercent, binauralAmountPercent];
}

class RoomConfig extends Equatable {
  const RoomConfig({this.enabled = true, this.wetPercent = 6, this.sizePercent = 100});

  final bool enabled;
  final double wetPercent;
  final double sizePercent;

  RoomConfig sanitized() => RoomConfig(
        enabled: enabled,
        wetPercent: _clampNum(wetPercent, 6, 0, 15),
        sizePercent: _clampNum(sizePercent, 100, 50, 150),
      );

  @override
  List<Object?> get props => <Object?>[enabled, wetPercent, sizePercent];
}

class LimiterConfig extends Equatable {
  const LimiterConfig({
    this.enabled = true,
    this.ceilingDb = -1,
    this.lookaheadMs = 5,
    this.releaseMs = 120,
  });

  final bool enabled;
  final double ceilingDb;
  final double lookaheadMs;
  final double releaseMs;

  LimiterConfig sanitized() => LimiterConfig(
        enabled: enabled,
        ceilingDb: _clampNum(ceilingDb, -1, -6, 0),
        lookaheadMs: _clampNum(lookaheadMs, 5, 1, 10),
        releaseMs: _clampNum(releaseMs, 120, 40, 500),
      );

  @override
  List<Object?> get props => <Object?>[enabled, ceilingDb, lookaheadMs, releaseMs];
}

/// Configuration complète du moteur.
class AudioEngineConfig extends Equatable {
  const AudioEngineConfig({
    this.enabled = true,
    this.profile = CinevaAudioProfile.cinema,
    this.lfeIntoBass = true,
    this.masterHeadroomDb = 0,
    required this.loudness,
    required this.eq,
    required this.drc,
    required this.dialogue,
    required this.bass,
    required this.spatial,
    required this.room,
    required this.limiter,
  });

  final bool enabled;
  final CinevaAudioProfile profile;
  final bool lfeIntoBass;
  final double masterHeadroomDb;
  final LoudnessConfig loudness;
  final EqConfig eq;
  final DrcConfig drc;
  final DialogueConfig dialogue;
  final BassConfig bass;
  final SpatialConfig spatial;
  final RoomConfig room;
  final LimiterConfig limiter;

  /// Profils prédéfinis.
  factory AudioEngineConfig.forProfile(CinevaAudioProfile profile) {
    switch (profile) {
      case CinevaAudioProfile.cinema:
        return const AudioEngineConfig(
          profile: CinevaAudioProfile.cinema,
          loudness: LoudnessConfig(targetLufs: -18, maxGainDb: 8, adaptRateDbPerSec: 1.2),
          eq: EqConfig(bands: <EqBandConfig>[
            EqBandConfig(type: 0, freqHz: 45, gainDb: 1.5, q: 0.7),
            EqBandConfig(type: 1, freqHz: 90, gainDb: 1.0, q: 0.9),
            EqBandConfig(type: 1, freqHz: 300, gainDb: -0.5, q: 1.0),
            EqBandConfig(type: 1, freqHz: 1200, gainDb: 0.3, q: 0.9),
            EqBandConfig(type: 1, freqHz: 3500, gainDb: 0.8, q: 0.9),
            EqBandConfig(type: 2, freqHz: 10000, gainDb: 1.2, q: 0.7),
          ]),
          drc: DrcConfig(thresholdDb: -28, ratio: 2, kneeDb: 6, attackMs: 15, releaseMs: 250),
          dialogue: DialogueConfig(intensityPercent: 35),
          bass: BassConfig(intensityPercent: 55, subShelfGainDb: 5.5),
          spatial: SpatialConfig(widthPercent: 100, crossfeedPercent: 0, binauralAmountPercent: 100),
          room: RoomConfig(wetPercent: 8, sizePercent: 100),
          limiter: LimiterConfig(ceilingDb: -0.5),
        );
      case CinevaAudioProfile.immersive:
        return const AudioEngineConfig(
          profile: CinevaAudioProfile.immersive,
          loudness: LoudnessConfig(targetLufs: -17),
          eq: EqConfig(bands: <EqBandConfig>[
            EqBandConfig(type: 0, freqHz: 45, gainDb: 1.0, q: 0.7),
            EqBandConfig(type: 1, freqHz: 90, gainDb: 0.5, q: 0.9),
            EqBandConfig(type: 1, freqHz: 300, gainDb: -0.5, q: 1.0),
            EqBandConfig(type: 1, freqHz: 1200, gainDb: 0.2, q: 0.9),
            EqBandConfig(type: 1, freqHz: 3500, gainDb: 0.6, q: 0.9),
            EqBandConfig(type: 2, freqHz: 10000, gainDb: 1.0, q: 0.7),
          ]),
          drc: DrcConfig(thresholdDb: -28, ratio: 2, kneeDb: 6, attackMs: 15, releaseMs: 250),
          dialogue: DialogueConfig(intensityPercent: 30),
          bass: BassConfig(intensityPercent: 45, subShelfGainDb: 4.5),
          spatial: SpatialConfig(widthPercent: 115, crossfeedPercent: 35, binauralAmountPercent: 100),
          room: RoomConfig(wetPercent: 10, sizePercent: 110),
          limiter: LimiterConfig(ceilingDb: -1),
        );
      case CinevaAudioProfile.tv:
        return const AudioEngineConfig(
          profile: CinevaAudioProfile.tv,
          loudness: LoudnessConfig(targetLufs: -16),
          eq: EqConfig(bands: <EqBandConfig>[
            EqBandConfig(type: 0, freqHz: 45, gainDb: -2.0, q: 0.7),
            EqBandConfig(type: 1, freqHz: 90, gainDb: 0, q: 0.9),
            EqBandConfig(type: 1, freqHz: 300, gainDb: -1.0, q: 1.0),
            EqBandConfig(type: 1, freqHz: 1200, gainDb: 0.6, q: 0.9),
            EqBandConfig(type: 1, freqHz: 3500, gainDb: 1.2, q: 0.9),
            EqBandConfig(type: 2, freqHz: 10000, gainDb: 1.5, q: 0.7),
          ]),
          drc: DrcConfig(thresholdDb: -24, ratio: 2.5, kneeDb: 8, attackMs: 10, releaseMs: 200),
          dialogue: DialogueConfig(intensityPercent: 65),
          bass: BassConfig(
            intensityPercent: 30,
            crossoverHz: 90,
            speakerMode: AudioSpeakerMode.small,
            subShelfGainDb: 4,
            harmonicDrivePercent: 40,
          ),
          spatial: SpatialConfig(widthPercent: 105, crossfeedPercent: 0, binauralAmountPercent: 60),
          room: RoomConfig(wetPercent: 4, sizePercent: 90),
          limiter: LimiterConfig(ceilingDb: -1),
        );
      case CinevaAudioProfile.night:
        return const AudioEngineConfig(
          profile: CinevaAudioProfile.night,
          loudness: LoudnessConfig(targetLufs: -15, maxGainDb: 6, adaptRateDbPerSec: 2.0),
          eq: EqConfig(bands: <EqBandConfig>[
            EqBandConfig(type: 0, freqHz: 45, gainDb: -1.5, q: 0.7),
            EqBandConfig(type: 1, freqHz: 90, gainDb: 0, q: 0.9),
            EqBandConfig(type: 1, freqHz: 300, gainDb: -0.5, q: 1.0),
            EqBandConfig(type: 1, freqHz: 1200, gainDb: 0.4, q: 0.9),
            EqBandConfig(type: 1, freqHz: 3500, gainDb: 1.0, q: 0.9),
            EqBandConfig(type: 2, freqHz: 10000, gainDb: 0.8, q: 0.7),
          ]),
          drc: DrcConfig(thresholdDb: -34, ratio: 4, kneeDb: 10, attackMs: 5, releaseMs: 150, mixPercent: 30),
          dialogue: DialogueConfig(intensityPercent: 55),
          bass: BassConfig(intensityPercent: 25, subShelfGainDb: 3),
          spatial: SpatialConfig(widthPercent: 100, crossfeedPercent: 0, binauralAmountPercent: 70),
          room: RoomConfig(wetPercent: 3, sizePercent: 90),
          limiter: LimiterConfig(ceilingDb: -1),
        );
      case CinevaAudioProfile.original:
        return const AudioEngineConfig(
          profile: CinevaAudioProfile.original,
          loudness: LoudnessConfig(enabled: false),
          eq: EqConfig(bands: <EqBandConfig>[]),
          drc: DrcConfig(enabled: false),
          dialogue: DialogueConfig(enabled: false),
          bass: BassConfig(enabled: false),
          spatial: SpatialConfig(enabled: false),
          room: RoomConfig(enabled: false),
          limiter: LimiterConfig(enabled: false),
        );
    }
  }

  AudioEngineConfig sanitized() => AudioEngineConfig(
        enabled: enabled,
        profile: profile,
        lfeIntoBass: lfeIntoBass,
        masterHeadroomDb: _clampNum(masterHeadroomDb, 0, -12, 12),
        loudness: loudness.sanitized(),
        eq: eq.sanitized(),
        drc: drc.sanitized(),
        dialogue: dialogue.sanitized(),
        bass: bass.sanitized(),
        spatial: spatial.sanitized(),
        room: room.sanitized(),
        limiter: limiter.sanitized(),
      );

  AudioEngineConfig copyWith({
    bool? enabled,
    CinevaAudioProfile? profile,
    bool? lfeIntoBass,
    double? masterHeadroomDb,
    LoudnessConfig? loudness,
    EqConfig? eq,
    DrcConfig? drc,
    DialogueConfig? dialogue,
    BassConfig? bass,
    SpatialConfig? spatial,
    RoomConfig? room,
    LimiterConfig? limiter,
  }) =>
      AudioEngineConfig(
        enabled: enabled ?? this.enabled,
        profile: profile ?? this.profile,
        lfeIntoBass: lfeIntoBass ?? this.lfeIntoBass,
        masterHeadroomDb: masterHeadroomDb ?? this.masterHeadroomDb,
        loudness: loudness ?? this.loudness,
        eq: eq ?? this.eq,
        drc: drc ?? this.drc,
        dialogue: dialogue ?? this.dialogue,
        bass: bass ?? this.bass,
        spatial: spatial ?? this.spatial,
        room: room ?? this.room,
        limiter: limiter ?? this.limiter,
      );

  /// Traduit la configuration en tableau de paramètres du cœur DSP.
  Float64List toParams({double sampleRate = 48000, int channels = 2}) {
    final AudioEngineConfig c = sanitized();
    final Float64List p = neutralParams(sampleRate: sampleRate, channels: channels);
    p[DspParam.masterEnable] = c.enabled ? 1 : 0;
    p[DspParam.lfeIntoBass] = c.lfeIntoBass ? 1 : 0;
    p[DspParam.masterHeadroomDb] = c.masterHeadroomDb;

    p[DspParam.loudnessEnable] = c.loudness.enabled ? 1 : 0;
    p[DspParam.loudnessTargetLufs] = c.loudness.targetLufs;
    p[DspParam.loudnessMaxGainDb] = c.loudness.maxGainDb;
    p[DspParam.loudnessMaxAttenuationDb] = c.loudness.maxAttenuationDb;
    p[DspParam.loudnessAdaptRateDbPerSec] = c.loudness.adaptRateDbPerSec;

    final List<EqBandConfig> bands = c.eq.bands;
    p[DspParam.eqEnable] = bands.isEmpty ? 0 : 1;
    if (bands.isNotEmpty) {
      for (int i = 0; i < bands.length && i < 6; i++) {
        p[DspParam.eqType(i)] = bands[i].type.toDouble();
        p[DspParam.eqFreq(i)] = bands[i].freqHz;
        p[DspParam.eqGainDb(i)] = bands[i].gainDb;
        p[DspParam.eqQ(i)] = bands[i].q;
      }
    } else {
      for (int i = 0; i < 6; i++) {
        p[DspParam.eqGainDb(i)] = 0;
      }
    }

    p[DspParam.drcEnable] = c.drc.enabled ? 1 : 0;
    p[DspParam.drcThresholdDb] = c.drc.thresholdDb;
    p[DspParam.drcRatio] = c.drc.ratio;
    p[DspParam.drcKneeDb] = c.drc.kneeDb;
    p[DspParam.drcAttackMs] = c.drc.attackMs;
    p[DspParam.drcReleaseMs] = c.drc.releaseMs;
    p[DspParam.drcMakeupDb] = c.drc.makeupDb;
    p[DspParam.drcMixPercent] = c.drc.mixPercent;

    p[DspParam.dialogueEnable] = c.dialogue.enabled ? 1 : 0;
    p[DspParam.dialogueIntensityPercent] = c.dialogue.intensityPercent;

    p[DspParam.bassEnable] = c.bass.enabled ? 1 : 0;
    p[DspParam.bassIntensityPercent] = c.bass.intensityPercent;
    p[DspParam.bassCrossoverHz] = c.bass.crossoverHz;
    p[DspParam.bassSpeakerMode] = c.bass.speakerMode.dspValue.toDouble();
    p[DspParam.bassSubShelfGainDb] = c.bass.subShelfGainDb;
    p[DspParam.bassHarmonicDrivePercent] = c.bass.harmonicDrivePercent;
    p[DspParam.bassLfeGainDb] = c.bass.lfeGainDb;

    p[DspParam.spatialEnable] = c.spatial.enabled ? 1 : 0;
    p[DspParam.spatialMode] = c.spatial.dspMode.toDouble();
    p[DspParam.spatialWidthPercent] = c.spatial.widthPercent;
    p[DspParam.spatialCrossfeedPercent] = c.spatial.crossfeedPercent;
    p[DspParam.spatialBinauralAmountPercent] = c.spatial.binauralAmountPercent;

    p[DspParam.roomEnable] = c.room.enabled ? 1 : 0;
    p[DspParam.roomWetPercent] = c.room.wetPercent;
    p[DspParam.roomSizePercent] = c.room.sizePercent;

    p[DspParam.limiterEnable] = c.limiter.enabled ? 1 : 0;
    p[DspParam.limiterCeilingDb] = c.limiter.ceilingDb;
    p[DspParam.limiterLookaheadMs] = c.limiter.lookaheadMs;
    p[DspParam.limiterReleaseMs] = c.limiter.releaseMs;

    return p;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'profile': profile.name,
        'lfeIntoBass': lfeIntoBass,
        'masterHeadroomDb': masterHeadroomDb,
        'loudness': <String, dynamic>{
          'enabled': loudness.enabled,
          'targetLufs': loudness.targetLufs,
          'maxGainDb': loudness.maxGainDb,
          'maxAttenuationDb': loudness.maxAttenuationDb,
          'adaptRateDbPerSec': loudness.adaptRateDbPerSec,
        },
        'eq': <String, dynamic>{
          'bands': bands
              .map((EqBandConfig b) => <String, dynamic>{
                    'type': b.type,
                    'freqHz': b.freqHz,
                    'gainDb': b.gainDb,
                    'q': b.q,
                  })
              .toList(),
        },
        'drc': <String, dynamic>{
          'enabled': drc.enabled,
          'thresholdDb': drc.thresholdDb,
          'ratio': drc.ratio,
          'kneeDb': drc.kneeDb,
          'attackMs': drc.attackMs,
          'releaseMs': drc.releaseMs,
          'makeupDb': drc.makeupDb,
          'mixPercent': drc.mixPercent,
        },
        'dialogue': <String, dynamic>{
          'enabled': dialogue.enabled,
          'intensityPercent': dialogue.intensityPercent,
        },
        'bass': <String, dynamic>{
          'enabled': bass.enabled,
          'intensityPercent': bass.intensityPercent,
          'crossoverHz': bass.crossoverHz,
          'speakerMode': bass.speakerMode.name,
          'subShelfGainDb': bass.subShelfGainDb,
          'harmonicDrivePercent': bass.harmonicDrivePercent,
          'lfeGainDb': bass.lfeGainDb,
        },
        'spatial': <String, dynamic>{
          'enabled': spatial.enabled,
          'widthPercent': spatial.widthPercent,
          'crossfeedPercent': spatial.crossfeedPercent,
          'binauralAmountPercent': spatial.binauralAmountPercent,
        },
        'room': <String, dynamic>{
          'enabled': room.enabled,
          'wetPercent': room.wetPercent,
          'sizePercent': room.sizePercent,
        },
        'limiter': <String, dynamic>{
          'enabled': limiter.enabled,
          'ceilingDb': limiter.ceilingDb,
          'lookaheadMs': limiter.lookaheadMs,
          'releaseMs': limiter.releaseMs,
        },
      };

  factory AudioEngineConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AudioEngineConfig.forProfile(CinevaAudioProfile.cinema);
    final CinevaAudioProfile profile = CinevaAudioProfileX.fromName(json['profile'] as String?);
    final AudioEngineConfig base = AudioEngineConfig.forProfile(profile);
    final Map<String, dynamic>? eqJson = _map(json['eq']);
    final List<dynamic>? bandList = eqJson?['bands'] as List<dynamic>?;
    final List<EqBandConfig> bands = bandList == null
        ? base.eq.bands
        : bandList
            .map((dynamic b) {
              final Map<String, dynamic> m = _map(b) ?? <String, dynamic>{};
              return EqBandConfig(
                type: _clampNum(m['type'], 1, 0, 2).toInt(),
                freqHz: _clampNum(m['freqHz'], 1000, 20, 20000),
                gainDb: _clampNum(m['gainDb'], 0, -15, 15),
                q: _clampNum(m['q'], 0.9, 0.3, 4),
              );
            })
            .toList();
    final Map<String, dynamic>? loudJson = _map(json['loudness']);
    final Map<String, dynamic>? drcJson = _map(json['drc']);
    final Map<String, dynamic>? dlgJson = _map(json['dialogue']);
    final Map<String, dynamic>? bassJson = _map(json['bass']);
    final Map<String, dynamic>? spatialJson = _map(json['spatial']);
    final Map<String, dynamic>? roomJson = _map(json['room']);
    final Map<String, dynamic>? limJson = _map(json['limiter']);
    return base
        .copyWith(
          enabled: _clampBool(json['enabled'], true),
          lfeIntoBass: _clampBool(json['lfeIntoBass'], true),
          masterHeadroomDb: _clampNum(json['masterHeadroomDb'], 0, -12, 12),
          loudness: LoudnessConfig(
            enabled: _clampBool(loudJson?['enabled'], base.loudness.enabled),
            targetLufs: _clampNum(loudJson?['targetLufs'], base.loudness.targetLufs, -36, -8),
            maxGainDb: _clampNum(loudJson?['maxGainDb'], base.loudness.maxGainDb, 0, 12),
            maxAttenuationDb: _clampNum(loudJson?['maxAttenuationDb'], base.loudness.maxAttenuationDb, 0, 12),
            adaptRateDbPerSec: _clampNum(loudJson?['adaptRateDbPerSec'], base.loudness.adaptRateDbPerSec, 0.1, 6),
          ),
          eq: EqConfig(bands: bands),
          drc: DrcConfig(
            enabled: _clampBool(drcJson?['enabled'], base.drc.enabled),
            thresholdDb: _clampNum(drcJson?['thresholdDb'], base.drc.thresholdDb, -60, 0),
            ratio: _clampNum(drcJson?['ratio'], base.drc.ratio, 1, 20),
            kneeDb: _clampNum(drcJson?['kneeDb'], base.drc.kneeDb, 0, 24),
            attackMs: _clampNum(drcJson?['attackMs'], base.drc.attackMs, 0.5, 200),
            releaseMs: _clampNum(drcJson?['releaseMs'], base.drc.releaseMs, 20, 1000),
            makeupDb: _clampNum(drcJson?['makeupDb'], base.drc.makeupDb, -6, 12),
            mixPercent: _clampNum(drcJson?['mixPercent'], base.drc.mixPercent, 0, 100),
          ),
          dialogue: DialogueConfig(
            enabled: _clampBool(dlgJson?['enabled'], base.dialogue.enabled),
            intensityPercent: _clampNum(dlgJson?['intensityPercent'], base.dialogue.intensityPercent, 0, 100),
          ),
          bass: BassConfig(
            enabled: _clampBool(bassJson?['enabled'], base.bass.enabled),
            intensityPercent: _clampNum(bassJson?['intensityPercent'], base.bass.intensityPercent, 0, 100),
            crossoverHz: _clampNum(bassJson?['crossoverHz'], base.bass.crossoverHz, 50, 160),
            speakerMode: AudioSpeakerModeX.fromName(bassJson?['speakerMode'] as String?),
            subShelfGainDb: _clampNum(bassJson?['subShelfGainDb'], base.bass.subShelfGainDb, -6, 9),
            harmonicDrivePercent: _clampNum(bassJson?['harmonicDrivePercent'], base.bass.harmonicDrivePercent, 0, 100),
            lfeGainDb: _clampNum(bassJson?['lfeGainDb'], base.bass.lfeGainDb, -12, 6),
          ),
          spatial: SpatialConfig(
            enabled: _clampBool(spatialJson?['enabled'], base.spatial.enabled),
            widthPercent: _clampNum(spatialJson?['widthPercent'], base.spatial.widthPercent, 0, 150),
            crossfeedPercent: _clampNum(spatialJson?['crossfeedPercent'], base.spatial.crossfeedPercent, 0, 100),
            binauralAmountPercent: _clampNum(spatialJson?['binauralAmountPercent'], base.spatial.binauralAmountPercent, 0, 100),
          ),
          room: RoomConfig(
            enabled: _clampBool(roomJson?['enabled'], base.room.enabled),
            wetPercent: _clampNum(roomJson?['wetPercent'], base.room.wetPercent, 0, 15),
            sizePercent: _clampNum(roomJson?['sizePercent'], base.room.sizePercent, 50, 150),
          ),
          limiter: LimiterConfig(
            enabled: _clampBool(limJson?['enabled'], base.limiter.enabled),
            ceilingDb: _clampNum(limJson?['ceilingDb'], base.limiter.ceilingDb, -6, 0),
            lookaheadMs: _clampNum(limJson?['lookaheadMs'], base.limiter.lookaheadMs, 1, 10),
            releaseMs: _clampNum(limJson?['releaseMs'], base.limiter.releaseMs, 40, 500),
          ),
        )
        .sanitized();
  }

  static Map<String, dynamic>? _map(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  @override
  List<Object?> get props => <Object?>[
        enabled, profile, lfeIntoBass, masterHeadroomDb,
        loudness, eq, drc, dialogue, bass, spatial, room, limiter,
      ];
}
