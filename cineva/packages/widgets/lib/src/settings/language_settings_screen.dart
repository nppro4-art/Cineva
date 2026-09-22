import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'settings_scaffold.dart';

/// Langue de l'interface et des métadonnées.
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  static const List<MapEntry<String, String>> options = <MapEntry<String, String>>[
    MapEntry<String, String>('fr', 'Français'),
    MapEntry<String, String>('en', 'English'),
    MapEntry<String, String>('es', 'Español'),
    MapEntry<String, String>('ar', 'العربية'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String current =
        ref.watch(settingsControllerProvider).valueOrNull?.language ?? 'fr';

    return SettingsScreenScaffold(
      title: 'Langue',
      subtitle: 'S’applique à l’interface et aux libellés du catalogue.',
      children: <Widget>[
        SettingsGroup(
          children: options
              .map(
                (MapEntry<String, String> option) => SettingsOption<String>(
                  value: option.key,
                  label: option.value,
                  subtitle: option.key.toUpperCase(),
                  selected: option.key == current,
                  onSelected: (String value) => ref
                      .read(settingsControllerProvider.notifier)
                      .updateLanguage(value),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
