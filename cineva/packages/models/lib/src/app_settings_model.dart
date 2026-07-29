import 'package:equatable/equatable.dart';

import 'cineva_vision_models.dart';
import 'user_preferences_models.dart';

class AppSettingsModel extends Equatable {
  const AppSettingsModel({
    required this.language,
    required this.videoQuality,
    required this.subtitlesEnabled,
    required this.autoplayEnabled,
    required this.notificationsEnabled,
    required this.darkMode,
    required this.themeMode,
    required this.notificationPreferences,
    required this.privacyPreferences,
    required this.visionSettings,
  });

  factory AppSettingsModel.defaults() {
    return AppSettingsModel(
      language: 'fr',
      videoQuality: 'auto',
      subtitlesEnabled: true,
      autoplayEnabled: true,
      notificationsEnabled: true,
      darkMode: true,
      themeMode: AppThemeMode.dark,
      notificationPreferences: NotificationPreferencesModel.defaults(),
      privacyPreferences: PrivacyPreferencesModel.defaults(),
      visionSettings: CinevaVisionSettings.defaults(),
    );
  }

  final String language;
  final String videoQuality;
  final bool subtitlesEnabled;
  final bool autoplayEnabled;
  final bool notificationsEnabled;
  final bool darkMode;
  final AppThemeMode themeMode;
  final NotificationPreferencesModel notificationPreferences;
  final PrivacyPreferencesModel privacyPreferences;
  final CinevaVisionSettings visionSettings;

  AppSettingsModel copyWith({
    String? language,
    String? videoQuality,
    bool? subtitlesEnabled,
    bool? autoplayEnabled,
    bool? notificationsEnabled,
    bool? darkMode,
    AppThemeMode? themeMode,
    NotificationPreferencesModel? notificationPreferences,
    PrivacyPreferencesModel? privacyPreferences,
    CinevaVisionSettings? visionSettings,
  }) {
    return AppSettingsModel(
      language: language ?? this.language,
      videoQuality: videoQuality ?? this.videoQuality,
      subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
      autoplayEnabled: autoplayEnabled ?? this.autoplayEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkMode: darkMode ?? this.darkMode,
      themeMode: themeMode ?? this.themeMode,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
      privacyPreferences: privacyPreferences ?? this.privacyPreferences,
      visionSettings: visionSettings ?? this.visionSettings,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'language': language,
      'videoQuality': videoQuality,
      'subtitlesEnabled': subtitlesEnabled,
      'autoplayEnabled': autoplayEnabled,
      'notificationsEnabled': notificationsEnabled,
      'darkMode': darkMode,
      'themeMode': themeMode.name,
      'notificationPreferences': notificationPreferences.toJson(),
      'privacyPreferences': privacyPreferences.toJson(),
      'visionSettings': visionSettings.toJson(),
    };
  }

  @override
  List<Object?> get props => <Object?>[
        language,
        videoQuality,
        subtitlesEnabled,
        autoplayEnabled,
        notificationsEnabled,
        darkMode,
        themeMode,
        notificationPreferences,
        privacyPreferences,
        visionSettings,
      ];
}
