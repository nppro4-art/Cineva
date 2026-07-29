import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:cineva_widgets/src/settings/settings_controller.dart';
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
