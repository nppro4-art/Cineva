import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull ?? AppSettingsModel.defaults();
    final prefs = settings.privacyPreferences;
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Confidentialité')),
      body: CinevaScaffoldContainer(
        child: CinevaGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recommandations personnalisées'),
                subtitle: const Text('Utiliser votre historique de visionnage pour affiner les suggestions.'),
                value: prefs.personalizedRecommendations,
                onChanged: (value) => controller.updatePrivacy(prefs.copyWith(personalizedRecommendations: value)),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Synchroniser l’historique entre appareils'),
                subtitle: const Text('Conserver la progression et l’historique sur tous vos appareils autorisés.'),
                value: prefs.shareWatchHistoryAcrossDevices,
                onChanged: (value) => controller.updatePrivacy(prefs.copyWith(shareWatchHistoryAcrossDevices: value)),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Analyses anonymisées'),
                subtitle: const Text('Aider à améliorer Cineva Vision, la lecture et les performances globales.'),
                value: prefs.analyticsEnabled,
                onChanged: (value) => controller.updatePrivacy(prefs.copyWith(analyticsEnabled: value)),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Profil public'),
                subtitle: const Text('Conserver votre profil strictement privé par défaut.'),
                value: prefs.publicProfile,
                onChanged: (value) => controller.updatePrivacy(prefs.copyWith(publicProfile: value)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
