import 'package:equatable/equatable.dart';

enum CinevaVisionProfile {
  standard,
  cinema,
  oled,
  ultra,
  aiBeta,
  custom,
}

extension CinevaVisionProfileX on CinevaVisionProfile {
  String get label => switch (this) {
        CinevaVisionProfile.standard => 'Standard',
        CinevaVisionProfile.cinema => 'Cinéma',
        CinevaVisionProfile.oled => 'OLED',
        CinevaVisionProfile.ultra => 'Ultra',
        CinevaVisionProfile.aiBeta => 'IA (Bêta)',
        CinevaVisionProfile.custom => 'Personnalisé',
      };

  String get description => switch (this) {
        CinevaVisionProfile.standard => 'Qualité d’origine, traitement minimal.',
        CinevaVisionProfile.cinema => 'Couleurs plus riches, contraste adouci et tonalité plus chaude.',
        CinevaVisionProfile.oled => 'Noirs plus profonds et saturation optimisée pour écrans OLED.',
        CinevaVisionProfile.ultra => 'Netteté renforcée, contraste dynamique et textures rehaussées.',
        CinevaVisionProfile.aiBeta => 'Architecture prête pour des traitements intelligents plus avancés.',
        CinevaVisionProfile.custom => 'Réglages manuels enregistrés pour votre usage.',
      };
}

enum DisplayTechnology {
  unknown,
  lcd,
  oled,
}

extension DisplayTechnologyX on DisplayTechnology {
  String get label => switch (this) {
        DisplayTechnology.unknown => 'Inconnu',
        DisplayTechnology.lcd => 'LCD',
        DisplayTechnology.oled => 'OLED',
      };
}

enum DevicePerformanceTier {
  entry,
  balanced,
  premium,
}

extension DevicePerformanceTierX on DevicePerformanceTier {
  String get label => switch (this) {
        DevicePerformanceTier.entry => 'Essentiel',
        DevicePerformanceTier.balanced => 'Équilibré',
        DevicePerformanceTier.premium => 'Premium',
      };
}

class CinevaVisionOptions extends Equatable {
  const CinevaVisionOptions({
    required this.smartSharpness,
    required this.enhancedColors,
    required this.dynamicContrast,
    required this.noiseReduction,
    required this.advancedSmoothness,
    required this.optimizedHdr,
    required this.aiEnhancement,
  });

  factory CinevaVisionOptions.defaults() {
    return const CinevaVisionOptions(
      smartSharpness: false,
      enhancedColors: false,
      dynamicContrast: false,
      noiseReduction: false,
      advancedSmoothness: false,
      optimizedHdr: false,
      aiEnhancement: false,
    );
  }

  final bool smartSharpness;
  final bool enhancedColors;
  final bool dynamicContrast;
  final bool noiseReduction;
  final bool advancedSmoothness;
  final bool optimizedHdr;
  final bool aiEnhancement;

  CinevaVisionOptions copyWith({
    bool? smartSharpness,
    bool? enhancedColors,
    bool? dynamicContrast,
    bool? noiseReduction,
    bool? advancedSmoothness,
    bool? optimizedHdr,
    bool? aiEnhancement,
  }) {
    return CinevaVisionOptions(
      smartSharpness: smartSharpness ?? this.smartSharpness,
      enhancedColors: enhancedColors ?? this.enhancedColors,
      dynamicContrast: dynamicContrast ?? this.dynamicContrast,
      noiseReduction: noiseReduction ?? this.noiseReduction,
      advancedSmoothness: advancedSmoothness ?? this.advancedSmoothness,
      optimizedHdr: optimizedHdr ?? this.optimizedHdr,
      aiEnhancement: aiEnhancement ?? this.aiEnhancement,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'smartSharpness': smartSharpness,
      'enhancedColors': enhancedColors,
      'dynamicContrast': dynamicContrast,
      'noiseReduction': noiseReduction,
      'advancedSmoothness': advancedSmoothness,
      'optimizedHdr': optimizedHdr,
      'aiEnhancement': aiEnhancement,
    };
  }

  factory CinevaVisionOptions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CinevaVisionOptions.defaults();
    return CinevaVisionOptions(
      smartSharpness: json['smartSharpness'] as bool? ?? false,
      enhancedColors: json['enhancedColors'] as bool? ?? false,
      dynamicContrast: json['dynamicContrast'] as bool? ?? false,
      noiseReduction: json['noiseReduction'] as bool? ?? false,
      advancedSmoothness: json['advancedSmoothness'] as bool? ?? false,
      optimizedHdr: json['optimizedHdr'] as bool? ?? false,
      aiEnhancement: json['aiEnhancement'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        smartSharpness,
        enhancedColors,
        dynamicContrast,
        noiseReduction,
        advancedSmoothness,
        optimizedHdr,
        aiEnhancement,
      ];
}

class CinevaVisionSettings extends Equatable {
  const CinevaVisionSettings({
    required this.profile,
    required this.options,
    required this.autoRecommended,
  });

  factory CinevaVisionSettings.defaults() {
    return CinevaVisionSettings(
      profile: CinevaVisionProfile.standard,
      options: CinevaVisionOptions.defaults(),
      autoRecommended: true,
    );
  }

  final CinevaVisionProfile profile;
  final CinevaVisionOptions options;
  final bool autoRecommended;

  CinevaVisionSettings copyWith({
    CinevaVisionProfile? profile,
    CinevaVisionOptions? options,
    bool? autoRecommended,
  }) {
    return CinevaVisionSettings(
      profile: profile ?? this.profile,
      options: options ?? this.options,
      autoRecommended: autoRecommended ?? this.autoRecommended,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'profile': profile.name,
      'options': options.toJson(),
      'autoRecommended': autoRecommended,
    };
  }

  factory CinevaVisionSettings.fromJson({
    required String? profileName,
    required Map<String, dynamic>? optionsJson,
    required bool? autoRecommended,
  }) {
    var profile = CinevaVisionProfile.standard;
    for (final value in CinevaVisionProfile.values) {
      if (value.name == profileName) {
        profile = value;
        break;
      }
    }

    return CinevaVisionSettings(
      profile: profile,
      options: CinevaVisionOptions.fromJson(optionsJson),
      autoRecommended: autoRecommended ?? true,
    );
  }

  @override
  List<Object?> get props => <Object?>[profile, options, autoRecommended];
}

class DeviceCapabilities extends Equatable {
  const DeviceCapabilities({
    required this.platform,
    required this.operatingSystemVersion,
    required this.screenWidth,
    required this.screenHeight,
    required this.pixelRatio,
    required this.refreshRate,
    required this.displayTechnology,
    required this.performanceTier,
    required this.isTv,
    required this.isDesktop,
    required this.isTablet,
    required this.smartSharpnessSupported,
    required this.enhancedColorsSupported,
    required this.dynamicContrastSupported,
    required this.noiseReductionSupported,
    required this.advancedSmoothnessSupported,
    required this.optimizedHdrSupported,
    required this.aiEnhancementSupported,
  });

  final String platform;
  final String operatingSystemVersion;
  final double screenWidth;
  final double screenHeight;
  final double pixelRatio;
  final double refreshRate;
  final DisplayTechnology displayTechnology;
  final DevicePerformanceTier performanceTier;
  final bool isTv;
  final bool isDesktop;
  final bool isTablet;
  final bool smartSharpnessSupported;
  final bool enhancedColorsSupported;
  final bool dynamicContrastSupported;
  final bool noiseReductionSupported;
  final bool advancedSmoothnessSupported;
  final bool optimizedHdrSupported;
  final bool aiEnhancementSupported;

  String get resolutionLabel =>
      '${(screenWidth * pixelRatio).round()} × ${(screenHeight * pixelRatio).round()}';

  String get recommendedModeLabel {
    final base = switch (recommendedProfile) {
      CinevaVisionProfile.standard => 'Standard',
      CinevaVisionProfile.cinema => 'Cinéma',
      CinevaVisionProfile.oled => 'OLED',
      CinevaVisionProfile.ultra => displayTechnology == DisplayTechnology.oled ? 'Ultra OLED' : 'Ultra',
      CinevaVisionProfile.aiBeta => 'IA (Bêta)',
      CinevaVisionProfile.custom => 'Personnalisé',
    };
    return base;
  }

  CinevaVisionProfile get recommendedProfile {
    if (aiEnhancementSupported && performanceTier == DevicePerformanceTier.premium && (isDesktop || isTv)) {
      return CinevaVisionProfile.aiBeta;
    }
    if (displayTechnology == DisplayTechnology.oled && performanceTier != DevicePerformanceTier.entry) {
      return CinevaVisionProfile.oled;
    }
    if (performanceTier == DevicePerformanceTier.premium || isTv || isDesktop) {
      return CinevaVisionProfile.ultra;
    }
    if (isTablet) {
      return CinevaVisionProfile.cinema;
    }
    return CinevaVisionProfile.standard;
  }

  @override
  List<Object?> get props => <Object?>[
        platform,
        operatingSystemVersion,
        screenWidth,
        screenHeight,
        pixelRatio,
        refreshRate,
        displayTechnology,
        performanceTier,
        isTv,
        isDesktop,
        isTablet,
        smartSharpnessSupported,
        enhancedColorsSupported,
        dynamicContrastSupported,
        noiseReductionSupported,
        advancedSmoothnessSupported,
        optimizedHdrSupported,
        aiEnhancementSupported,
      ];
}

class CinevaVisionRenderProfile extends Equatable {
  const CinevaVisionRenderProfile({
    required this.saturation,
    required this.contrast,
    required this.brightness,
    required this.warmth,
    required this.overlayOpacity,
    required this.shadowBoost,
  });

  final double saturation;
  final double contrast;
  final double brightness;
  final double warmth;
  final double overlayOpacity;
  final double shadowBoost;

  @override
  List<Object?> get props => <Object?>[
        saturation,
        contrast,
        brightness,
        warmth,
        overlayOpacity,
        shadowBoost,
      ];
}

