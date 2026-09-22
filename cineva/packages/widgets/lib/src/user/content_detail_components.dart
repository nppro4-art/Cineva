part of 'content_detail_screen.dart';

/// Visuel de la fiche : pleine largeur, dégradé important vers le bas, titre
/// incrusté. Réagit au scroll (parallaxe + très léger rétrécissement).
class DetailBackdrop extends StatelessWidget {
  const DetailBackdrop({
    super.key,
    required this.detail,
    required this.height,
    required this.scrollController,
  });

  final ContentDetailModel detail;
  final double height;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final CinevaMetrics metrics = CinevaMetrics.of(context);

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AnimatedBuilder(
            animation: scrollController,
            builder: (BuildContext context, Widget? child) {
              final double offset =
                  scrollController.hasClients && scrollController.offset > 0
                      ? scrollController.offset
                      : 0;
              final double progress = (offset / height).clamp(0.0, 1.0);
              return ClipRect(
                child: Transform.translate(
                  offset: Offset(0, offset * 0.22),
                  child: Transform.scale(
                    scale: 1.14 - (0.14 * progress),
                    alignment: Alignment.topCenter,
                    child: child,
                  ),
                ),
              );
            },
            child: RepaintBoundary(
              child: CinevaArtworkImage.forDetail(detail, useBackdrop: true),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: CinevaScrims.detailFade(CinevaColors.ink),
            ),
          ),
          Positioned(
            left: metrics.gutter,
            right: metrics.gutter,
            bottom: CinevaSpacing.xs,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      CinevaContentLabels.type(detail.contentType).toUpperCase(),
                      style: CinevaTypography.overline.copyWith(color: CinevaColors.gold),
                    ),
                    if (detail.year != null) ...<Widget>[
                      const _DotSeparator(),
                      Text('${detail.year}', style: CinevaTypography.overline),
                    ],
                  ],
                ),
                const SizedBox(height: CinevaSpacing.xs),
                Text(
                  detail.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: CinevaTypography.detailTitle.copyWith(
                    fontSize: metrics.isTiny ? 23 : 26,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DotSeparator extends StatelessWidget {
  const _DotSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 7),
      child: Text('·', style: CinevaTypography.overline),
    );
  }
}

/// Note + badges de qualité + genres.
class DetailMetaRow extends StatelessWidget {
  const DetailMetaRow({super.key, required this.detail});

  final ContentDetailModel detail;

  @override
  Widget build(BuildContext context) {
    final List<String> badges = _qualityBadges(detail);
    final double? rating = detail.rating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (rating != null && rating > 0) ...<Widget>[
              const Icon(Icons.star_rounded, size: 16, color: CinevaColors.gold),
              const SizedBox(width: 4),
              Text(rating.toStringAsFixed(1), style: CinevaTypography.rating),
              const SizedBox(width: CinevaSpacing.sm),
              Container(width: 1, height: 12, color: CinevaColors.hairlineStrong),
              const SizedBox(width: CinevaSpacing.sm),
            ],
            Expanded(
              child: Text(
                <String>[
                  detailDurationLabel(detail),
                  if (detail.ageRating != null) detail.ageRating!,
                ].where((String value) => value.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CinevaTypography.meta,
              ),
            ),
          ],
        ),
        if (badges.isNotEmpty) ...<Widget>[
          const SizedBox(height: CinevaSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: badges.map((String label) => _QualityBadge(label: label)).toList(),
          ),
        ],
        if (detail.genres.isNotEmpty) ...<Widget>[
          const SizedBox(height: CinevaSpacing.sm),
          Text(
            detail.genres.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CinevaTypography.meta.copyWith(fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

/// Badges réellement dérivés du catalogue (résolutions publiées, HDR, Dolby).
List<String> _qualityBadges(ContentDetailModel detail) {
  final List<VideoQualityOption> options =
      detail.availableQualities.where((VideoQualityOption option) => option.available).toList();
  if (options.isEmpty) {
    final String badge = detail.badge.trim();
    return badge.isEmpty ? const <String>[] : CinevaContentLabels.qualityTokens(badge);
  }

  final List<String> badges = <String>[];
  final VideoQualityOption best = options.reduce(
    (VideoQualityOption a, VideoQualityOption b) =>
        a.preset.index >= b.preset.index ? a : b,
  );
  if (best.preset != VideoQualityPreset.auto) badges.add(best.preset.label);
  if (options.any((VideoQualityOption option) => option.hdr)) badges.add('HDR');
  if (options.any((VideoQualityOption option) => option.dolbyVision)) badges.add('Dolby Vision');
  if (options.any((VideoQualityOption option) => option.dolbyAtmos)) badges.add('Dolby Atmos');
  if (detail.audioLanguages.length > 1) badges.add('${detail.audioLanguages.length} audios');
  if (detail.subtitleLanguages.length > 1) badges.add('${detail.subtitleLanguages.length} sous-titres');
  return badges.take(5).toList();
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CinevaRadii.hair - 2),
        border: Border.all(color: CinevaColors.hairlineStrong),
        color: CinevaColors.surface,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9.5,
          height: 1.2,
          letterSpacing: 0.7,
          fontWeight: FontWeight.w700,
          color: CinevaColors.textSoft,
        ),
      ),
    );
  }
}

/// Actions principales : « Regarder » (ou « Reprendre ») + bascule Ma liste.
class DetailPrimaryActions extends StatelessWidget {
  const DetailPrimaryActions({
    super.key,
    required this.detail,
    required this.progress,
    required this.seriesProgress,
    required this.isFavorite,
    required this.onPlay,
    required this.onTrailer,
    required this.onToggleList,
  });

  final ContentDetailModel detail;
  final PlaybackProgressModel? progress;
  final PlaybackProgressModel? seriesProgress;
  final bool isFavorite;
  final VoidCallback onPlay;
  final VoidCallback? onTrailer;
  final VoidCallback onToggleList;

  @override
  Widget build(BuildContext context) {
    final PlaybackProgressModel? active = progress ?? seriesProgress;
    final double percent = active?.progressPercent ?? 0;
    final String label = percent > 0.02 && percent < 0.97 ? 'Reprendre' : 'Regarder';
    final bool hasStream = detail.videoUrl != null ||
        detail.seasons.any(
          (SeasonModel season) =>
              season.episodes.any((EpisodeModel episode) => episode.videoUrl.isNotEmpty),
        );

    return Row(
      children: <Widget>[
        Expanded(
          child: CinevaPlayButton(
            label: label,
            height: 50,
            onPressed: hasStream ? onPlay : null,
            semanticLabel: '$label ${detail.title}',
          ),
        ),
        const SizedBox(width: CinevaSpacing.sm),
        _SquareActionButton(
          icon: isFavorite ? Icons.check_rounded : Icons.add_rounded,
          active: isFavorite,
          tooltip: isFavorite ? 'Retirer de Ma liste' : 'Ajouter à Ma liste',
          onTap: onToggleList,
        ),
        if (onTrailer != null) ...<Widget>[
          const SizedBox(width: CinevaSpacing.sm),
          _SquareActionButton(
            icon: Icons.play_circle_outline_rounded,
            tooltip: 'Bande-annonce',
            onTap: onTrailer!,
          ),
        ],
      ],
    );
  }
}

class _SquareActionButton extends StatelessWidget {
  const _SquareActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.active = false,
    this.size = 50,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: CinevaPressable(
        pressedScale: 0.92,
        onTap: onTap,
        child: AnimatedContainer(
          duration: CinevaMotion.fast,
          curve: CinevaCurve.out,
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CinevaRadii.medium),
            color: CinevaColors.raised,
            border: Border.all(
              color: active ? CinevaColors.gold.withOpacity(0.5) : CinevaColors.hairline,
            ),
          ),
          child: AnimatedSwitcher(
            duration: CinevaMotion.fast,
            switchInCurve: CinevaCurve.release,
            transitionBuilder: (Widget child, Animation<double> animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              icon,
              key: ValueKey<IconData>(icon),
              size: 22,
              color: active ? CinevaColors.gold : CinevaColors.textHigh,
            ),
          ),
        ),
      ),
    );
  }
}

/// Actions circulaires : Bande-annonce, Télécharger, Casting.
class DetailCircleActions extends StatelessWidget {
  const DetailCircleActions({
    super.key,
    required this.detail,
    required this.download,
    required this.hasTrailer,
    required this.onTrailer,
    required this.onDownload,
    required this.onCast,
  });

  final ContentDetailModel detail;
  final DownloadItemModel? download;
  final bool hasTrailer;
  final VoidCallback onTrailer;
  final VoidCallback onDownload;
  final VoidCallback onCast;

  @override
  Widget build(BuildContext context) {
    final bool downloadable = detail.resolveDownloadUrl() != null;
    final IconData downloadIcon = ContentDetailHelpers.downloadIcon(download);
    final String downloadLabel = download == null
        ? (downloadable ? 'Télécharger' : 'Indisponible')
        : detailDownloadStateLabel(download);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        if (hasTrailer)
          CinevaCircleAction(
            icon: Icons.smart_display_outlined,
            label: 'Bande-annonce',
            onPressed: onTrailer,
          ),
        CinevaCircleAction(
          icon: downloadIcon,
          label: downloadLabel,
          active: download?.isCompleted ?? false,
          progress: download != null && !download!.isCompleted && download!.progressPercent > 0
              ? download!.progressPercent
              : null,
          onPressed: downloadable || download != null ? onDownload : null,
        ),
        CinevaCircleAction(
          icon: Icons.people_outline_rounded,
          label: 'Casting',
          onPressed: onCast,
        ),
      ],
    );
  }
}

/// Synopsis replié sur 3 lignes, dépliable d'un appui.
class DetailSynopsis extends StatelessWidget {
  const DetailSynopsis({
    super.key,
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final String content = text.trim();
    if (content.isEmpty) return const SizedBox.shrink();
    final bool isLong = content.length > 190;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AnimatedSize(
          duration: CinevaMotion.medium,
          curve: CinevaCurve.decelerate,
          alignment: Alignment.topCenter,
          child: Text(
            content,
            maxLines: expanded || !isLong ? 12 : 3,
            overflow: expanded || !isLong ? TextOverflow.clip : TextOverflow.ellipsis,
            style: CinevaTypography.body,
          ),
        ),
        if (isLong) ...<Widget>[
          const SizedBox(height: CinevaSpacing.xs),
          CinevaPressable(
            pressedScale: 0.96,
            onTap: onToggle,
            semanticLabel: expanded ? 'Réduire le synopsis' : 'Lire tout le synopsis',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    expanded ? 'Moins' : 'Plus',
                    style: CinevaTypography.meta.copyWith(
                      color: CinevaColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 16,
                    color: CinevaColors.gold,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Reprise d'un film : progression + position exacte.
class DetailResumeCard extends StatelessWidget {
  const DetailResumeCard({super.key, required this.progress, required this.onResume});

  final PlaybackProgressModel progress;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CinevaColors.surface,
        borderRadius: BorderRadius.circular(CinevaRadii.card),
      ),
      child: CinevaPressable(
        pressedScale: 0.985,
        onTap: onResume,
        semanticLabel: 'Reprendre la lecture',
        child: Padding(
          padding: const EdgeInsets.all(CinevaSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.play_circle_outline_rounded,
                      size: 18, color: CinevaColors.gold),
                  const SizedBox(width: CinevaSpacing.xs),
                  Expanded(
                    child: Text(
                      'Reprendre',
                      style: CinevaTypography.cardTitle.copyWith(fontSize: 14),
                    ),
                  ),
                  Text(detailProgressLabel(progress), style: CinevaTypography.numeric),
                ],
              ),
              const SizedBox(height: CinevaSpacing.sm),
              CinevaProgressBar(value: progress.progressPercent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reprise d'une série : « Continuer S1 · Ép. 3 ».
class DetailSeriesResumeCard extends StatelessWidget {
  const DetailSeriesResumeCard({
    super.key,
    required this.detail,
    required this.progress,
    required this.onResume,
  });

  final ContentDetailModel detail;
  final PlaybackProgressModel progress;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final EpisodeModel? episode = _findEpisode(detail, progress.contentId);
    final String label = episode == null
        ? progress.content.title
        : 'S${episode.seasonNumber} · Ép. ${episode.episodeNumber} — ${episode.title}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CinevaColors.surface,
        borderRadius: BorderRadius.circular(CinevaRadii.card),
      ),
      child: CinevaPressable(
        pressedScale: 0.985,
        onTap: onResume,
        semanticLabel: 'Continuer $label',
        child: Padding(
          padding: const EdgeInsets.all(CinevaSpacing.sm),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 88,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(CinevaRadii.small),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        CinevaArtworkImage(
                          path: episode?.thumbnailPath ?? detail.backdropPath,
                          seed: progress.contentId,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(gradient: CinevaScrims.posterBottom),
                        ),
                        const Center(
                          child: Icon(Icons.play_arrow_rounded,
                              size: 22, color: CinevaColors.textHigh),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: CinevaSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Continuer',
                      style: CinevaTypography.overline.copyWith(color: CinevaColors.gold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CinevaTypography.cardTitle.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 7),
                    CinevaProgressBar(value: progress.progressPercent, height: 2.5),
                    const SizedBox(height: 5),
                    Text(
                      detailProgressLabel(progress),
                      style: CinevaTypography.numeric.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static EpisodeModel? _findEpisode(ContentDetailModel detail, String episodeId) {
    for (final SeasonModel season in detail.seasons) {
      for (final EpisodeModel episode in season.episodes) {
        if (episode.id == episodeId) return episode;
      }
    }
    return null;
  }
}

/// Informations détaillées : réalisation, casting, audio, sous-titres, poids.
class DetailInfoBlock extends StatelessWidget {
  const DetailInfoBlock({super.key, required this.detail});

  final ContentDetailModel detail;

  @override
  Widget build(BuildContext context) {
    final String size = detailDownloadSizeLabel(detail);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CinevaColors.surface,
        borderRadius: BorderRadius.circular(CinevaRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CinevaSpacing.md,
          vertical: CinevaSpacing.xs,
        ),
        child: Column(
          children: <Widget>[
            _InfoRow(label: 'Réalisation', value: detail.directorName),
            _InfoRow(label: 'Casting', value: detail.castNames.join(', ')),
            _InfoRow(label: 'Audio', value: detail.audioLanguages.join(', ')),
            _InfoRow(label: 'Sous-titres', value: detail.subtitleLanguages.join(', ')),
            if (size.isNotEmpty) _InfoRow(label: 'Téléchargement', value: size),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final String content = value.trim();
    if (content.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CinevaSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 104,
            child: Text(label, style: CinevaTypography.meta.copyWith(fontSize: 12)),
          ),
          Expanded(
            child: Text(
              content,
              style: CinevaTypography.bodyCompact.copyWith(
                fontSize: 13,
                color: CinevaColors.textHigh,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sélecteur de saisons (pills horizontales) pour les séries.
class DetailSeasonsHeader extends StatelessWidget {
  const DetailSeasonsHeader({
    super.key,
    required this.seasons,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<SeasonModel> seasons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CinevaSectionHeader(title: 'Saisons', actionLabel: '${seasons.length}'),
        const SizedBox(height: CinevaSpacing.xs),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast),
            itemCount: seasons.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: CinevaSpacing.xs),
            itemBuilder: (BuildContext context, int index) {
              final SeasonModel season = seasons[index];
              return CinevaChip(
                label: season.title.isEmpty
                    ? 'Saison ${season.seasonNumber}'
                    : season.title,
                selected: index == selectedIndex,
                onSelected: (_) => onSelected(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Rail « Contenus similaires » branché sur le repository.
class DetailSimilarRail extends ConsumerWidget {
  const DetailSimilarRail({super.key, required this.contentId});

  final String contentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ContentTileModel>> similar =
        ref.watch(similarContentProvider(contentId));
    final CinevaMetrics metrics = CinevaMetrics.of(context);
    final List<ContentTileModel> items = similar.valueOrNull ?? const <ContentTileModel>[];
    final double posterWidth = metrics.posterWidth;

    if (items.isEmpty) {
      return similar.isLoading
          ? SizedBox(
              height: (posterWidth * 1.5) + 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(width: CinevaSpacing.railGap),
                itemBuilder: (BuildContext context, int index) =>
                    CinevaSkeletonPoster(width: posterWidth),
              ),
            )
          : const SizedBox.shrink();
    }

    return CinevaRail(
      title: 'Dans le même esprit',
      itemHeight: (posterWidth * 1.5) + 46,
      itemCount: items.length,
      edgePadding: 0,
      itemBuilder: (BuildContext context, int index) {
        final ContentTileModel item = items[index];
        return CinevaMovieCard(
          item: item,
          width: posterWidth,
          onTap: () => context.pushReplacement(
            '/content/${Uri.encodeComponent(item.id)}',
          ),
        );
      },
    );
  }
}
