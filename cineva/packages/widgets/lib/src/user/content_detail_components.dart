part of 'content_detail_screen.dart';

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.detail,
    required this.progress,
    required this.download,
    required this.isFavorite,
    required this.onPlay,
    required this.onDownload,
    required this.onFavorite,
  });

  final ContentDetailModel detail;
  final PlaybackProgressModel? progress;
  final DownloadItemModel? download;
  final bool isFavorite;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        SizedBox(
          width: 220,
          child: CinevaPrimaryButton(
            label: progress == null ? 'Lecture' : 'Reprendre',
            icon: Icons.play_arrow_rounded,
            onPressed: onPlay,
          ),
        ),
        SizedBox(
          width: 220,
          child: CinevaPrimaryButton(
            label: ContentDetailHelpers.downloadLabel(download),
            icon: ContentDetailHelpers.downloadIcon(download),
            onPressed: onDownload,
          ),
        ),
        SizedBox(
          width: 220,
          child: CinevaPrimaryButton(
            label: isFavorite ? 'Retirer de ma liste' : 'Ma liste',
            icon: isFavorite ? Icons.check_rounded : Icons.add_rounded,
            onPressed: onFavorite,
          ),
        ),
      ],
    );
  }
}

class _SeriesSeasonControls extends StatelessWidget {
  const _SeriesSeasonControls({
    required this.detail,
    required this.selectedSeasonIndex,
    required this.onSeasonSelected,
    required this.onResume,
    required this.onStartSeason,
    required this.onRandomEpisode,
  });

  final ContentDetailModel detail;
  final int selectedSeasonIndex;
  final ValueChanged<int> onSeasonSelected;
  final VoidCallback? onResume;
  final VoidCallback? onStartSeason;
  final VoidCallback onRandomEpisode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const CinevaSectionTitle(title: 'Saisons et épisodes'),
        const SizedBox(height: CinevaSpacing.md),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List<Widget>.generate(
            detail.seasons.length,
            (index) => ChoiceChip(
              label: Text(detail.seasons[index].title),
              selected: selectedSeasonIndex == index,
              onSelected: (_) => onSeasonSelected(index),
            ),
          ),
        ),
        const SizedBox(height: CinevaSpacing.lg),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            if (onResume != null)
              SizedBox(
                width: 220,
                child: CinevaPrimaryButton(
                  label: 'Reprendre',
                  icon: Icons.play_circle_fill_rounded,
                  onPressed: onResume,
                ),
              ),
            if (onStartSeason != null)
              SizedBox(
                width: 220,
                child: CinevaPrimaryButton(
                  label: 'Commencer la saison',
                  icon: Icons.skip_next_rounded,
                  onPressed: onStartSeason,
                ),
              ),
            SizedBox(
              width: 220,
              child: CinevaPrimaryButton(
                label: 'Lecture aléatoire',
                icon: Icons.shuffle_rounded,
                onPressed: onRandomEpisode,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.progress,
    required this.onTap,
  });

  final EpisodeModel episode;
  final PlaybackProgressModel? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final seen = progress?.isCompleted ?? false;
    final percent = progress?.progressPercent ?? 0;

    return Semantics(
      button: true,
      label: 'Lire ${episode.label} ${episode.title}',
      value: seen ? 'Épisode déjà vu' : '${(percent * 100).round()} pour cent visionné',
      child: InkWell(
        borderRadius: BorderRadius.circular(CinevaRadii.medium),
        onTap: onTap,
        child: CinevaGlassCard(
          child: Row(
            children: <Widget>[
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(CinevaRadii.medium),
                  gradient: CinevaArtworkPalette.gradientFor(episode.id),
                ),
                child: Center(
                  child: Text(
                    episode.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: CinevaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: Text(episode.title, style: Theme.of(context).textTheme.titleMedium)),
                        if (seen) const Icon(Icons.check_circle_rounded, color: CinevaColors.success),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${episode.label} • ${episode.durationMinutes} min',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      episode.synopsis,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(value: percent, backgroundColor: CinevaColors.surfaceRaised),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CinevaSpacing.sm),
              const Icon(Icons.play_circle_fill_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: CinevaGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: CinevaSpacing.sm),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CinevaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CinevaColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(label),
      ),
    );
  }
}
