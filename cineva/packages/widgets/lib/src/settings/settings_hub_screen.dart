import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../audio/audio_engine_controller.dart';
import '../vision/vision_controller.dart';
import 'settings_scaffold.dart';

/// Hub des paramètres Cineva.
///
/// Chaque entrée affiche l'état réellement persisté (langue, thème, qualité,
/// notifications, confidentialité, Cineva Vision, moteur audio).
class SettingsHubScreen extends ConsumerWidget {
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppSettingsModel> settingsAsync =
        ref.watch(settingsControllerProvider);
    final AudioEngineUiState audio = ref.watch(audioEngineControllerProvider);
    final VisionState vision = ref.watch(visionControllerProvider);

    return SettingsScreenScaffold(
      title: 'Paramètres',
      subtitle: 'Lecture, application et compte.',
      onRefresh: () => ref.read(settingsControllerProvider.notifier).load(),
      children: settingsAsync.when(
        loading: () => <Widget>[
          ...List<Widget>.generate(
            6,
            (int index) => const Padding(
              padding: EdgeInsets.only(bottom: CinevaSpacing.sm),
              child: CinevaSkeleton(height: 54),
            ),
          ),
        ],
        error: (Object error, StackTrace stackTrace) => <Widget>[
          CinevaStatusBanner(
            title: 'Paramètres indisponibles',
            message: error.toString(),
            tone: CinevaBannerTone.error,
          ),
        ],
        data: (AppSettingsModel settings) => <Widget>[
          const SettingsGroupHeader(title: 'Lecture'),
          SettingsGroup(
            children: <Widget>[
              CinevaListTile(
                icon: Icons.tune_rounded,
                title: 'Audio & Vidéo',
                subtitle: 'Qualité ${settings.videoQuality.toUpperCase()} · sous-titres '
                    '${settings.subtitlesEnabled ? 'activés' : 'désactivés'}',
                onTap: () => context.push('/settings/audio-video'),
              ),
              const CinevaHairline(indent: 52),
              CinevaListTile(
                icon: Icons.graphic_eq_rounded,
                title: 'Cineva Audio',
                subtitle: audio.backendAvailable
                    ? '${audio.settings.profile.label} · moteur '
                        '${audio.settings.enabled ? 'activé' : 'désactivé'}'
                    : 'Moteur indisponible sur cet appareil',
                onTap: () => context.push('/settings/audio-video'),
              ),
              const CinevaHairline(indent: 52),
              CinevaListTile(
                icon: Icons.auto_awesome_rounded,
                title: 'Cineva Vision',
                subtitle: vision.settings?.profile.label ??
                    settings.visionSettings.profile.label,
                onTap: () => context.push('/settings/cineva-vision'),
              ),
            ],
          ),
          const SettingsGroupHeader(title: 'Application'),
          SettingsGroup(
            children: <Widget>[
              CinevaListTile(
                icon: Icons.translate_rounded,
                title: 'Langue',
                subtitle: settings.language.toUpperCase(),
                onTap: () => context.push('/settings/language'),
              ),
              const CinevaHairline(indent: 52),
              CinevaListTile(
                icon: Icons.palette_outlined,
                title: 'Apparence',
                subtitle: settings.themeMode.label,
                onTap: () => context.push('/settings/theme'),
              ),
              const CinevaHairline(indent: 52),
              CinevaListTile(
                icon: Icons.notifications_active_outlined,
                title: 'Notifications',
                subtitle: settings.notificationPreferences.enabled
                    ? 'Activées'
                    : 'Désactivées',
                onTap: () => context.push('/settings/notifications'),
              ),
              const CinevaHairline(indent: 52),
              CinevaListTile(
                icon: Icons.verified_user_outlined,
                title: 'Confidentialité',
                subtitle: settings.privacyPreferences.analyticsEnabled
                    ? 'Analyses activées'
                    : 'Analyses désactivées',
                onTap: () => context.push('/settings/privacy'),
              ),
            ],
          ),
          const SettingsGroupHeader(title: 'Compte'),
          SettingsGroup(
            children: <Widget>[
              CinevaListTile(
                icon: Icons.person_outline_rounded,
                title: 'Profil',
                onTap: () => context.push('/profile'),
              ),
              const CinevaHairline(indent: 52),
              CinevaListTile(
                icon: Icons.devices_other_outlined,
                title: 'Appareils',
                onTap: () => context.push('/account/devices'),
              ),
              const CinevaHairline(indent: 52),
              CinevaListTile(
                icon: Icons.help_outline_rounded,
                title: 'Aide & contact',
                onTap: () => context.push('/settings/help'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
