import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';

class SettingsHubScreen extends ConsumerWidget {
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: CinevaScaffoldContainer(
        child: settingsAsync.when(
          loading: () => const CinevaLoadingView(label: 'Chargement des préférences...'),
          error: (error, _) => Center(
            child: CinevaStatusBanner(
              title: 'Paramètres indisponibles',
              message: error.toString(),
              tone: CinevaBannerTone.error,
            ),
          ),
          data: (settings) => ListView(
            children: <Widget>[
              const CinevaPageHeader(
                title: 'Préférences utilisateur',
                subtitle: 'Thème, langue, notifications, confidentialité et qualité vidéo globale.',
              ),
              const SizedBox(height: CinevaSpacing.xl),
              _NavTile(
                icon: Icons.translate_rounded,
                title: 'Langue',
                subtitle: settings.language.toUpperCase(),
                onTap: () => context.push('/settings/language'),
              ),
              _NavTile(
                icon: Icons.palette_outlined,
                title: 'Thème',
                subtitle: settings.themeMode.label,
                onTap: () => context.push('/settings/theme'),
              ),
              _NavTile(
                icon: Icons.high_quality_rounded,
                title: 'Préférences vidéo',
                subtitle: 'Qualité ${settings.videoQuality.toUpperCase()} • Sous-titres ${settings.subtitlesEnabled ? 'activés' : 'désactivés'}',
                onTap: () => context.push('/settings/video'),
              ),
              _NavTile(
                icon: Icons.notifications_active_outlined,
                title: 'Notifications',
                subtitle: settings.notificationPreferences.enabled ? 'Activées' : 'Désactivées',
                onTap: () => context.push('/settings/notifications'),
              ),
              _NavTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Confidentialité',
                subtitle: settings.privacyPreferences.analyticsEnabled ? 'Analyses activées' : 'Analyses désactivées',
                onTap: () => context.push('/settings/privacy'),
              ),
              _NavTile(
                icon: Icons.auto_awesome_rounded,
                title: 'Cineva Vision',
                subtitle: settings.visionSettings.profile.label,
                onTap: () => context.push('/settings/cineva-vision'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(CinevaRadii.medium),
        onTap: onTap,
        child: CinevaGlassCard(
          child: Row(
            children: <Widget>[
              Icon(icon, color: CinevaColors.accentSoft),
              const SizedBox(width: CinevaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
