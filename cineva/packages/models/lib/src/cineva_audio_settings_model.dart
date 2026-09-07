import 'package:equatable/equatable.dart';

/// Profils du Cineva Audio Engine (miroir utilisateur de
/// `cineva_audio_engine` ; la correspondance complète vit dans le moteur).
enum CinevaAudioProfile {
  cinema,
  immersive,
  tv,
  night,
  original,
}

extension CinevaAudioProfileX on CinevaAudioProfile {
  String get label => switch (this) {
        CinevaAudioProfile.cinema => 'Cinéma',
        CinevaAudioProfile.immersive => 'Immersif',
        CinevaAudioProfile.tv => 'TV',
        CinevaAudioProfile.night => 'Night',
        CinevaAudioProfile.original => 'Original',
      };

  String get description => switch (this) {
        CinevaAudioProfile.cinema => 'Dynamique, basses profondes, dialogues clairs, scène sonore large.',
        CinevaAudioProfile.immersive => 'Spatialisation renforcée pour le casque, profondeur et largeur.',
        CinevaAudioProfile.tv => 'Optimisé pour les haut-parleurs de TV.',
        CinevaAudioProfile.night => 'Dynamique compressée, explosions adoucies, dialogues clairs.',
        CinevaAudioProfile.original => 'Aucun traitement — pour comparer avec le son d’origine.',
      };

  static CinevaAudioProfile fromName(String? name) {
    for (final CinevaAudioProfile value in CinevaAudioProfile.values) {
      if (value.name == name) return value;
    }
    return CinevaAudioProfile.cinema;
  }
}

/// Mode de dynamique choisi par l'utilisateur.
enum CinevaAudioDynamicRange {
  cinema,
  standard,
  night,
}

extension CinevaAudioDynamicRangeX on CinevaAudioDynamicRange {
  String get label => switch (this) {
        CinevaAudioDynamicRange.cinema => 'Cinéma',
        CinevaAudioDynamicRange.standard => 'Standard',
        CinevaAudioDynamicRange.night => 'Night',
      };

  static CinevaAudioDynamicRange fromName(String? name) {
    for (final CinevaAudioDynamicRange value in CinevaAudioDynamicRange.values) {
      if (value.name == name) return value;
    }
    return CinevaAudioDynamicRange.cinema;
  }
}

/// Type de sortie audio (adapte bass management et spatialisation).
enum CinevaAudioOutput {
  speakers,
  tv,
  headphone,
}

extension CinevaAudioOutputX on CinevaAudioOutput {
  String get label => switch (this) {
        CinevaAudioOutput.speakers => 'Haut-parleurs',
        CinevaAudioOutput.tv => 'TV',
        CinevaAudioOutput.headphone => 'Casque',
      };

  static CinevaAudioOutput fromName(String? name) {
    for (final CinevaAudioOutput value in CinevaAudioOutput.values) {
      if (value.name == name) return value;
    }
    return CinevaAudioOutput.speakers;
  }
}

/// Réglages DSP avancés (section « Audio avancé »).
class CinevaAudioAdvancedSettings extends Equatable {
  const CinevaAudioAdvancedSettings({
    required this.eqBandGains,
    required this.eqEnabled,
    required this.crossoverHz,
    required this.subShelfGainDb,
    required this.roomWetPercent,
    required this.limiterCeilingDb,
  });

  factory CinevaAudioAdvancedSettings.defaults() {
    return const CinevaAudioAdvancedSettings(
      eqBandGains: <double>[0, 0, 0, 0, 0, 0],
      eqEnabled: true,
      crossoverHz: 80,
      subShelfGainDb: 5,
      roomWetPercent: 6,
      limiterCeilingDb: -1,
    );
  }

  /// Gains dB des 6 bandes : sub-bass, bass, low-mid, mid, high-mid, treble.
  final List<double> eqBandGains;
  final bool eqEnabled;
  final double crossoverHz;
  final double subShelfGainDb;
  final double roomWetPercent;
  final double limiterCeilingDb;

  CinevaAudioAdvancedSettings copyWith({
    List<double>? eqBandGains,
    bool? eqEnabled,
    double? crossoverHz,
    double? subShelfGainDb,
    double? roomWetPercent,
    double? limiterCeilingDb,
  }) {
    return CinevaAudioAdvancedSettings(
      eqBandGains: eqBandGains ?? this.eqBandGains,
      eqEnabled: eqEnabled ?? this.eqEnabled,
      crossoverHz: crossoverHz ?? this.crossoverHz,
      subShelfGainDb: subShelfGainDb ?? this.subShelfGainDb,
      roomWetPercent: roomWetPercent ?? this.roomWetPercent,
      limiterCeilingDb: limiterCeilingDb ?? this.limiterCeilingDb,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'eqBandGains': eqBandGains,
        'eqEnabled': eqEnabled,
        'crossoverHz': crossoverHz,
        'subShelfGainDb': subShelfGainDb,
        'roomWetPercent': roomWetPercent,
        'limiterCeilingDb': limiterCeilingDb,
      };

  factory CinevaAudioAdvancedSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CinevaAudioAdvancedSettings.defaults();
    final List<dynamic>? gains = json['eqBandGains'] as List<dynamic>?;
    final List<double> bandGains = <double>[];
    if (gains != null) {
      for (int i = 0; i < 6; i++) {
        final dynamic g = i < gains.length ? gains[i] : 0;
        bandGains.add(_clampGain(g));
      }
    } else {
      bandGains.addAll(CinevaAudioAdvancedSettings.defaults().eqBandGains);
    }
    return CinevaAudioAdvancedSettings(
      eqBandGains: bandGains,
      eqEnabled: json['eqEnabled'] as bool? ?? true,
      crossoverHz: _clamp(json['crossoverHz'], 80, 50, 160),
      subShelfGainDb: _clamp(json['subShelfGainDb'], 5, -6, 9),
      roomWetPercent: _clamp(json['roomWetPercent'], 6, 0, 15),
      limiterCeilingDb: _clamp(json['limiterCeilingDb'], -1, -6, 0),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        eqBandGains,
        eqEnabled,
        crossoverHz,
        subShelfGainDb,
        roomWetPercent,
        limiterCeilingDb,
      ];
}

double _clamp(dynamic value, double fallback, double min, double max) {
  final double d = value is num ? value.toDouble() : fallback;
  if (d.isNaN || d < min) return min;
  if (d > max) return max;
  return d;
}

double _clampGain(dynamic value) => _clamp(value, 0, -15, 15);

/// Réglages utilisateur du Cineva Audio Engine (persistés).
class CinevaAudioSettings extends Equatable {
  const CinevaAudioSettings({
    required this.enabled,
    required this.profile,
    required this.spatialEnabled,
    required this.dialogueAmount,
    required this.bassAmount,
    required this.dynamicRange,
    required this.loudnessEnabled,
    required this.output,
    required this.abCompare,
    required this.advanced,
  });

  factory CinevaAudioSettings.defaults() {
    return const CinevaAudioSettings(
      enabled: true,
      profile: CinevaAudioProfile.cinema,
      spatialEnabled: true,
      dialogueAmount: 50,
      bassAmount: 50,
      dynamicRange: CinevaAudioDynamicRange.cinema,
      loudnessEnabled: true,
      output: CinevaAudioOutput.speakers,
      abCompare: false,
      advanced: null,
    );
  }

  /// Moteur activé.
  final bool enabled;

  /// Profil courant.
  final CinevaAudioProfile profile;

  /// Spatialisation (binaurale multicanal / élargissement).
  final bool spatialEnabled;

  /// Intensité dialogue 0–100.
  final double dialogueAmount;

  /// Intensité bass 0–100.
  final double bassAmount;

  /// Mode de dynamique.
  final CinevaAudioDynamicRange dynamicRange;

  /// Normalisation loudness.
  final bool loudnessEnabled;

  /// Type de sortie (adapte le traitement).
  final CinevaAudioOutput output;

  /// Comparaison A/B active (bypass instantané côté player).
  final bool abCompare;

  /// Réglages avancés (null = valeurs du profil).
  final CinevaAudioAdvancedSettings? advanced;

  CinevaAudioSettings copyWith({
    bool? enabled,
    CinevaAudioProfile? profile,
    bool? spatialEnabled,
    double? dialogueAmount,
    double? bassAmount,
    CinevaAudioDynamicRange? dynamicRange,
    bool? loudnessEnabled,
    CinevaAudioOutput? output,
    bool? abCompare,
    CinevaAudioAdvancedSettings? advanced,
    bool clearAdvanced = false,
  }) {
    return CinevaAudioSettings(
      enabled: enabled ?? this.enabled,
      profile: profile ?? this.profile,
      spatialEnabled: spatialEnabled ?? this.spatialEnabled,
      dialogueAmount: _clamp(dialogueAmount ?? this.dialogueAmount, 50, 0, 100),
      bassAmount: _clamp(bassAmount ?? this.bassAmount, 50, 0, 100),
      dynamicRange: dynamicRange ?? this.dynamicRange,
      loudnessEnabled: loudnessEnabled ?? this.loudnessEnabled,
      output: output ?? this.output,
      abCompare: abCompare ?? this.abCompare,
      advanced: clearAdvanced ? null : (advanced ?? this.advanced),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'profile': profile.name,
        'spatialEnabled': spatialEnabled,
        'dialogueAmount': dialogueAmount,
        'bassAmount': bassAmount,
        'dynamicRange': dynamicRange.name,
        'loudnessEnabled': loudnessEnabled,
        'output': output.name,
        'abCompare': abCompare,
        'advanced': advanced?.toJson(),
      };

  factory CinevaAudioSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CinevaAudioSettings.defaults();
    final Map<String, dynamic>? advancedJson = json['advanced'] is Map<String, dynamic>
        ? json['advanced'] as Map<String, dynamic>
        : null;
    return CinevaAudioSettings.defaults().copyWith(
      enabled: json['enabled'] as bool? ?? true,
      profile: CinevaAudioProfileX.fromName(json['profile'] as String?),
      spatialEnabled: json['spatialEnabled'] as bool? ?? true,
      dialogueAmount: _clamp(json['dialogueAmount'], 50, 0, 100),
      bassAmount: _clamp(json['bassAmount'], 50, 0, 100),
      dynamicRange: CinevaAudioDynamicRangeX.fromName(json['dynamicRange'] as String?),
      loudnessEnabled: json['loudnessEnabled'] as bool? ?? true,
      output: CinevaAudioOutputX.fromName(json['output'] as String?),
      abCompare: json['abCompare'] as bool? ?? false,
      advanced: advancedJson == null ? null : CinevaAudioAdvancedSettings.fromJson(advancedJson),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        enabled,
        profile,
        spatialEnabled,
        dialogueAmount,
        bassAmount,
        dynamicRange,
        loudnessEnabled,
        output,
        abCompare,
        advanced,
      ];
}
