import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/src/supabase_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mapAppSettings hydrates theme and privacy preferences', () {
    final settings = mapAppSettings(<String, dynamic>{
      'preferred_language': 'en',
      'video_quality': '1080p',
      'subtitles_enabled': false,
      'autoplay_enabled': false,
      'notifications_enabled': true,
      'dark_mode': false,
      'theme_mode': 'light',
      'notification_preferences': <String, dynamic>{'enabled': true, 'downloads': false},
      'privacy_settings': <String, dynamic>{'analyticsEnabled': false},
      'vision_profile': 'oled',
      'vision_options': <String, dynamic>{'enhancedColors': true, 'autoRecommended': false},
    });

    expect(settings.language, 'en');
    expect(settings.themeMode, AppThemeMode.light);
    expect(settings.notificationPreferences.downloads, isFalse);
    expect(settings.privacyPreferences.analyticsEnabled, isFalse);
    expect(settings.visionSettings.profile, CinevaVisionProfile.oled);
  });

  test('asSubtitleLanguages normalizes mixed subtitle payload', () {
    final subtitles = asSubtitleLanguages(<dynamic>[
      'Français',
      <String, dynamic>{'label': 'English'},
    ]);

    expect(subtitles, <String>['Français', 'English']);
  });
}
