import 'package:cineva_models/cineva_models.dart';

abstract interface class AppSettingsRepository {
  Future<AppSettingsModel> loadSettings();

  Future<AppSettingsModel> saveSettings(AppSettingsModel settings);
}
