import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull ?? AppSettingsModel.defaults();
    final prefs = settings.notificationPreferences;
    final controller = ref.read(settingsControllerProvider.notifier);

    Widget tile({required String title, required bool value, required ValueChanged<bool> onChanged}) {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        value: value,
        onChanged: prefs.enabled ? onChanged : null,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: CinevaScaffoldContainer(
        child: CinevaGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notifications activées'),
                value: prefs.enabled,
                onChanged: (value) => controller.updateNotifications(prefs.copyWith(enabled: value)),
              ),
              tile(
                title: 'Nouveaux contenus',
                value: prefs.newContent,
                onChanged: (value) => controller.updateNotifications(prefs.copyWith(newContent: value)),
              ),
              tile(
                title: 'Téléchargements terminés',
                value: prefs.downloads,
                onChanged: (value) => controller.updateNotifications(prefs.copyWith(downloads: value)),
              ),
              tile(
                title: 'Rappels d’abonnement',
                value: prefs.subscriptionReminders,
                onChanged: (value) => controller.updateNotifications(prefs.copyWith(subscriptionReminders: value)),
              ),
              tile(
                title: 'Actualités produit',
                value: prefs.productUpdates,
                onChanged: (value) => controller.updateNotifications(prefs.copyWith(productUpdates: value)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
