import 'package:cineva_animations/cineva_animations.dart';
import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../cineva_poster_card.dart';
import 'cineva_artwork.dart';
import 'content_detail_helpers.dart';

part 'content_detail_components.dart';

class ContentDetailScreen extends ConsumerStatefulWidget {
  const ContentDetailScreen({super.key, required this.contentId});

  final String contentId;

  @override
  ConsumerState<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends ConsumerState<ContentDetailScreen> {
  int _selectedSeasonIndex = 0;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(contentDetailProvider(widget.contentId));
    final similarAsync = ref.watch(similarContentProvider(widget.contentId));
    final library = ref.watch(libraryControllerProvider);

    return Scaffold(
      body: detailAsync.when(
        loading: () => const CinevaScaffoldContainer(
          child: CinevaLoadingView(label: 'Chargement du contenu...'),
        ),
        error: (error, _) => CinevaScaffoldContainer(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: CinevaStatusBanner(
                title: 'Impossible de charger la fiche',
                message: error.toString(),
                tone: CinevaBannerTone.error,
              ),
            ),
          ),
        ),
        data: (detail) {
          if (detail == null) {
            return const CinevaScaffoldContainer(
              child: Center(
                child: CinevaStatusBanner(
                  title: 'Contenu introuvable',
                  message: 'Le contenu demandé n’est pas disponible pour le moment.',
                  tone: CinevaBannerTone.warning,
                ),
              ),
            );
          }

          final isFavorite = library.isFavorite(detail.id);
          final download = library.downloadFor(detail.id);
          final progress = library.progressFor(detail.id, detail.contentType);
          final seasonIndex = detail.seasons.isEmpty
              ? 0
              : _selectedSeasonIndex.clamp(0, detail.seasons.length - 1);
          final selectedSeason = detail.seasons.isEmpty ? null : detail.seasons[seasonIndex];

          final latestEpisodeProgress = ContentDetailHelpers.latestSeriesProgress(
            detail,
            library.continueWatching,
          );

          return CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: <Widget>[
              SliverAppBar(
                expandedHeight: 420,
                pinned: true,
                backgroundColor: CinevaColors.background,
                leading: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      CinevaArtwork(
                        content: detail.toTile(),
                        useBackdrop: true,
                        borderRadius: BorderRadius.zero,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.black.withOpacity(0.08),
                              Colors.black.withOpacity(0.28),
                              CinevaColors.background,
                            ],
                            stops: const <double>[0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(CinevaSpacing.lg),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    <Widget>[
                      CinevaFadeSlide(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1440),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final wide = ContentDetailLayout.isWide(constraints.maxWidth);
                                final poster = SizedBox(
                                  width: ContentDetailLayout.posterWidth(constraints.maxWidth),
                                  child: AspectRatio(
                                    aspectRatio: 2 / 3,
                                    child: Hero(
                                      tag: 'poster-${detail.id}',
                                      child: CinevaArtwork(
                                        content: detail.toTile(),
                                        borderRadius: BorderRadius.circular(CinevaRadii.large),
                                        showTypeBadge: true,
                                      ),
                                    ),
                                  ),
                                );

                                final body = Expanded(
                                  child: FocusTraversalGroup(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: <Widget>[
                                            _InfoChip(label: detail.badge),
                                            if (detail.year != null) _InfoChip(label: '${detail.year}'),
                                            if (detail.durationMinutes != null) _InfoChip(label: '${detail.durationMinutes} min'),
                                            if (detail.ageRating != null) _InfoChip(label: detail.ageRating!),
                                            if (detail.rating != null) _InfoChip(label: '★ ${detail.rating!.toStringAsFixed(1)}'),
                                          ],
                                        ),
                                        const SizedBox(height: CinevaSpacing.lg),
                                        Semantics(
                                          header: true,
                                          child: Text(detail.title, style: Theme.of(context).textTheme.displaySmall),
                                        ),
                                        const SizedBox(height: CinevaSpacing.sm),
                                        Text(
                                          detail.subtitle,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: CinevaColors.textMuted),
                                        ),
                                        const SizedBox(height: CinevaSpacing.lg),
                                        Text(
                                          detail.synopsis,
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
                                        ),
                                        const SizedBox(height: CinevaSpacing.xl),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: detail.genres.map((genre) => _InfoChip(label: genre)).toList(),
                                        ),
                                        const SizedBox(height: CinevaSpacing.xl),
                                        _PrimaryActions(
                                          detail: detail,
                                          progress: progress,
                                          download: download,
                                          isFavorite: isFavorite,
                                          onPlay: () => _playContent(detail.defaultPlaybackId ?? detail.id),
                                          onDownload: () => _handleDownload(detail, download),
                                          onFavorite: () => _handleFavorite(detail.toTile()),
                                        ),
                                        if (progress != null && !detail.isSeries) ...<Widget>[
                                          const SizedBox(height: CinevaSpacing.lg),
                                          CinevaStatusBanner(
                                            title: 'Reprise disponible',
                                            message: 'Dernière progression : ${((progress.progressPercent) * 100).round()}% • ${AppFormatters.formatDuration(progress.positionSeconds)}',
                                            tone: CinevaBannerTone.info,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );

                                if (wide) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      poster,
                                      const SizedBox(width: CinevaSpacing.xl),
                                      body,
                                    ],
                                  );
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    poster,
                                    const SizedBox(height: CinevaSpacing.xl),
                                    body,
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: CinevaSpacing.xxl),
                      Wrap(
                        spacing: CinevaSpacing.md,
                        runSpacing: CinevaSpacing.md,
                        children: <Widget>[
                          _DetailPanel(title: 'Réalisateur', content: detail.directorName),
                          _DetailPanel(title: 'Langues audio', content: detail.audioLanguages.join(' • ')),
                          _DetailPanel(title: 'Sous-titres', content: detail.subtitleLanguages.join(' • ')),
                          _DetailPanel(title: 'Casting', content: detail.castNames.join(', ')),
                        ],
                      ),
                      if (detail.isSeries && detail.seasons.isNotEmpty) ...<Widget>[
                        const SizedBox(height: CinevaSpacing.xxl),
                        _SeriesSeasonControls(
                          detail: detail,
                          selectedSeasonIndex: seasonIndex,
                          onSeasonSelected: (index) => setState(() => _selectedSeasonIndex = index),
                          onResume: latestEpisodeProgress == null
                              ? null
                              : () => _playContent(latestEpisodeProgress.content.id),
                          onStartSeason: selectedSeason?.firstEpisode == null
                              ? null
                              : () => _playContent(selectedSeason!.firstEpisode!.id),
                          onRandomEpisode: () => _playRandomEpisode(detail),
                        ),
                        const SizedBox(height: CinevaSpacing.lg),
                        if (selectedSeason != null)
                          ...selectedSeason.episodes.map(
                            (episode) => Padding(
                              padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
                              child: _EpisodeCard(
                                episode: episode,
                                progress: library.progressFor(episode.id, 'episode'),
                                onTap: () => _playContent(episode.id),
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: CinevaSpacing.xxl),
                      const CinevaSectionTitle(title: 'Contenus similaires'),
                      const SizedBox(height: CinevaSpacing.md),
                      similarAsync.when(
                        loading: () => const SizedBox(
                          height: 260,
                          child: CinevaLoadingView(label: 'Recherche de recommandations...'),
                        ),
                        error: (error, _) => CinevaStatusBanner(
                          title: 'Impossible de charger les recommandations',
                          message: error.toString(),
                          tone: CinevaBannerTone.warning,
                        ),
                        data: (items) {
                          if (items.isEmpty) {
                            return const CinevaStatusBanner(
                              title: 'Aucune recommandation',
                              message: 'Ajoutez davantage de contenus pour enrichir les recommandations similaires.',
                            );
                          }
                          return SizedBox(
                            height: 274,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) => CinevaPosterCard(
                                item: items[index],
                                onTap: () => context.push('/content/${Uri.encodeComponent(items[index].id)}'),
                              ),
                              separatorBuilder: (_, __) => const SizedBox(width: CinevaSpacing.md),
                              itemCount: items.length,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _playContent(String contentId) {
    context.push('/player/${Uri.encodeComponent(contentId)}');
  }

  void _playRandomEpisode(ContentDetailModel detail) {
    final episode = ContentDetailHelpers.pickRandomEpisode(detail);
    if (episode == null) return;
    _playContent(episode.id);
  }

  Future<void> _handleFavorite(ContentTileModel content) async {
    await ref.read(libraryControllerProvider.notifier).toggleFavorite(content);
    if (mounted) {
      final isFavorite = ref.read(libraryControllerProvider).isFavorite(content.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isFavorite ? 'Ajouté à Ma liste.' : 'Retiré de Ma liste.')),
      );
    }
  }

  Future<void> _handleDownload(ContentDetailModel detail, DownloadItemModel? current) async {
    final controller = ref.read(libraryControllerProvider.notifier);
    if (current == null) {
      await controller.enqueueDownload(detail);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Téléchargement ajouté.')));
      }
      return;
    }
    if (current.isDownloading) {
      await controller.pauseDownload(detail.id);
    } else if (current.isPaused) {
      await controller.resumeDownload(detail.id);
    } else if (current.isCompleted) {
      await controller.removeDownload(detail.id);
    } else {
      await controller.resumeDownload(detail.id);
    }
  }
}
