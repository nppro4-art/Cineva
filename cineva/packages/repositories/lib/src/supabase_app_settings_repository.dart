import 'dart:convert';

import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_settings_repository.dart';
import 'supabase_support.dart';

class SupabaseAppSettingsRepository implements AppSettingsRepository {
  SupabaseAppSettingsRepository({
    required BackendService backendService,
    required LocalPreferencesService localPreferencesService,
  })  : _backendService = backendService,
        _localPreferencesService = localPreferencesService;

  final BackendService _backendService;
  final LocalPreferencesService _localPreferencesService;

  @override
  Future<AppSettingsModel> loadSettings() async {
    final local = await _loadLocal();
    final client = await _safeClient();
    if (client == null) return local;

    try {
      final row = await client
          .from(SupabaseConstants.profilesTable)
          .select()
          .eq('id', client.auth.currentUser!.id)
          .maybeSingle();
      if (row == null) return local;
      final settings = _fromProfileRow(Map<String, dynamic>.from(row as Map), fallback: local);
      await _saveLocal(settings);
      return settings;
    } catch (_) {
      return local;
    }
  }

  @override
  Future<AppSettingsModel> saveSettings(AppSettingsModel settings) async {
    await _saveLocal(settings);
    final client = await _safeClient();
    if (client == null) return settings;

    try {
      await client.from(SupabaseConstants.profilesTable).update(<String, dynamic>{
        'preferred_language': settings.language,
        'video_quality': settings.videoQuality,
        'subtitles_enabled': settings.subtitlesEnabled,
        'autoplay_enabled': settings.autoplayEnabled,
        'notifications_enabled': settings.notificationsEnabled,
        'dark_mode': settings.themeMode == AppThemeMode.dark,
        'theme_mode': settings.themeMode.name,
        'privacy_settings': settings.privacyPreferences.toJson(),
        'notification_preferences': settings.notificationPreferences.toJson(),
      }).eq('id', client.auth.currentUser!.id);
    } catch (_) {}

    return settings;
  }

  AppSettingsModel _fromProfileRow(Map<String, dynamic> row, {required AppSettingsModel fallback}) {
    final themeMode = _themeModeFromName(row['theme_mode'] as String?) ??
        ((row['dark_mode'] as bool? ?? fallback.darkMode) ? AppThemeMode.dark : AppThemeMode.light);

    return fallback.copyWith(
      language: row['preferred_language'] as String? ?? fallback.language,
      videoQuality: row['video_quality'] as String? ?? fallback.videoQuality,
      subtitlesEnabled: row['subtitles_enabled'] as bool? ?? fallback.subtitlesEnabled,
      autoplayEnabled: row['autoplay_enabled'] as bool? ?? fallback.autoplayEnabled,
      notificationsEnabled: row['notifications_enabled'] as bool? ?? fallback.notificationsEnabled,
      darkMode: row['dark_mode'] as bool? ?? fallback.darkMode,
      themeMode: themeMode,
      notificationPreferences: NotificationPreferencesModel.fromJson(_jsonMap(row['notification_preferences'])),
      privacyPreferences: PrivacyPreferencesModel.fromJson(_jsonMap(row['privacy_settings'])),
    );
  }

  Future<AppSettingsModel> _loadLocal() async {
    final map = await _localPreferencesService.readAppSettingsMap();
    if (map.isEmpty) return AppSettingsModel.defaults();
    return AppSettingsModel.defaults().copyWith(
      language: map['language'] as String? ?? 'fr',
      videoQuality: map['videoQuality'] as String? ?? 'auto',
      subtitlesEnabled: map['subtitlesEnabled'] as bool? ?? true,
      autoplayEnabled: map['autoplayEnabled'] as bool? ?? true,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      darkMode: map['darkMode'] as bool? ?? true,
      themeMode: _themeModeFromName(map['themeMode'] as String?) ?? AppThemeMode.dark,
      notificationPreferences: NotificationPreferencesModel.fromJson(_jsonMap(map['notificationPreferences'])),
      privacyPreferences: PrivacyPreferencesModel.fromJson(_jsonMap(map['privacyPreferences'])),
      // Note : visionSettings vit dans son propre dépôt (clé locale dédiée) ;
      // on ne le restaure pas depuis ce blob.
      audioSettings: CinevaAudioSettings.fromJson(_jsonMap(map['audioSettings'])),
    );
  }

  Future<void> _saveLocal(AppSettingsModel settings) async {
    await _localPreferencesService.saveAppSettingsMap(settings.toJson());
  }

  Map<String, dynamic>? _jsonMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return null;
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

  Future<SupabaseClient?> _safeClient() async {
    final state = await _backendService.ensureInitialized();
    final client = _backendService.client;
    if (!state.supabaseReady || client == null || client.auth.currentUser == null) return null;
    return client;
  }
}
