import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../cineva_stat_tile.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionControllerProvider);
    final settingsAsync = ref.watch(settingsControllerProvider);
    final session = sessionAsync.valueOrNull;
    final user = session?.user;
    final settings = settingsAsync.valueOrNull ?? user?.settings ?? AppSettingsModel.defaults();
    final visionState = ref.watch(visionControllerProvider);

    if (sessionAsync.isLoading && user == null) {
      return const CinevaLoadingView();
    }

    if (user == null) {
      return const Center(child: Text('Aucune session active.'));
    }

    return ListView(
      padding: const EdgeInsets.all(CinevaSpacing.lg),
      children: <Widget>[
        CinevaPageHeader(
          title: user.fullName,
          subtitle: user.email,
          trailing: IconButton(
            onPressed: () async {
              await ref.read(sessionControllerProvider.notifier).refresh(showLoader: false);
              await ref.read(settingsControllerProvider.notifier).load();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        const SizedBox(height: CinevaSpacing.xl),
        CinevaGlassCard(
          child: Row(
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: <Color>[CinevaColors.accent, CinevaColors.accentSoft]),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: CinevaColors.accent.withOpacity(0.26),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 34),
              ),
              const SizedBox(width: CinevaSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(user.fullName, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(user.email, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted)),
                    const SizedBox(height: CinevaSpacing.sm),
                    Text(
                      user.hasActiveSubscription ? 'Abonnement actif' : 'Abonnement expiré',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: user.hasActiveSubscription ? CinevaColors.success : CinevaColors.warning,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: CinevaSpacing.xl),
        Wrap(
          spacing: CinevaSpacing.md,
          runSpacing: CinevaSpacing.md,
          children: <Widget>[
            SizedBox(
              width: 220,
              child: CinevaStatTile(
                label: 'Expiration',
                value: user.subscriptionExpiresLabel,
                icon: Icons.calendar_month_rounded,
              ),
            ),
            SizedBox(
              width: 220,
              child: CinevaStatTile(
                label: 'Jours restants',
                value: '${user.daysRemaining}',
                icon: Icons.timelapse_rounded,
              ),
            ),
            SizedBox(
              width: 220,
              child: CinevaStatTile(
                label: 'Cineva Vision',
                value: visionState.settings?.profile.label ?? settings.visionSettings.profile.label,
                icon: Icons.auto_awesome_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: CinevaSpacing.xl),
        _ActionTile(
          icon: Icons.settings_rounded,
          title: 'Paramètres',
          subtitle:
              'Langue, thème, qualité vidéo globale, notifications, confidentialité et Cineva Vision.',
          onTap: () => context.push('/settings'),
        ),
        const SizedBox(height: CinevaSpacing.sm),
        _ActionTile(
          icon: Icons.auto_awesome_rounded,
          title: 'Qualité d’image — Cineva Vision',
          subtitle: visionState.capabilities?.recommendedModeLabel != null
              ? 'Mode ${visionState.capabilities!.recommendedModeLabel} recommandé pour votre appareil.'
              : 'Analyse automatique du matériel et réglages avancés.',
          onTap: () => context.push('/settings/cineva-vision'),
        ),
        const SizedBox(height: CinevaSpacing.xl),
        const CinevaSectionTitle(title: 'Appareils connectés'),
        const SizedBox(height: CinevaSpacing.md),
        ...(session?.devices ?? const <DeviceModel>[]).map((device) => _DeviceTile(device: device)).toList(),
        const SizedBox(height: CinevaSpacing.xl),
        SizedBox(
          width: 220,
          child: CinevaPrimaryButton(
            label: 'Se déconnecter',
            icon: Icons.logout_rounded,
            onPressed: () => ref.read(sessionControllerProvider.notifier).signOut(),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
    return InkWell(
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
    );
  }
}

class _DeviceTile extends ConsumerWidget {
  const _DeviceTile({required this.device});

  final DeviceModel device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CinevaSpacing.sm),
      child: CinevaGlassCard(
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(device.displayName, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${device.platform.toUpperCase()} • ${device.appVersion ?? 'Version inconnue'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () async {
                await ref.read(sessionControllerProvider.notifier).removeDevice(device.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appareil supprimé.')));
                }
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
