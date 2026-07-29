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

  Future<Set<String>> readFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favoriteIdsKey) ?? const <String>[]).toSet();
  }

  Future<void> saveFavoriteIds(Set<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteIdsKey, values.toList());
  }

  Future<Map<String, dynamic>> readPlaybackProgressMap() async {
    return _readJsonMap(_playbackProgressKey);
  }

  Future<void> savePlaybackProgressMap(Map<String, dynamic> value) async {
    await _writeJsonMap(_playbackProgressKey, value);
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
