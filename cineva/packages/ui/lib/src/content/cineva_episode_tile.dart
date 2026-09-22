import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

import '../primitives/cineva_pressable.dart';
import '../primitives/cineva_progress.dart';
import 'cineva_artwork_image.dart';
import 'cineva_content_labels.dart';

/// Ligne d'épisode : vignette 16:9, titre, durée, progression et action.
class CinevaEpisodeTile extends StatelessWidget {
  const CinevaEpisodeTile({
    super.key,
    required this.episode,
    required this.onTap,
    this.progress,
    this.thumbnailPath,
    this.onDownload,
    this.downloadState,
    this.showSynopsis = true,
  });

  final EpisodeModel episode;
  final VoidCallback onTap;

  /// Progression déjà visionnée (null = jamais lancé).
  final PlaybackProgressModel? progress;

  /// Vignette de repli si l'épisode n'en fournit pas.
  final String? thumbnailPath;

  final VoidCallback? onDownload;

  /// Icône d'état du téléchargement.
  final IconData? downloadState;

  final bool showSynopsis;

  @override
  Widget build(BuildContext context) {
    final double percent = progress?.progressPercent ?? 0;
    final bool seen = progress?.isCompleted ?? false;
    final String? thumb = episode.thumbnailPath ?? thumbnailPath;

    return CinevaPressable(
      pressedScale: 0.985,
      onTap: onTap,
      semanticLabel: 'Lire ${episode.label} ${episode.title}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CinevaSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 122,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(CinevaRadii.small),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _EpisodeThumb(path: thumb, seed: episode.id),
                      const DecoratedBox(
                        decoration: BoxDecoration(gradient: CinevaScrims.posterBottom),
                      ),
                      Center(
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xB3000000),
                            border: Border.all(color: const Color(0x33FFFFFF)),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 18,
                            color: CinevaColors.textHigh,
                          ),
                        ),
                      ),
                      if (percent > 0 && !seen)
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 5,
                          child: CinevaProgressBar(value: percent, height: 2.5),
                        ),
                      if (seen)
                        const Positioned(
                          right: 5,
                          top: 5,
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: CinevaColors.success,
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
                    episode.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CinevaTypography.cardTitle.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Ép. ${episode.episodeNumber} · ${episode.durationMinutes} min',
                    style: CinevaTypography.meta.copyWith(fontSize: 11.5),
                  ),
                  if (showSynopsis) ...<Widget>[
                    const SizedBox(height: 5),
                    Text(
                      CinevaContentLabels.clampText(episode.synopsis, maxChars: 96),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CinevaTypography.bodyCompact.copyWith(
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onDownload != null || downloadState != null) ...<Widget>[
              const SizedBox(width: CinevaSpacing.xs),
              CinevaPressable(
                pressedScale: 0.88,
                onTap: onDownload,
                semanticLabel: 'Télécharger ${episode.label}',
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    downloadState ?? Icons.download_rounded,
                    size: 20,
                    color: CinevaColors.textSoft,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EpisodeThumb extends StatelessWidget {
  const _EpisodeThumb({required this.path, required this.seed});

  final String? path;
  final String seed;

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty || path!.startsWith('demo://')) {
      return DecoratedBox(
        decoration: BoxDecoration(gradient: CinevaArtworkGradients.forSeed(seed)),
      );
    }
    return CinevaArtworkImage(path: path, seed: seed);
  }
}
