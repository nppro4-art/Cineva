import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_services/src/vision/cineva_vision_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = CinevaVisionService();

  test('recommendedSettings enables advanced options on premium oled device', () {
    const capabilities = DeviceCapabilities(
      platform: 'android',
      operatingSystemVersion: 'Android 15',
      screenWidth: 430,
      screenHeight: 932,
      pixelRatio: 3,
      refreshRate: 120,
      displayTechnology: DisplayTechnology.oled,
      performanceTier: DevicePerformanceTier.premium,
      isTv: false,
      isDesktop: false,
      isTablet: false,
      smartSharpnessSupported: true,
      enhancedColorsSupported: true,
      dynamicContrastSupported: true,
      noiseReductionSupported: true,
      advancedSmoothnessSupported: true,
      optimizedHdrSupported: true,
      aiEnhancementSupported: true,
    );

    final settings = service.recommendedSettings(capabilities);

    expect(settings.profile, CinevaVisionProfile.oled);
    expect(settings.options.enhancedColors, isTrue);
    expect(settings.options.dynamicContrast, isTrue);
  });

  test('sanitize disables unsupported toggles', () {
    const capabilities = DeviceCapabilities(
      platform: 'android',
      operatingSystemVersion: 'Android 12',
      screenWidth: 360,
      screenHeight: 740,
      pixelRatio: 2,
      refreshRate: 60,
      displayTechnology: DisplayTechnology.lcd,
      performanceTier: DevicePerformanceTier.entry,
      isTv: false,
      isDesktop: false,
      isTablet: false,
      smartSharpnessSupported: false,
      enhancedColorsSupported: true,
      dynamicContrastSupported: true,
      noiseReductionSupported: false,
      advancedSmoothnessSupported: false,
      optimizedHdrSupported: false,
      aiEnhancementSupported: false,
    );

    final sanitized = service.sanitize(
      CinevaVisionSettings(
        profile: CinevaVisionProfile.aiBeta,
        autoRecommended: false,
        options: const CinevaVisionOptions(
          smartSharpness: true,
          enhancedColors: true,
          dynamicContrast: true,
          noiseReduction: true,
          advancedSmoothness: true,
          optimizedHdr: true,
          aiEnhancement: true,
        ),
      ),
      capabilities,
    );

    expect(sanitized.options.smartSharpness, isFalse);
    expect(sanitized.options.noiseReduction, isFalse);
    expect(sanitized.options.optimizedHdr, isFalse);
    expect(sanitized.options.enhancedColors, isTrue);
  });
}
