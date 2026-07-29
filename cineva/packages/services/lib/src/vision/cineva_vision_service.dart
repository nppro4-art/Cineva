import 'dart:ui';

import 'package:cineva_models/cineva_models.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class CinevaVisionService {
  CinevaVisionService({DeviceInfoPlugin? deviceInfoPlugin})
      : _deviceInfo = deviceInfoPlugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfo;

  Future<DeviceCapabilities> analyzeDevice() async {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final view = dispatcher.views.isNotEmpty ? dispatcher.views.first : dispatcher.implicitView;
    final physicalWidth = view?.physicalSize.width ?? 1080;
    final physicalHeight = view?.physicalSize.height ?? 1920;
    final pixelRatio = view?.devicePixelRatio ?? 1;
    final logicalWidth = physicalWidth / pixelRatio;
    final logicalHeight = physicalHeight / pixelRatio;
    final refreshRate = view?.display.refreshRate ?? 60;

    final platform = _platformLabel();
    final isDesktop = platform == 'windows' || platform == 'macos' || platform == 'linux' || platform == 'web';
    final isTablet = !isDesktop && logicalWidth >= 700;
    final isTv = logicalWidth >= 1200 && logicalHeight >= 700 && !kIsWeb && !isDesktop;
    final displayTechnology = await _inferDisplayTechnology(platform: platform, logicalWidth: logicalWidth, isTv: isTv);
    final performanceTier = _performanceTier(
      isDesktop: isDesktop,
      isTablet: isTablet,
      refreshRate: refreshRate,
      logicalWidth: logicalWidth,
      displayTechnology: displayTechnology,
    );

    final advancedSmoothnessSupported = refreshRate >= 90;
    final optimizedHdrSupported = isDesktop || isTv || logicalWidth * pixelRatio >= 1920;
    final aiEnhancementSupported = isDesktop || isTv || performanceTier == DevicePerformanceTier.premium;

    return DeviceCapabilities(
      platform: platform,
      operatingSystemVersion: await _operatingSystemVersion(platform),
      screenWidth: logicalWidth,
      screenHeight: logicalHeight,
      pixelRatio: pixelRatio,
      refreshRate: refreshRate,
      displayTechnology: displayTechnology,
      performanceTier: performanceTier,
      isTv: isTv,
      isDesktop: isDesktop,
      isTablet: isTablet,
      smartSharpnessSupported: performanceTier != DevicePerformanceTier.entry,
      enhancedColorsSupported: true,
      dynamicContrastSupported: true,
      noiseReductionSupported: performanceTier != DevicePerformanceTier.entry || isTv,
      advancedSmoothnessSupported: advancedSmoothnessSupported,
      optimizedHdrSupported: optimizedHdrSupported,
      aiEnhancementSupported: aiEnhancementSupported,
    );
  }

  CinevaVisionSettings recommendedSettings(DeviceCapabilities capabilities) {
    final base = switch (capabilities.recommendedProfile) {
      CinevaVisionProfile.standard => CinevaVisionSettings.defaults(),
      CinevaVisionProfile.cinema => CinevaVisionSettings(
          profile: CinevaVisionProfile.cinema,
          autoRecommended: true,
          options: CinevaVisionOptions.defaults().copyWith(
            enhancedColors: true,
            dynamicContrast: true,
          ),
        ),
      CinevaVisionProfile.oled => CinevaVisionSettings(
          profile: CinevaVisionProfile.oled,
          autoRecommended: true,
          options: CinevaVisionOptions.defaults().copyWith(
            enhancedColors: true,
            dynamicContrast: true,
            optimizedHdr: capabilities.optimizedHdrSupported,
          ),
        ),
      CinevaVisionProfile.ultra => CinevaVisionSettings(
          profile: CinevaVisionProfile.ultra,
          autoRecommended: true,
          options: CinevaVisionOptions.defaults().copyWith(
            smartSharpness: capabilities.smartSharpnessSupported,
            enhancedColors: true,
            dynamicContrast: true,
            noiseReduction: capabilities.noiseReductionSupported,
            advancedSmoothness: capabilities.advancedSmoothnessSupported,
            optimizedHdr: capabilities.optimizedHdrSupported,
          ),
        ),
      CinevaVisionProfile.aiBeta => CinevaVisionSettings(
          profile: CinevaVisionProfile.aiBeta,
          autoRecommended: true,
          options: CinevaVisionOptions.defaults().copyWith(
            smartSharpness: capabilities.smartSharpnessSupported,
            enhancedColors: true,
            dynamicContrast: true,
            noiseReduction: capabilities.noiseReductionSupported,
            advancedSmoothness: capabilities.advancedSmoothnessSupported,
            optimizedHdr: capabilities.optimizedHdrSupported,
            aiEnhancement: capabilities.aiEnhancementSupported,
          ),
        ),
      CinevaVisionProfile.custom => CinevaVisionSettings.defaults(),
    };

    return sanitize(base, capabilities);
  }

  CinevaVisionSettings sanitize(CinevaVisionSettings settings, DeviceCapabilities capabilities) {
    final options = settings.options.copyWith(
      smartSharpness: capabilities.smartSharpnessSupported ? settings.options.smartSharpness : false,
      enhancedColors: capabilities.enhancedColorsSupported ? settings.options.enhancedColors : false,
      dynamicContrast: capabilities.dynamicContrastSupported ? settings.options.dynamicContrast : false,
      noiseReduction: capabilities.noiseReductionSupported ? settings.options.noiseReduction : false,
      advancedSmoothness: capabilities.advancedSmoothnessSupported ? settings.options.advancedSmoothness : false,
      optimizedHdr: capabilities.optimizedHdrSupported ? settings.options.optimizedHdr : false,
      aiEnhancement: capabilities.aiEnhancementSupported ? settings.options.aiEnhancement : false,
    );
    return settings.copyWith(options: options);
  }

  CinevaVisionRenderProfile buildRenderProfile({
    required CinevaVisionSettings settings,
    required DeviceCapabilities capabilities,
  }) {
    double saturation = 1;
    double contrast = 1;
    double brightness = 0;
    double warmth = 0;
    double overlayOpacity = 0;
    double shadowBoost = 0;

    switch (settings.profile) {
      case CinevaVisionProfile.standard:
        break;
      case CinevaVisionProfile.cinema:
        saturation += 0.08;
        contrast += 0.06;
        warmth += 0.05;
        overlayOpacity += 0.02;
        break;
      case CinevaVisionProfile.oled:
        saturation += 0.1;
        contrast += 0.12;
        brightness -= 0.02;
        shadowBoost += 0.06;
        break;
      case CinevaVisionProfile.ultra:
        saturation += 0.12;
        contrast += 0.16;
        shadowBoost += 0.08;
        overlayOpacity += 0.04;
        break;
      case CinevaVisionProfile.aiBeta:
        saturation += 0.14;
        contrast += 0.18;
        shadowBoost += 0.1;
        overlayOpacity += 0.05;
        warmth += 0.02;
        break;
      case CinevaVisionProfile.custom:
        break;
    }

    if (settings.options.enhancedColors) saturation += 0.07;
    if (settings.options.dynamicContrast) contrast += 0.1;
    if (settings.options.smartSharpness) overlayOpacity += 0.03;
    if (settings.options.noiseReduction) brightness += 0.01;
    if (settings.options.optimizedHdr) shadowBoost += 0.05;
    if (settings.options.aiEnhancement) {
      contrast += 0.04;
      saturation += 0.04;
    }
    if (settings.options.advancedSmoothness && capabilities.advancedSmoothnessSupported) {
      overlayOpacity += 0.01;
    }

    return CinevaVisionRenderProfile(
      saturation: saturation,
      contrast: contrast,
      brightness: brightness,
      warmth: warmth,
      overlayOpacity: overlayOpacity,
      shadowBoost: shadowBoost,
    );
  }

  DevicePerformanceTier _performanceTier({
    required bool isDesktop,
    required bool isTablet,
    required double refreshRate,
    required double logicalWidth,
    required DisplayTechnology displayTechnology,
  }) {
    if (isDesktop || refreshRate >= 120 || logicalWidth >= 1080 || displayTechnology == DisplayTechnology.oled) {
      return DevicePerformanceTier.premium;
    }
    if (isTablet || refreshRate >= 90 || logicalWidth >= 720) {
      return DevicePerformanceTier.balanced;
    }
    return DevicePerformanceTier.entry;
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  Future<String> _operatingSystemVersion(String platform) async {
    try {
      if (kIsWeb) {
        final web = await _deviceInfo.webBrowserInfo;
        return web.appVersion ?? 'Web';
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final info = await _deviceInfo.androidInfo;
          return 'Android ${info.version.release}';
        case TargetPlatform.iOS:
          final info = await _deviceInfo.iosInfo;
          return '${info.systemName} ${info.systemVersion}';
        case TargetPlatform.macOS:
          final info = await _deviceInfo.macOsInfo;
          return 'macOS ${info.osRelease}';
        case TargetPlatform.windows:
          final info = await _deviceInfo.windowsInfo;
          return 'Windows ${info.displayVersion}';
        case TargetPlatform.linux:
          final info = await _deviceInfo.linuxInfo;
          return info.prettyName;
        case TargetPlatform.fuchsia:
          return 'Fuchsia';
      }
    } catch (_) {
      return platform;
    }
  }

  Future<DisplayTechnology> _inferDisplayTechnology({
    required String platform,
    required double logicalWidth,
    required bool isTv,
  }) async {
    if (platform == 'android') {
      try {
        final info = await _deviceInfo.androidInfo;
        final text = '${info.brand} ${info.model} ${info.device}'.toLowerCase();
        if (text.contains('pixel') || text.contains('galaxy s') || text.contains('galaxy z') || text.contains('oled')) {
          return DisplayTechnology.oled;
        }
      } catch (_) {}
    }

    if (platform == 'ios' || platform == 'macos') {
      return logicalWidth >= 375 ? DisplayTechnology.oled : DisplayTechnology.lcd;
    }

    if (isTv) {
      return DisplayTechnology.oled;
    }

    return DisplayTechnology.lcd;
  }
}
