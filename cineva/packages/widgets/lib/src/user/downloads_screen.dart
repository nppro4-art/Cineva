import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../cineva_empty_state_card.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryControllerProvider);
    final controller = ref.read(libraryControllerProvider.notifier);
    final usedBytes = library.downloads.fold<int>(0, (sum, item) => sum + (item.downloadedBytes > 0 ? item.downloadedBytes : item.totalBytes));

    return ListView(
      padding: const EdgeInsets.all(CinevaSpacing.lg),
      children: <Widget>[
        const CinevaPageHeader(
          title: 'Téléchargements',
          subtitle: 'Téléchargements réels lorsqu’un flux direct est disponible, file d’attente, reprise et lecture locale.',
        ),
        const SizedBox(height: CinevaSpacing.md),
        CinevaGlassCard(
          child: Row(
            children: <Widget>[
              const Icon(Icons.storage_rounded, color: CinevaColors.accentSoft),
              const SizedBox(width: CinevaSpacing.md),
              Expanded(
                child: Text(
                  'Espace utilisé par Cineva : ${AppFormatters.formatBytes(usedBytes)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: CinevaSpacing.xl),
        if (library.errorMessage != null) ...<Widget>[
          CinevaStatusBanner(
            title: 'Téléchargements partiellement indisponibles',
            message: library.errorMessage!,
            tone: CinevaBannerTone.warning,
          ),
          const SizedBox(height: CinevaSpacing.lg),
        ],
        if (library.downloads.isEmpty)
          const CinevaEmptyStateCard(
            title: 'Aucun téléchargement',
            subtitle: 'Depuis une fiche contenu, utilisez Télécharger pour lancer un téléchargement local avec reprise et gestion de file.',
            icon: Icons.download_for_offline_outlined,
          )
        else
          ...library.downloads.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
              child: _DownloadCard(
                item: item,
                onPause: () => controller.pauseDownload(item.contentId),
                onResume: () => controller.resumeDownload(item.contentId),
                onRemove: () => controller.removeDownload(item.contentId),
              ),
            ),
          ),
      ],
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.item,
    required this.onPause,
    required this.onResume,
    required this.onRemove,
  });

  final DownloadItemModel item;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return CinevaGlassCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CinevaRadii.medium),
              gradient: const LinearGradient(colors: <Color>[CinevaColors.accent, CinevaColors.accentSoft]),
            ),
            child: Icon(item.content.contentType == 'movie' ? Icons.movie_creation_outlined : Icons.live_tv_rounded),
          ),
          const SizedBox(width: CinevaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: Text(item.content.title, style: Theme.of(context).textTheme.titleMedium)),
                    if (item.canPlayOffline)
                      const Icon(Icons.offline_pin_rounded, color: CinevaColors.success),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.sizeMb.toStringAsFixed(0)} Mo • ${_statusLabel(item)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted),
                ),
                const SizedBox(height: CinevaSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: item.progressPercent,
                    backgroundColor: CinevaColors.surfaceRaised,
                  ),
                ),
                const SizedBox(height: CinevaSpacing.sm),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    Text(
                      '${(item.progressPercent * 100).round()}% téléchargé',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                    ),
                    if (item.transferSpeedMbps != null)
                      Text(
                        '${item.transferSpeedMbps!.toStringAsFixed(2)} Mb/s',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                      ),
                    if (item.estimatedRemainingSeconds != null && item.estimatedRemainingSeconds! > 0)
                      Text(
                        '${AppFormatters.formatEta(item.estimatedRemainingSeconds!)} restants',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                      ),
                  ],
                ),
                if (item.downloadedBytes > 0 || item.totalBytes > 0) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    '${AppFormatters.formatBytes(item.downloadedBytes)} / ${AppFormatters.formatBytes(item.totalBytes)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                  ),
                ],
                if (item.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    item.errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.warning),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: CinevaSpacing.md),
          Column(
            children: <Widget>[
              if (item.isDownloading)
                IconButton(onPressed: onPause, icon: const Icon(Icons.pause_rounded))
              else if (item.isPaused || item.status == DownloadStatus.failed)
                IconButton(onPressed: onResume, icon: const Icon(Icons.play_arrow_rounded))
              else if (item.isCompleted)
                const Icon(Icons.check_circle_rounded, color: CinevaColors.success)
              else
                const Icon(Icons.downloading_rounded),
              IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(DownloadItemModel item) {
    return switch (item.status) {
      DownloadStatus.queued => 'En file d’attente',
      DownloadStatus.downloading => 'Téléchargement en cours',
      DownloadStatus.paused => 'Téléchargement en pause',
      DownloadStatus.completed => 'Disponible hors ligne',
      DownloadStatus.failed => 'Échec du téléchargement',
      DownloadStatus.deleted => 'Supprimé',
    };
  }
}
