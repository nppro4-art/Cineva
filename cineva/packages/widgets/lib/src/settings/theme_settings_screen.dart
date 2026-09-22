import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'settings_scaffold.dart';

/// Apparence : sombre (par défaut), clair ou aligné sur le système.
class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeMode current =
        ref.watch(settingsControllerProvider).valueOrNull?.themeMode ??
            AppThemeMode.dark;

    return SettingsScreenScaffold(
      title: 'Apparence',
      subtitle: 'Cineva est conçu pour le mode sombre ; le mode clair reste disponible.',
      children: <Widget>[
        SettingsGroup(
          children: AppThemeMode.values
              .map(
                (AppThemeMode mode) => SettingsOption<AppThemeMode>(
                  value: mode,
                  label: mode.label,
                  subtitle: _description(mode),
                  icon: _icon(mode),
                  selected: mode == current,
                  onSelected: (AppThemeMode value) => ref
                      .read(settingsControllerProvider.notifier)
                      .updateTheme(value),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  static IconData _icon(AppThemeMode mode) => switch (mode) {
        AppThemeMode.dark => Icons.nightlight_round,
        AppThemeMode.light => Icons.light_mode_rounded,
        AppThemeMode.system => Icons.brightness_auto_rounded,
      };

  static String _description(AppThemeMode mode) => switch (mode) {
        AppThemeMode.dark => 'Noir profond, surfaces étagées, accents dorés.',
        AppThemeMode.light => 'Fond clair pour un usage en pleine journée.',
        AppThemeMode.system => 'Suit le réglage de votre appareil.',
      };
}
