import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

class AdminStatsScreen extends ConsumerWidget {
  const AdminStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchStatsAsync = ref.watch(adminWatchStatsProvider);
    final dashboardAsync = ref.watch(dashboardSummaryProvider);

    return ListView(
      padding: const EdgeInsets.all(CinevaSpacing.lg),
      children: <Widget>[
        CinevaPageHeader(
          title: 'Statistiques',
          subtitle: 'Watch time, contenus les plus vus, téléchargements et activité récente.',
          trailing: IconButton(
            onPressed: () {
              ref.invalidate(adminWatchStatsProvider);
              ref.invalidate(dashboardSummaryProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        const SizedBox(height: CinevaSpacing.xl),
        dashboardAsync.when(
          loading: () => const SizedBox(height: 120, child: CinevaLoadingView(label: 'Chargement des métriques...')),
          error: (error, _) => CinevaStatusBanner(
            title: 'Métriques indisponibles',
            message: error.toString(),
            tone: CinevaBannerTone.error,
          ),
          data: (summary) => Wrap(
            spacing: CinevaSpacing.md,
            runSpacing: CinevaSpacing.md,
            children: <Widget>[
              _KpiTile(label: 'Temps total de visionnage', value: '${summary.totalWatchMinutes} min', icon: Icons.timer_rounded),
              _KpiTile(label: 'Événements de lecture', value: '${summary.totalWatchEvents}', icon: Icons.play_circle_fill_rounded),
              _KpiTile(label: 'Téléchargements', value: '${summary.totalDownloads}', icon: Icons.download_done_rounded),
            ],
          ),
        ),
        const SizedBox(height: CinevaSpacing.xxl),
        const CinevaSectionTitle(title: 'Contenus les plus regardés'),
        const SizedBox(height: CinevaSpacing.md),
        watchStatsAsync.when(
          loading: () => const SizedBox(height: 240, child: CinevaLoadingView(label: 'Agrégation des statistiques...')),
          error: (error, _) => CinevaStatusBanner(
            title: 'Statistiques indisponibles',
            message: error.toString(),
            tone: CinevaBannerTone.error,
          ),
          data: (stats) {
            if (stats.isEmpty) {
              return const CinevaStatusBanner(
                title: 'Pas encore de données',
                message: 'Les contenus les plus regardés apparaîtront dès que des événements de lecture seront disponibles.',
              );
            }
            return Column(
              children: stats.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
                child: CinevaGlassCard(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(item.title, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              '${item.contentType.toUpperCase()} • ${item.totalEvents} événements',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: CinevaSpacing.md),
                      Text('${item.totalMinutes} min', style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
              )).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: CinevaGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: CinevaColors.accentSoft),
            const SizedBox(height: CinevaSpacing.md),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: CinevaSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
