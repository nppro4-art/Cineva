import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalPreferencesService {
  const LocalPreferencesService();

  static const _deviceKey = 'cineva.device_fingerprint';
  static const _lastEmailKey = 'cineva.last_email';
  static const _searchHistoryKey = 'cineva.search_history';
  static const _favoriteIdsKey = 'cineva.favorite_ids';
  static const _playbackProgressKey = 'cineva.playback_progress';
  static const _downloadsKey = 'cineva.downloads';
  static const _visionSettingsKey = 'cineva.vision_settings';
  static const _appSettingsKey = 'cineva.app_settings';
  static const _activeProfileKey = 'cineva.active_member_profile';

  Future<String?> readDeviceFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceKey);
  }

  Future<void> saveDeviceFingerprint(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceKey, value);
  }

  Future<String?> readLastEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastEmailKey);
  }

  Future<void> saveLastEmail(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastEmailKey, value);
  }

  Future<List<String>> readSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_searchHistoryKey) ?? const <String>[];
  }

  Future<void> saveSearchHistory(List<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_searchHistoryKey, values);
  }

  Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchHistoryKey);
  }

  /// Favoris en cache. [profileId] isole le cache d'un profil membre : sans
  /// profil (ancienne version, ou base non migrée), la clé historique est
  /// conservée telle quelle — aucune donnée existante n'est déplacée.
  Future<Set<String>> readFavoriteIds({String? profileId}) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_scopedKey(_favoriteIdsKey, profileId)) ?? const <String>[]).toSet();
  }

  Future<void> saveFavoriteIds(Set<String> values, {String? profileId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_scopedKey(_favoriteIdsKey, profileId), values.toList());
  }

  /// Profil membre actif sur cet appareil (null = aucun profil choisi).
  Future<String?> readActiveMemberProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeProfileKey);
  }

  Future<void> saveActiveMemberProfileId(String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    if (profileId == null || profileId.isEmpty) {
      await prefs.remove(_activeProfileKey);
      return;
    }
    await prefs.setString(_activeProfileKey, profileId);
  }

  String _scopedKey(String key, String? profileId) {
    if (profileId == null || profileId.isEmpty) return key;
    return '$key.$profileId';
  }

  Future<Map<String, dynamic>> readPlaybackProgressMap({String? profileId}) async {
    return _readJsonMap(_scopedKey(_playbackProgressKey, profileId));
  }

  Future<void> savePlaybackProgressMap(Map<String, dynamic> value, {String? profileId}) async {
    await _writeJsonMap(_scopedKey(_playbackProgressKey, profileId), value);
  }

  Future<Map<String, dynamic>> readDownloadsMap() async {
    return _readJsonMap(_downloadsKey);
  }

  Future<void> saveDownloadsMap(Map<String, dynamic> value) async {
    await _writeJsonMap(_downloadsKey, value);
  }

  Future<Map<String, dynamic>> readVisionSettingsMap() async {
    return _readJsonMap(_visionSettingsKey);
  }

  Future<void> saveVisionSettingsMap(Map<String, dynamic> value) async {
    await _writeJsonMap(_visionSettingsKey, value);
  }

  Future<Map<String, dynamic>> readAppSettingsMap() async {
    return _readJsonMap(_appSettingsKey);
  }

  Future<void> saveAppSettingsMap(Map<String, dynamic> value) async {
    await _writeJsonMap(_appSettingsKey, value);
  }

  Future<Map<String, dynamic>> _readJsonMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  Future<void> _writeJsonMap(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }
}
