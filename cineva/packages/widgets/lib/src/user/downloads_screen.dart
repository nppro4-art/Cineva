import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../library/library_controller.dart';
import 'content_detail_helpers.dart';

/// Téléchargements Cineva.
///
/// Lit l'état réel de [LibraryController] (file gérée par
/// `MediaDownloadService`, persistée par le dépôt). Les items sont regroupés
/// par statut : en cours, en pause, échoués, disponibles hors ligne.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  bool _editMode = false;

  @override
  Widget build(BuildContext context) {
    final LibraryState library = ref.watch(libraryControllerProvider);
    final CinevaMetrics metrics = CinevaMetrics.of(context);
    final List<DownloadItemModel> items = library.downloads;

    final List<DownloadItemModel> active = items
        .where((DownloadItemModel item) =>
            item.status == DownloadStatus.downloading ||
            item.status == DownloadStatus.queued)
        .toList();
    final List<DownloadItemModel> paused = items
        .where((DownloadItemModel item) => item.status == DownloadStatus.paused)
        .toList();
    final List<DownloadItemModel> failed = items
        .where((DownloadItemModel item) => item.status == DownloadStatus.failed)
        .toList();
    final List<DownloadItemModel> completed = items
        .where((DownloadItemModel item) => item.status == DownloadStatus.completed)
        .toList();

    return Scaffold(
      backgroundColor: CinevaColors.ink,
      body: RefreshIndicator(
        onRefresh: () => ref.read(libraryControllerProvider.notifier).load(),
        color: CinevaColors.gold,
        backgroundColor: CinevaColors.raised,
        edgeOffset: metrics.topInset + 84,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
            decelerationRate: ScrollDecelerationRate.fast,
          ),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: SizedBox(height: metrics.topInset + CinevaSpacing.xxxl),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: metrics.gutter),
              sliver: SliverToBoxAdapter(
                child: CinevaScreenTitle(
                  title: 'Téléchargements',
                  padding: EdgeInsets.zero,
                  subtitle: _subtitle(items, completed),
                  trailing: items.isEmpty
                      ? null
                      : CinevaPressable(
                          pressedScale: 0.94,
                          onTap: () => setState(() => _editMode = !_editMode),
                          semanticLabel:
                              _editMode ? 'Terminer la modification' : 'Modifier la liste',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: CinevaSpacing.xs,
                              vertical: CinevaSpacing.xs,
                            ),
                            child: AnimatedDefaultTextStyle(
                              duration: CinevaMotion.fast,
                              style: CinevaTypography.button.copyWith(
                                fontSize: 12.5,
                                color: _editMode ? CinevaColors.gold : CinevaColors.textSoft,
                              ),
                              child: Text(_editMode ? 'Terminé' : 'Modifier'),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyDownloads(metrics: metrics),
              )
            else ...<Widget>[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  metrics.gutter,
                  CinevaSpacing.md,
                  metrics.gutter,
                  CinevaSpacing.lg,
                ),
                sliver: SliverToBoxAdapter(
                  child: _StorageSummary(
                    active: active.length,
                    paused: paused.length,
                    completed: completed.length,
                    bytes: _offlineBytes(completed),
                  ),
                ),
              ),
              if (library.errorMessage != null)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: metrics.gutter),
                  sliver: SliverToBoxAdapter(
                    child: CinevaStatusBanner(
                      message: library.errorMessage!,
                      tone: CinevaBannerTone.error,
                    ),
                  ),
                ),
              ..._group(context, 'En cours', active),
              ..._group(context, 'En pause', paused),
              ..._group(context, 'À relancer', failed),
              ..._group(context, 'Hors ligne', completed),
              if (_editMode)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    metrics.gutter,
                    CinevaSpacing.sm,
                    metrics.gutter,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: CinevaSecondaryButton(
                      label: 'Tout supprimer',
                      icon: Icons.delete_sweep_rounded,
                      tone: CinevaButtonTone.danger,
                      height: 44,
                      onPressed: completed.isEmpty ? null : _removeAll,
                    ),
                  ),
                ),
            ],
            SliverToBoxAdapter(
              child: SizedBox(
                height: CinevaBottomNavigation.clearance(
                  context,
                  extra: CinevaSpacing.xxl,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(List<DownloadItemModel> items, List<DownloadItemModel> completed) {
    if (items.isEmpty) return 'Rien de téléchargé pour l’instant';
    final String size = CinevaSizeLabels.fromBytes(_offlineBytes(completed));
    final String label = completed.length == 1
        ? '1 titre disponible hors ligne'
        : '${completed.length} titres disponibles hors ligne';
    return size.isEmpty ? label : '$label · $size';
  }

  int _offlineBytes(List<DownloadItemModel> completed) {
    int total = 0;
    for (final DownloadItemModel item in completed) {
      total += item.totalBytes > 0
          ? item.totalBytes
          : (item.sizeMb * 1024 * 1024).round();
    }
    return total;
  }

  List<Widget> _group(BuildContext context, String title, List<DownloadItemModel> items) {
    if (items.isEmpty) return const <Widget>[];
    final CinevaMetrics metrics = CinevaMetrics.of(context);

    return <Widget>[
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          metrics.gutter,
          CinevaSpacing.md,
          metrics.gutter,
          CinevaSpacing.xs,
        ),
        sliver: SliverToBoxAdapter(
          child: CinevaSectionHeader(
            title: title,
            actionLabel: '${items.length}',
            onAction: null,
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: metrics.gutter),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            childCount: items.length,
            (BuildContext context, int index) => _tile(items[index]),
          ),
        ),
      ),
    ];
  }

  Widget _tile(DownloadItemModel item) {
    return CinevaDownloadTile(
      item: item,
      primaryIcon: ContentDetailHelpers.downloadIcon(item),
      primaryTooltip: ContentDetailHelpers.downloadLabel(item),
      onTap: () => _open(item),
      onPrimaryAction: () => _primaryAction(item),
      onRemove: _editMode || item.status == DownloadStatus.failed
          ? () => _confirmRemove(item)
          : null,
    );
  }

  void _open(DownloadItemModel item) {
    if (item.canPlayOffline || item.status == DownloadStatus.completed) {
      context.push('/player/${Uri.encodeComponent(item.contentId)}');
      return;
    }
    context.push('/content/${Uri.encodeComponent(item.contentId)}');
  }

  Future<void> _primaryAction(DownloadItemModel item) async {
    final LibraryController controller = ref.read(libraryControllerProvider.notifier);
    switch (item.status) {
      case DownloadStatus.downloading:
      case DownloadStatus.queued:
        await controller.pauseDownload(item.contentId);
      case DownloadStatus.paused:
        await controller.resumeDownload(item.contentId);
      case DownloadStatus.failed:
        await controller.resumeDownload(item.contentId);
      case DownloadStatus.completed:
      case DownloadStatus.deleted:
        _open(item);
    }
  }

  Future<void> _confirmRemove(DownloadItemModel item) async {
    final bool confirmed = await CinevaDialog.show(
      context,
      title: 'Supprimer le téléchargement',
      message: '« ${item.content.title} » ne sera plus disponible hors ligne.',
      confirmLabel: 'Supprimer',
      cancelLabel: 'Conserver',
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(libraryControllerProvider.notifier).removeDownload(item.contentId);
  }

  Future<void> _removeAll() async {
    final LibraryController controller = ref.read(libraryControllerProvider.notifier);
    final List<DownloadItemModel> completed = ref
        .read(libraryControllerProvider)
        .downloads
        .where((DownloadItemModel item) => item.status == DownloadStatus.completed)
        .toList();
    if (completed.isEmpty) return;

    final bool confirmed = await CinevaDialog.show(
      context,
      title: 'Tout supprimer',
      message: completed.length == 1
          ? '« ${completed.first.content.title} » ne sera plus disponible hors ligne.'
          : '${completed.length} titres ne seront plus disponibles hors ligne.',
      confirmLabel: 'Supprimer',
      cancelLabel: 'Annuler',
      icon: Icons.delete_sweep_rounded,
      destructive: true,
    );
    if (!confirmed) return;

    for (final DownloadItemModel item in completed) {
      await controller.removeDownload(item.contentId);
    }
    if (!mounted) return;
    setState(() => _editMode = false);
  }
}

/// Récapitulatif réel : ce qui est hors ligne, en cours, en pause, et le
/// volume occupé. Aucune capacité disque n'est exposée par les services, on
/// n'affiche donc pas de pourcentage inventé.
class _StorageSummary extends StatelessWidget {
  const _StorageSummary({
    required this.active,
    required this.paused,
    required this.completed,
    required this.bytes,
  });

  final int active;
  final int paused;
  final int completed;
  final int bytes;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CinevaColors.surface,
        borderRadius: BorderRadius.circular(CinevaRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CinevaSpacing.md,
          vertical: CinevaSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            _SummaryStat(
              icon: Icons.download_done_rounded,
              value: '$completed',
              label: 'Hors ligne',
              accent: CinevaColors.gold,
            ),
            _SummaryStat(
              icon: Icons.downloading_rounded,
              value: '$active',
              label: 'En cours',
              accent: CinevaColors.textHigh,
            ),
            _SummaryStat(
              icon: Icons.pause_circle_outline_rounded,
              value: '$paused',
              label: 'En pause',
              accent: CinevaColors.textHigh,
            ),
            _SummaryStat(
              icon: Icons.sd_storage_rounded,
              value: bytes > 0 ? CinevaSizeLabels.fromBytes(bytes) : '—',
              label: 'Occupé',
              accent: CinevaColors.textHigh,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Icon(icon, size: 15, color: accent),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: CinevaTypography.numeric.copyWith(
                fontSize: 13.5,
                color: CinevaColors.textHigh,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CinevaTypography.meta.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads({required this.metrics});

  final CinevaMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          metrics.gutter,
          0,
          metrics.gutter,
          CinevaBottomNavigation.clearance(context),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: CinevaColors.surface,
              ),
              child: const Icon(
                Icons.download_for_offline_outlined,
                size: 26,
                color: CinevaColors.textFaint,
              ),
            ),
            const SizedBox(height: CinevaSpacing.lg),
            Text(
              'Aucun téléchargement',
              style: CinevaTypography.sectionTitle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: CinevaSpacing.xs),
            Text(
              'Téléchargez un film ou un épisode depuis sa fiche pour le regarder sans connexion.',
              textAlign: TextAlign.center,
              style: CinevaTypography.bodyCompact,
            ),
            const SizedBox(height: CinevaSpacing.xl),
            CinevaSecondaryButton(
              label: 'Parcourir le catalogue',
              icon: Icons.arrow_forward_rounded,
              expanded: false,
              onPressed: () => context.go('/home'),
            ),
          ],
        ),
      ),
    );
  }
}
