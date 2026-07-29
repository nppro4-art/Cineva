import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final current = settings?.themeMode ?? AppThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Thème')),
      body: CinevaScaffoldContainer(
        child: ListView(
          children: AppThemeMode.values
              .map(
                (mode) => Padding(
                  padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
                  child: RadioListTile<AppThemeMode>(
                    value: mode,
                    groupValue: current,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(settingsControllerProvider.notifier).updateTheme(value);
                      }
                    },
                    title: Text(mode.label),
                    tileColor: CinevaColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CinevaRadii.medium)),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
