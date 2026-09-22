import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../library/library_controller.dart';
import 'content_detail_helpers.dart';

part 'content_detail_components.dart';

/// Fiche contenu Cineva (film **et** série).
///
/// Mobile portrait : visuel pleine largeur en haut avec un dégradé important,
/// titre incrusté, puis métadonnées, note, synopsis, actions principales,
/// actions circulaires, saisons/épisodes et contenus similaires.
class ContentDetailScreen extends ConsumerStatefulWidget {
  const ContentDetailScreen({super.key, required this.contentId});

  final String contentId;

  @override
  ConsumerState<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends ConsumerState<ContentDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _castKey = GlobalKey();

  int _seasonIndex = 0;
  bool _synopsisExpanded = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ContentDetailModel?> detailAsync =
        ref.watch(contentDetailProvider(widget.contentId));

    return detailAsync.when(
      loading: () => const _DetailSkeleton(),
      error: (Object error, StackTrace stackTrace) => _DetailError(
        error: error,
        onBack: _goBack,
      ),
      data: (ContentDetailModel? detail) {
        if (detail == null) {
          return _DetailError(
            error: 'Le contenu demandé n’est pas disponible pour le moment.',
            onBack: _goBack,
          );
        }
        return _buildDetail(detail);
      },
    );
  }

  Widget _buildDetail(ContentDetailModel detail) {
    final LibraryState library = ref.watch(libraryControllerProvider);
    final CinevaMetrics metrics = CinevaMetrics.of(context);

    final bool isFavorite = library.isFavorite(detail.id);
    final DownloadItemModel? download = library.downloadFor(detail.id);
    final PlaybackProgressModel? progress =
        library.progressFor(detail.id, detail.contentType);
    final PlaybackProgressModel? seriesProgress = detail.isSeries
        ? ContentDetailHelpers.latestSeriesProgress(detail, library.continueWatching)
        : null;

    final int seasonIndex = detail.seasons.isEmpty
        ? 0
        : _seasonIndex.clamp(0, detail.seasons.length - 1);
    final SeasonModel? season =
        detail.seasons.isEmpty ? null : detail.seasons[seasonIndex];

    return Stack(
      children: <Widget>[
        CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
            decelerationRate: ScrollDecelerationRate.fast,
          ),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: DetailBackdrop(
                detail: detail,
                height: metrics.detailBackdropHeight,
                scrollController: _scrollController,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                metrics.gutter,
                CinevaSpacing.lg,
                metrics.gutter,
                CinevaSpacing.xxl,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    DetailMetaRow(detail: detail),
                    const SizedBox(height: CinevaSpacing.lg),
                    DetailPrimaryActions(
                      detail: detail,
                      progress: progress,
                      seriesProgress: seriesProgress,
                      isFavorite: isFavorite,
                      onPlay: () => _play(_playTarget(detail)),
                      onTrailer: _trailerUrl(detail) == null
                          ? null
                          : () => _playTrailer(detail),
                      onToggleList: () => _toggleFavorite(detail),
                    ),
                    const SizedBox(height: CinevaSpacing.xl),
                    DetailCircleActions(
                      detail: detail,
                      download: download,
                      hasTrailer: _trailerUrl(detail) != null,
                      onTrailer: () => _playTrailer(detail),
                      onDownload: () => _handleDownload(detail, download),
                      onCast: _scrollToCast,
                    ),
                    const SizedBox(height: CinevaSpacing.xl),
                    DetailSynopsis(
                      text: detail.synopsis,
                      expanded: _synopsisExpanded,
                      onToggle: () =>
                          setState(() => _synopsisExpanded = !_synopsisExpanded),
                    ),
                    if (progress != null && !detail.isSeries) ...<Widget>[
                      const SizedBox(height: CinevaSpacing.lg),
                      DetailResumeCard(
                        progress: progress,
                        onResume: () => _play(detail.id),
                      ),
                    ],
                    if (seriesProgress != null) ...<Widget>[
                      const SizedBox(height: CinevaSpacing.lg),
                      DetailSeriesResumeCard(
                        detail: detail,
                        progress: seriesProgress,
                        onResume: () => _play(seriesProgress.content.id),
                      ),
                    ],
                    const SizedBox(height: CinevaSpacing.xxl),
                    DetailInfoBlock(key: _castKey, detail: detail),
                    if (detail.isSeries && detail.seasons.isNotEmpty) ...<Widget>[
                      const SizedBox(height: CinevaSpacing.xxl),
                      DetailSeasonsHeader(
                        selectedIndex: seasonIndex,
                        seasons: detail.seasons,
                        onSelected: (int index) => setState(() => _seasonIndex = index),
                      ),
                      const SizedBox(height: CinevaSpacing.md),
                      if (season != null)
                        ...season.episodes.map(
                          (EpisodeModel episode) => CinevaEpisodeTile(
                            episode: episode,
                            progress: library.progressFor(episode.id, 'episode'),
                            thumbnailPath: detail.backdropPath,
                            downloadState: _episodeDownloadIcon(
                              library.downloadFor(episode.id),
                            ),
                            onTap: () => _play(episode.id),
                            onDownload: () => _downloadEpisode(episode),
                          ),
                        ),
                    ],
                    const SizedBox(height: CinevaSpacing.xxl),
                    DetailSimilarRail(contentId: detail.id),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _DetailTopBar(
            title: detail.title,
            scrollController: _scrollController,
            threshold: metrics.detailBackdropHeight * 0.62,
            onBack: _goBack,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ actions
  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/home');
  }

  /// Cible de lecture : épisode en cours, sinon épisode aléatoire pour une
  /// série (comportement d'origine), sinon le contenu lui-même.
  String _playTarget(ContentDetailModel detail) {
    final String? playbackId = detail.defaultPlaybackId;
    if (playbackId != null && playbackId.isNotEmpty) return playbackId;
    if (detail.isSeries) {
      final EpisodeModel? episode = ContentDetailHelpers.pickRandomEpisode(detail);
      if (episode != null) return episode.id;
    }
    return detail.id;
  }

  void _play(String contentId) {
    context.push('/player/${Uri.encodeComponent(contentId)}');
  }

  String? _trailerUrl(ContentDetailModel detail) {
    final String? url = detail.trailerUrl;
    if (url == null || url.trim().isEmpty) return null;
    return url;
  }

  void _playTrailer(ContentDetailModel detail) {
    if (_trailerUrl(detail) == null) return;
    context.push('/player/${Uri.encodeComponent(detail.id)}?trailer=true');
  }

  void _scrollToCast() {
    final RenderBox? box =
        _castKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !_scrollController.hasClients) return;
    final double target = (_scrollController.offset + box.localToGlobal(Offset.zero).dy - 96)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: CinevaMotion.slow,
      curve: CinevaCurve.decelerate,
    );
  }

  IconData? _episodeDownloadIcon(DownloadItemModel? item) {
    if (item == null) return Icons.download_rounded;
    return ContentDetailHelpers.downloadIcon(item);
  }

  Future<void> _toggleFavorite(ContentDetailModel detail) async {
    final LibraryController controller = ref.read(libraryControllerProvider.notifier);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await controller.toggleFavorite(detail.toTile());
    final bool now = ref.read(libraryControllerProvider).isFavorite(detail.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1800),
          content: Text(now ? 'Ajouté à Ma liste' : 'Retiré de Ma liste'),
        ),
      );
  }

  Future<void> _handleDownload(
    ContentDetailModel detail,
    DownloadItemModel? current,
  ) async {
    final LibraryController controller = ref.read(libraryControllerProvider.notifier);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    if (current != null) {
      if (current.isDownloading || current.status == DownloadStatus.queued) {
        await controller.pauseDownload(detail.id);
        return;
      }
      if (current.isCompleted) {
        final bool confirmed = await CinevaDialog.show(
          context,
          title: 'Supprimer le téléchargement',
          message: '« ${detail.title} » ne sera plus disponible hors ligne.',
          confirmLabel: 'Supprimer',
          cancelLabel: 'Conserver',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        );
        if (confirmed) await controller.removeDownload(detail.id);
        return;
      }
      await controller.resumeDownload(detail.id);
      return;
    }

    if (detail.resolveDownloadUrl() == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Aucun fichier téléchargeable n’est publié pour ce contenu.'),
        ),
      );
      return;
    }

    await controller.enqueueDownload(detail);
    final String? error = ref.read(libraryControllerProvider).errorMessage;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error ?? 'Téléchargement ajouté à la file.')));
  }

  Future<void> _downloadEpisode(EpisodeModel episode) async {
    final LibraryController controller = ref.read(libraryControllerProvider.notifier);
    final LibraryState library = ref.read(libraryControllerProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final DownloadItemModel? current = library.downloadFor(episode.id);

    if (current != null) {
      if (current.isDownloading || current.status == DownloadStatus.queued) {
        await controller.pauseDownload(episode.id);
        return;
      }
      if (current.isCompleted) {
        await controller.removeDownload(episode.id);
        return;
      }
      await controller.resumeDownload(episode.id);
      return;
    }

    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(milliseconds: 1400),
        content: Text('Préparation du téléchargement…'),
      ),
    );
    final ContentDetailModel? detail =
        await ref.read(contentDetailProvider(episode.id).future);
    if (detail == null || detail.resolveDownloadUrl() == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Aucun fichier téléchargeable pour cet épisode.'),
        ),
      );
      return;
    }
    await controller.enqueueDownload(detail);
  }
}

/// Barre supérieure de la fiche : transparente sur le visuel, surface sombre
/// après ~62 % de la hauteur du visuel, titre en fondu.
class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({
    required this.title,
    required this.scrollController,
    required this.threshold,
    required this.onBack,
  });

  final String title;
  final ScrollController scrollController;
  final double threshold;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (BuildContext context, Widget? child) {
        final double offset =
            scrollController.hasClients && scrollController.offset > 0
                ? scrollController.offset
                : 0;
        final double opacity =
            threshold <= 0 ? 1 : (offset / threshold).clamp(0.0, 1.0);

        return CinevaTopBar(
          title: title,
          opacity: opacity,
          onBack: onBack,
          actions: <Widget>[
            CinevaIconButton(
              icon: Icons.search_rounded,
              filled: opacity < 0.5,
              tooltip: 'Recherche',
              onPressed: () => context.go('/search'),
            ),
          ],
        );
      },
    );
  }
}

/// Écran de chargement de la fiche : même silhouette que la page réelle.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final CinevaMetrics metrics = CinevaMetrics.of(context);

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: <Widget>[
        SizedBox(
          height: metrics.detailBackdropHeight,
          child: const CinevaSkeleton(borderRadius: BorderRadius.zero),
        ),
        Padding(
          padding: EdgeInsets.all(metrics.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CinevaSkeleton(
                height: 16,
                width: metrics.width * 0.5,
                borderRadius: BorderRadius.circular(CinevaRadii.hair),
              ),
              const SizedBox(height: CinevaSpacing.md),
              const CinevaSkeleton(height: 48),
              const SizedBox(height: CinevaSpacing.xl),
              ...List<Widget>.generate(
                4,
                (int index) => Padding(
                  padding: const EdgeInsets.only(bottom: CinevaSpacing.sm),
                  child: CinevaSkeleton(
                    height: 11,
                    width: metrics.width * (0.9 - (index * 0.12)),
                    borderRadius: BorderRadius.circular(CinevaRadii.hair),
                  ),
                ),
              ),
              const SizedBox(height: CinevaSpacing.xl),
              const CinevaSkeleton(height: 92),
              const SizedBox(height: CinevaSpacing.md),
              const CinevaSkeleton(height: 92),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.error, required this.onBack});

  final Object error;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final CinevaMetrics metrics = CinevaMetrics.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(metrics.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CinevaIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              filled: false,
              tooltip: 'Retour',
              onPressed: onBack,
            ),
            const SizedBox(height: CinevaSpacing.xxl),
            const Icon(Icons.movie_outlined, size: 28, color: CinevaColors.textFaint),
            const SizedBox(height: CinevaSpacing.md),
            Text('Fiche indisponible', style: CinevaTypography.screenTitle),
            const SizedBox(height: CinevaSpacing.xs),
            Text('$error', style: CinevaTypography.body),
            const SizedBox(height: CinevaSpacing.xl),
            CinevaSecondaryButton(
              label: 'Retour',
              icon: Icons.arrow_back_rounded,
              expanded: false,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}

/// Formate la durée totale d'un téléchargement annoncé.
String detailDownloadSizeLabel(ContentDetailModel detail) {
  if (detail.downloadSizeMb <= 0) return '';
  return CinevaSizeLabels.fromMb(detail.downloadSizeMb);
}

/// Durée lisible (« 2 h 49 ») à partir des minutes.
String detailDurationLabel(ContentDetailModel detail) {
  return CinevaContentLabels.duration(detail.durationMinutes);
}

/// Libellé d'état du téléchargement pour la fiche.
String detailDownloadStateLabel(DownloadItemModel? item) {
  if (item == null) return 'Télécharger';
  return switch (item.status) {
    DownloadStatus.queued => 'En file',
    DownloadStatus.downloading => '${(item.progressPercent * 100).round()} %',
    DownloadStatus.paused => 'En pause',
    DownloadStatus.completed => 'Hors ligne',
    DownloadStatus.failed => 'Échec',
    DownloadStatus.deleted => 'Télécharger',
  };
}

/// Formatage de l'heure de dernière progression.
String detailProgressLabel(PlaybackProgressModel progress) {
  return '${AppFormatters.formatDuration(progress.positionSeconds)} / '
      '${AppFormatters.formatDuration(progress.durationSeconds)}';
}
