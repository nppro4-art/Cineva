import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'settings_controller.dart';
import 'settings_scaffold.dart';

/// Confidentialité : recommandations, historique, analyses, profil public.
class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettingsModel settings =
        ref.watch(settingsControllerProvider).valueOrNull ??
            AppSettingsModel.defaults();
    final PrivacyPreferencesModel prefs = settings.privacyPreferences;
    final SettingsController controller =
        ref.read(settingsControllerProvider.notifier);

    return SettingsScreenScaffold(
      title: 'Confidentialité',
      subtitle: 'Vos données de lecture restent sous votre contrôle.',
      children: <Widget>[
        SettingsGroup(
          children: <Widget>[
            CinevaSwitchTile(
              icon: Icons.auto_awesome_rounded,
              title: 'Recommandations personnalisées',
              subtitle:
                  'Utiliser votre historique de visionnage pour affiner les suggestions.',
              value: prefs.personalizedRecommendations,
              onChanged: (bool value) => controller
                  .updatePrivacy(prefs.copyWith(personalizedRecommendations: value)),
            ),
            const CinevaHairline(indent: 52),
            CinevaSwitchTile(
              icon: Icons.sync_rounded,
              title: 'Synchroniser l’historique entre appareils',
              subtitle:
                  'Conserver la progression et l’historique sur tous vos appareils autorisés.',
              value: prefs.shareWatchHistoryAcrossDevices,
              onChanged: (bool value) => controller.updatePrivacy(
                prefs.copyWith(shareWatchHistoryAcrossDevices: value),
              ),
            ),
            const CinevaHairline(indent: 52),
            CinevaSwitchTile(
              icon: Icons.insights_rounded,
              title: 'Analyses anonymisées',
              subtitle:
                  'Aider à améliorer Cineva Vision, la lecture et les performances globales.',
              value: prefs.analyticsEnabled,
              onChanged: (bool value) =>
                  controller.updatePrivacy(prefs.copyWith(analyticsEnabled: value)),
            ),
            const CinevaHairline(indent: 52),
            CinevaSwitchTile(
              icon: Icons.person_outline_rounded,
              title: 'Profil public',
              subtitle: 'Votre profil reste strictement privé par défaut.',
              value: prefs.publicProfile,
              onChanged: (bool value) =>
                  controller.updatePrivacy(prefs.copyWith(publicProfile: value)),
            ),
          ],
        ),
      ],
    );
  }
}
