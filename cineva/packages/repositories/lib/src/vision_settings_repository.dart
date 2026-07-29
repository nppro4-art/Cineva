import 'package:cineva_models/cineva_models.dart';

abstract interface class VisionSettingsRepository {
  Future<CinevaVisionSettings> loadVisionSettings();

  Future<void> saveVisionSettings(CinevaVisionSettings settings);
}
