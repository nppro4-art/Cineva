part of 'library_screen.dart';

/// Sélecteur d'onglets de la bibliothèque : deux segments, indicateur glissant.
class LibraryTabs extends StatelessWidget {
  const LibraryTabs({
    super.key,
    required this.tab,
    required this.listCount,
    required this.resumeCount,
    required this.onChanged,
  });

  final LibraryTab tab;
  final int listCount;
  final int resumeCount;
  final ValueChanged<LibraryTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double half = width / 2;

        return Container(
          height: 42,
          decoration: BoxDecoration(
            color: CinevaColors.surface,
            borderRadius: BorderRadius.circular(CinevaRadii.chip),
          ),
          child: Stack(
            children: <Widget>[
              AnimatedPositioned(
                duration: CinevaMotion.medium,
                curve: CinevaCurve.decelerate,
                left: tab == LibraryTab.list ? 3 : half + 1,
                top: 3,
                bottom: 3,
                width: half - 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: CinevaColors.raised,
                    borderRadius: BorderRadius.circular(CinevaRadii.chip),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _TabButton(
                      label: 'Ma liste',
                      icon: Icons.playlist_add_check_rounded,
                      count: listCount,
                      selected: tab == LibraryTab.list,
                      onTap: () => onChanged(LibraryTab.list),
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      label: 'Reprendre',
                      icon: Icons.play_circle_outline_rounded,
                      count: resumeCount,
                      selected: tab == LibraryTab.resume,
                      onTap: () => onChanged(LibraryTab.resume),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? CinevaColors.gold : CinevaColors.textSoft;

    return CinevaPressable(
      pressedScale: 0.98,
      onTap: onTap,
      semanticLabel: '$label, $count',
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedSwitcher(
              duration: CinevaMotion.fast,
              child: Icon(icon, key: ValueKey<bool>(selected), size: 15, color: color),
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: CinevaMotion.fast,
              curve: CinevaCurve.out,
              style: CinevaTypography.button.copyWith(
                fontSize: 12.5,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label),
            ),
            if (count > 0) ...<Widget>[
              const SizedBox(width: 5),
              Text('$count', style: CinevaTypography.numeric.copyWith(fontSize: 10.5, color: color)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Filtres de type dans « Ma liste ».
class LibraryTypeFilters extends StatelessWidget {
  const LibraryTypeFilters({
    super.key,
    required this.moviesOnly,
    required this.seriesOnly,
    required this.onMovies,
    required this.onSeries,
  });

  final bool moviesOnly;
  final bool seriesOnly;
  final VoidCallback onMovies;
  final VoidCallback onSeries;

  @override
  Widget build(BuildContext context) {
    return CinevaChipRow(
      dense: true,
      children: <Widget>[
        CinevaChip(
          label: 'Tous',
          dense: true,
          selected: !moviesOnly && !seriesOnly,
          onSelected: (_) {
            if (moviesOnly) onMovies();
            if (seriesOnly) onSeries();
          },
        ),
        CinevaChip(
          label: 'Films',
          dense: true,
          icon: Icons.movie_outlined,
          selected: moviesOnly,
          onSelected: (_) => onMovies(),
        ),
        CinevaChip(
          label: 'Séries',
          dense: true,
          icon: Icons.live_tv_rounded,
          selected: seriesOnly,
          onSelected: (_) => onSeries(),
        ),
      ],
    );
  }
}

/// État vide : icône discrète, titre, message, retour au catalogue.
class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: CinevaSpacing.xl),
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: CinevaColors.surface,
          ),
          child: const Icon(
            Icons.playlist_add_rounded,
            size: 24,
            color: CinevaColors.textFaint,
          ),
        ),
        const SizedBox(height: CinevaSpacing.lg),
        Text(title, style: CinevaTypography.sectionTitle.copyWith(fontSize: 16)),
        const SizedBox(height: CinevaSpacing.xs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: CinevaTypography.bodyCompact,
        ),
        const SizedBox(height: CinevaSpacing.xl),
        CinevaSecondaryButton(
          label: actionLabel,
          icon: Icons.arrow_forward_rounded,
          expanded: false,
          onPressed: onAction,
        ),
      ],
    );
  }
}

/// Rappel discret : des lectures sont en cours, basculer vers « Reprendre ».
class ResumeHintCard extends StatelessWidget {
  const ResumeHintCard({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CinevaPressable(
      pressedScale: 0.985,
      onTap: onTap,
      semanticLabel: 'Voir les $count lectures en cours',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CinevaColors.surface,
          borderRadius: BorderRadius.circular(CinevaRadii.card),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CinevaSpacing.md,
            vertical: CinevaSpacing.sm + 2,
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.play_circle_outline_rounded,
                  size: 18, color: CinevaColors.gold),
              const SizedBox(width: CinevaSpacing.sm),
              Expanded(
                child: Text(
                  count == 1 ? '1 lecture en cours' : '$count lectures en cours',
                  style: CinevaTypography.cardTitle.copyWith(fontSize: 13.5),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: CinevaColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne « Reprendre » : vignette 16:9 avec progression, titre, position.
class ResumeRow extends StatelessWidget {
  const ResumeRow({
    super.key,
    required this.progress,
    required this.onPlay,
    required this.onTap,
    required this.onLongPress,
  });

  final PlaybackProgressModel progress;
  final VoidCallback onPlay;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final ContentTileModel content = progress.content;
    final int remaining = progress.durationSeconds - progress.positionSeconds;
    final String position = AppFormatters.formatDuration(progress.positionSeconds);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CinevaColors.surface,
        borderRadius: BorderRadius.circular(CinevaRadii.card),
      ),
      child: CinevaPressable(
        pressedScale: 0.985,
        onTap: onTap,
        onLongPress: onLongPress,
        semanticLabel:
            'Reprendre ${content.title} à $position, ${AppFormatters.formatEta(remaining)} restant',
        child: Padding(
          padding: const EdgeInsets.all(CinevaSpacing.sm),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 112,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(CinevaRadii.small),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        RepaintBoundary(
                          child: CinevaArtworkImage.forTile(content, useBackdrop: true),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(gradient: CinevaScrims.posterBottom),
                        ),
                        Center(
                          child: CinevaPressable(
                            pressedScale: 0.9,
                            onTap: onPlay,
                            semanticLabel: 'Lire ${content.title}',
                            child: const Icon(Icons.play_arrow_rounded,
                                size: 26, color: CinevaColors.textHigh),
                          ),
                        ),
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 5,
                          child: CinevaProgressBar(
                            value: progress.progressPercent,
                            height: 2.5,
                          ),
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
                      CinevaContentLabels.type(content.contentType).toUpperCase(),
                      style: CinevaTypography.overline.copyWith(
                        fontSize: 9,
                        color: CinevaColors.gold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      content.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CinevaTypography.cardTitle.copyWith(fontSize: 13.5),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      remaining > 0
                          ? '$position · ${AppFormatters.formatEta(remaining)} restant'
                          : position,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CinevaTypography.numeric.copyWith(
                        fontSize: 10.5,
                        color: CinevaColors.textFaint,
                      ),
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
}
