import 'package:cineva_models/cineva_models.dart';

Map<String, dynamic>? asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<String> asStringList(dynamic value, {List<String> fallback = const <String>[]}) {
  if (value is List) return value.map((entry) => '$entry').toList();
  return fallback;
}

List<String> asSubtitleLanguages(dynamic value) {
  if (value is List) {
    return value.map((entry) {
      if (entry is String) return entry;
      if (entry is Map) {
        final map = Map<String, dynamic>.from(entry);
        return map['label'] as String? ?? map['language'] as String? ?? 'Sous-titre';
      }
      return '$entry';
    }).toList();
  }
  return const <String>[];
}

DateTime? asDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

AppSettingsModel mapAppSettings(Map<String, dynamic> row) {
  final darkMode = row['dark_mode'] as bool? ?? true;
  return AppSettingsModel(
    language: row['preferred_language'] as String? ?? 'fr',
    videoQuality: row['video_quality'] as String? ?? 'auto',
    subtitlesEnabled: row['subtitles_enabled'] as bool? ?? true,
    autoplayEnabled: row['autoplay_enabled'] as bool? ?? true,
    notificationsEnabled: row['notifications_enabled'] as bool? ?? true,
    darkMode: darkMode,
    themeMode: _themeModeFromName(row['theme_mode'] as String?) ??
        (darkMode ? AppThemeMode.dark : AppThemeMode.light),
    notificationPreferences: NotificationPreferencesModel.fromJson(asJsonMap(row['notification_preferences'])),
    privacyPreferences: PrivacyPreferencesModel.fromJson(asJsonMap(row['privacy_settings'])),
    visionSettings: CinevaVisionSettings.fromJson(
      profileName: row['vision_profile'] as String?,
      optionsJson: asJsonMap(row['vision_options']),
      autoRecommended: asJsonMap(row['vision_options'])?['autoRecommended'] as bool?,
    ),
  );
}

AppUser mapAppUser(Map<String, dynamic> row) {
  return AppUser(
    id: row['id'] as String,
    email: row['email'] as String? ?? '',
    fullName: row['full_name'] as String? ?? 'Utilisateur Cineva',
    role: row['role'] as String? ?? 'user',
    status: row['status'] as String? ?? 'active',
    avatarPath: row['avatar_path'] as String?,
    subscriptionExpiresAt: asDateTime(row['subscription_expires_at']),
    subscriptionSuspended: row['subscription_suspended'] as bool? ?? false,
    settings: mapAppSettings(row),
  );
}

DeviceModel mapDevice(Map<String, dynamic> row) {
  return DeviceModel(
    id: row['id'] as String,
    deviceFingerprint: row['device_fingerprint'] as String? ?? '',
    platform: row['platform'] as String? ?? 'unknown',
    isActive: row['is_active'] as bool? ?? true,
    deviceName: row['device_name'] as String?,
    appVersion: row['app_version'] as String?,
    lastSeenAt: asDateTime(row['last_seen_at']),
  );
}

AppThemeMode? _themeModeFromName(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  for (final value in AppThemeMode.values) {
    if (value.name == raw) {
      return value;
    }
  }
  return null;
}
