import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:cineva_widgets/src/settings/settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SettingsController updates language and theme', () async {
    final repository = _FakeAppSettingsRepository();
    final controller = SettingsController(repository);

    await Future<void>.delayed(Duration.zero);
    await controller.updateLanguage('en');
    await controller.updateTheme(AppThemeMode.light);

    final state = controller.state.valueOrNull!;
    expect(state.language, 'en');
    expect(state.themeMode, AppThemeMode.light);
  });

  test('SettingsController updates audio settings and persists them', () async {
    final repository = _FakeAppSettingsRepository();
    final controller = SettingsController(repository);

    await Future<void>.delayed(Duration.zero);
    await controller.updateAudioSettings(
      CinevaAudioSettings.defaults().copyWith(
        profile: CinevaAudioProfile.night,
        dialogueAmount: 80,
        output: CinevaAudioOutput.headphone,
      ),
    );

    final state = controller.state.valueOrNull!;
    expect(state.audioSettings.profile, CinevaAudioProfile.night);
    expect(state.audioSettings.dialogueAmount, 80);
    expect(state.audioSettings.output, CinevaAudioOutput.headphone);
    // Persisté via le repository.
    expect(repository.settings.audioSettings.profile, CinevaAudioProfile.night);
    // Les autres réglages sont préservés.
    expect(state.language, 'fr');
  });
}

class _FakeAppSettingsRepository implements AppSettingsRepository {
  AppSettingsModel settings = AppSettingsModel.defaults();

  @override
  Future<AppSettingsModel> loadSettings() async => settings;

  @override
  Future<AppSettingsModel> saveSettings(AppSettingsModel next) async {
    settings = next;
    return settings;
  }
}
