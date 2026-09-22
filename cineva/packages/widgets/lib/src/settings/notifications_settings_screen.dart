import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'settings_controller.dart';
import 'settings_scaffold.dart';

/// Notifications : interrupteur maître puis catégories.
class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettingsModel settings =
        ref.watch(settingsControllerProvider).valueOrNull ??
            AppSettingsModel.defaults();
    final NotificationPreferencesModel prefs = settings.notificationPreferences;
    final SettingsController controller =
        ref.read(settingsControllerProvider.notifier);

    return SettingsScreenScaffold(
      title: 'Notifications',
      subtitle: 'Choisissez ce que Cineva peut vous signaler.',
      children: <Widget>[
        SettingsGroup(
          children: <Widget>[
            CinevaSwitchTile(
              icon: Icons.notifications_active_outlined,
              title: 'Notifications activées',
              value: prefs.enabled,
              onChanged: (bool value) =>
                  controller.updateNotifications(prefs.copyWith(enabled: value)),
            ),
            const CinevaHairline(indent: 52),
            CinevaSwitchTile(
              icon: Icons.movie_filter_outlined,
              title: 'Nouveaux contenus',
              subtitle: 'Ajouts au catalogue et sorties',
              value: prefs.newContent,
              enabled: prefs.enabled,
              onChanged: (bool value) =>
                  controller.updateNotifications(prefs.copyWith(newContent: value)),
            ),
            const CinevaHairline(indent: 52),
            CinevaSwitchTile(
              icon: Icons.download_done_rounded,
              title: 'Téléchargements terminés',
              subtitle: 'Dès qu’un titre est disponible hors ligne',
              value: prefs.downloads,
              enabled: prefs.enabled,
              onChanged: (bool value) =>
                  controller.updateNotifications(prefs.copyWith(downloads: value)),
            ),
            const CinevaHairline(indent: 52),
            CinevaSwitchTile(
              icon: Icons.calendar_month_rounded,
              title: 'Rappels d’abonnement',
              subtitle: 'Échéance et moyens de paiement',
              value: prefs.subscriptionReminders,
              enabled: prefs.enabled,
              onChanged: (bool value) => controller
                  .updateNotifications(prefs.copyWith(subscriptionReminders: value)),
            ),
            const CinevaHairline(indent: 52),
            CinevaSwitchTile(
              icon: Icons.auto_awesome_rounded,
              title: 'Actualités produit',
              subtitle: 'Nouveautés Cineva Vision et Cineva Audio',
              value: prefs.productUpdates,
              enabled: prefs.enabled,
              onChanged: (bool value) =>
                  controller.updateNotifications(prefs.copyWith(productUpdates: value)),
            ),
          ],
        ),
      ],
    );
  }
}
