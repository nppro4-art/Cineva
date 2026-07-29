import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../cineva_empty_state_card.dart';
import '../cineva_stat_tile.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return ListView(
      padding: const EdgeInsets.all(CinevaSpacing.lg),
      children: <Widget>[
        CinevaPageHeader(
          title: 'Dashboard',
          subtitle: 'Vue consolidée des utilisateurs, abonnements, appareils, lecture et téléchargements.',
          trailing: IconButton(
            onPressed: () => ref.invalidate(dashboardSummaryProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        const SizedBox(height: CinevaSpacing.xl),
        summaryAsync.when(
          loading: () => const SizedBox(height: 260, child: CinevaLoadingView(label: 'Chargement du tableau de bord...')),
          error: (error, _) => CinevaStatusBanner(
            title: 'Chargement impossible',
            message: error.toString(),
            tone: CinevaBannerTone.error,
          ),
          data: (summary) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final tileWidth = width > 1500 ? 260.0 : width > 1100 ? 220.0 : width > 760 ? (width - 16) / 2 : width;
                  return Wrap(
                    spacing: CinevaSpacing.md,
                    runSpacing: CinevaSpacing.md,
                    children: <Widget>[
                      SizedBox(width: tileWidth, child: CinevaStatTile(label: 'Utilisateurs', value: '${summary.totalUsers}', icon: Icons.group_rounded)),
                      SizedBox(width: tileWidth, child: CinevaStatTile(label: 'Actifs', value: '${summary.activeUsers}', icon: Icons.verified_rounded)),
                      SizedBox(width: tileWidth, child: CinevaStatTile(label: 'Expirés', value: '${summary.expiredUsers}', icon: Icons.schedule_rounded)),
                      SizedBox(width: tileWidth, child: CinevaStatTile(label: 'Bientôt expirés', value: '${summary.expiringSoonUsers}', icon: Icons.notification_important_rounded)),
                      SizedBox(width: tileWidth, child: CinevaStatTile(label: 'Téléchargements', value: '${summary.totalDownloads}', icon: Icons.download_done_rounded)),
                      SizedBox(width: tileWidth, child: CinevaStatTile(label: 'Watch time', value: '${summary.totalWatchMinutes} min', icon: Icons.timer_rounded)),
                    ],
                  );
                },
              ),
              const SizedBox(height: CinevaSpacing.xxl),
              Wrap(
                spacing: CinevaSpacing.md,
                runSpacing: CinevaSpacing.md,
                children: <Widget>[
                  SizedBox(
                    width: 420,
                    child: _SummaryPanel(
                      title: 'Comptes récents',
                      child: summary.recentUsers.isEmpty
                          ? const CinevaEmptyStateCard(
                              title: 'Aucun nouvel utilisateur',
                              subtitle: 'Les nouveaux comptes s’afficheront ici automatiquement.',
                              icon: Icons.person_add_alt_1_rounded,
                            )
                          : Column(
                              children: summary.recentUsers
                                  .map(
                                    (user) => Padding(
                                      padding: const EdgeInsets.only(bottom: CinevaSpacing.sm),
                                      child: _MiniUserTile(user: user),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ),
                  SizedBox(
                    width: 420,
                    child: _SummaryPanel(
                      title: 'Appareils récents',
                      child: summary.recentDevices.isEmpty
                          ? const CinevaEmptyStateCard(
                              title: 'Aucun appareil',
                              subtitle: 'Les dernières connexions apparaîtront ici.',
                              icon: Icons.devices_other_rounded,
                            )
                          : Column(
                              children: summary.recentDevices
                                  .map(
                                    (device) => Padding(
                                      padding: const EdgeInsets.only(bottom: CinevaSpacing.sm),
                                      child: _MiniDeviceTile(device: device),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CinevaGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CinevaSectionTitle(title: title),
          const SizedBox(height: CinevaSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _MiniUserTile extends StatelessWidget {
  const _MiniUserTile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final tone = user.isAdmin
        ? CinevaColors.accentSoft
        : user.hasActiveSubscription
            ? CinevaColors.success
            : CinevaColors.warning;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CinevaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(CinevaRadii.small),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CinevaSpacing.md),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(user.fullName, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(user.email, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tone.withOpacity(0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(user.isAdmin ? 'Admin' : (user.hasActiveSubscription ? 'Actif' : 'Expiré')),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniDeviceTile extends StatelessWidget {
  const _MiniDeviceTile({required this.device});

  final DeviceModel device;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CinevaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(CinevaRadii.small),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CinevaSpacing.md),
        child: Row(
          children: <Widget>[
            const Icon(Icons.devices_rounded, color: CinevaColors.accentSoft),
            const SizedBox(width: CinevaSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(device.displayName, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${device.platform.toUpperCase()} • ${device.appVersion ?? 'Version inconnue'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
