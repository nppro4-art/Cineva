import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsController extends StateNotifier<AsyncValue<AppSettingsModel>> {
  SettingsController(this._repository) : super(const AsyncValue.loading()) {
    load();
  }

  final AppSettingsRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.loadSettings);
  }

  Future<void> update(AppSettingsModel settings) async {
    final previous = state.valueOrNull ?? AppSettingsModel.defaults();
    state = AsyncValue.data(settings);
    try {
      final saved = await _repository.saveSettings(settings);
      state = AsyncValue.data(saved);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      state = AsyncValue.data(previous);
    }
  }

  Future<void> updateLanguage(String language) async {
    final current = state.valueOrNull ?? AppSettingsModel.defaults();
    await update(current.copyWith(language: language));
  }

  Future<void> updateTheme(AppThemeMode themeMode) async {
    final current = state.valueOrNull ?? AppSettingsModel.defaults();
    await update(
      current.copyWith(
        themeMode: themeMode,
        darkMode: themeMode == AppThemeMode.dark,
      ),
    );
  }

  Future<void> updateVideoQuality(String quality) async {
    final current = state.valueOrNull ?? AppSettingsModel.defaults();
    await update(current.copyWith(videoQuality: quality));
  }

  Future<void> updateSubtitles(bool enabled) async {
    final current = state.valueOrNull ?? AppSettingsModel.defaults();
    await update(current.copyWith(subtitlesEnabled: enabled));
  }

  Future<void> updateAutoplay(bool enabled) async {
    final current = state.valueOrNull ?? AppSettingsModel.defaults();
    await update(current.copyWith(autoplayEnabled: enabled));
  }

  Future<void> updateNotifications(NotificationPreferencesModel prefs) async {
    final current = state.valueOrNull ?? AppSettingsModel.defaults();
    await update(
      current.copyWith(
        notificationsEnabled: prefs.enabled,
        notificationPreferences: prefs,
      ),
    );
  }

  Future<void> updatePrivacy(PrivacyPreferencesModel prefs) async {
    final current = state.valueOrNull ?? AppSettingsModel.defaults();
    await update(current.copyWith(privacyPreferences: prefs));
  }

  Future<void> updateAudioSettings(CinevaAudioSettings audio) async {
    final current = state.valueOrNull ?? AppSettingsModel.defaults();
    await update(current.copyWith(audioSettings: audio));
  }
}
