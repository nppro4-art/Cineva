import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  static const options = <MapEntry<String, String>>[
    MapEntry('fr', 'Français'),
    MapEntry('en', 'English'),
    MapEntry('es', 'Español'),
    MapEntry('ar', 'العربية'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final current = settings?.language ?? 'fr';

    return Scaffold(
      appBar: AppBar(title: const Text('Langue')),
      body: CinevaScaffoldContainer(
        child: ListView(
          children: options
              .map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
                  child: RadioListTile<String>(
                    value: option.key,
                    groupValue: current,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(settingsControllerProvider.notifier).updateLanguage(value);
                      }
                    },
                    title: Text(option.value),
                    subtitle: Text(option.key.toUpperCase()),
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
