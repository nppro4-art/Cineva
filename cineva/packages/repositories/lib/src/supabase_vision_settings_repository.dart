import 'dart:convert';

import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'vision_settings_repository.dart';

class SupabaseVisionSettingsRepository implements VisionSettingsRepository {
  SupabaseVisionSettingsRepository({
    required BackendService backendService,
    required LocalPreferencesService localPreferencesService,
  })  : _backendService = backendService,
        _localPreferencesService = localPreferencesService;

  final BackendService _backendService;
  final LocalPreferencesService _localPreferencesService;

  @override
  Future<CinevaVisionSettings> loadVisionSettings() async {
    final local = await _loadLocal();
    final client = await _safeClient();
    if (client == null) return local;

    try {
      final row = await client
          .from(SupabaseConstants.profilesTable)
          .select('vision_profile, vision_options')
          .eq('id', client.auth.currentUser!.id)
          .maybeSingle();
      if (row == null) return local;

      final optionsJson = row['vision_options'];
      final settings = CinevaVisionSettings.fromJson(
        profileName: row['vision_profile'] as String?,
        optionsJson: optionsJson is Map<String, dynamic>
            ? optionsJson
            : optionsJson is String
                ? Map<String, dynamic>.from(jsonDecode(optionsJson) as Map)
                : null,
        autoRecommended: optionsJson is Map<String, dynamic> ? optionsJson['autoRecommended'] as bool? : null,
      ).copyWith(
        autoRecommended: optionsJson is Map<String, dynamic>
            ? optionsJson['autoRecommended'] as bool? ?? true
            : local.autoRecommended,
      );

      await _saveLocal(settings);
      return settings;
    } catch (_) {
      return local;
    }
  }

  @override
  Future<void> saveVisionSettings(CinevaVisionSettings settings) async {
    await _saveLocal(settings);

    final client = await _safeClient();
    if (client == null) return;

    try {
      final payload = settings.toJson();
      await client.from(SupabaseConstants.profilesTable).update(<String, dynamic>{
        'vision_profile': settings.profile.name,
        'vision_options': <String, dynamic>{
          ...Map<String, dynamic>.from(payload['options'] as Map<String, dynamic>),
          'autoRecommended': settings.autoRecommended,
        },
      }).eq('id', client.auth.currentUser!.id);
    } catch (_) {}
  }

  Future<CinevaVisionSettings> _loadLocal() async {
    final map = await _localPreferencesService.readVisionSettingsMap();
    return CinevaVisionSettings.fromJson(
      profileName: map['profile'] as String?,
      optionsJson: map['options'] is Map<String, dynamic>
          ? map['options'] as Map<String, dynamic>
          : map['options'] is Map
              ? Map<String, dynamic>.from(map['options'] as Map)
              : null,
      autoRecommended: map['autoRecommended'] as bool?,
    );
  }

  Future<void> _saveLocal(CinevaVisionSettings settings) async {
    await _localPreferencesService.saveVisionSettingsMap(settings.toJson());
  }

  Future<SupabaseClient?> _safeClient() async {
    final state = await _backendService.ensureInitialized();
    final client = _backendService.client;
    if (!state.supabaseReady || client == null || client.auth.currentUser == null) return null;
    return client;
  }
}
