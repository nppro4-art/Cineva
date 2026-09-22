import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

import '../primitives/cineva_pressable.dart';
import '../primitives/cineva_progress.dart';
import 'cineva_artwork_image.dart';
import 'cineva_content_labels.dart';

/// Affiche de film/série : ratio 2:3, coins légèrement arrondis, ombre très
/// subtile, titre et métadonnées en dessous.
///
/// Au toucher : la carte grandit de 1.00 à 1.03 en ~150 ms et gagne un halo
/// discret ([CinevaPressableCard]) — jamais un « hover » de desktop.
class CinevaMovieCard extends StatelessWidget {
  const CinevaMovieCard({
    super.key,
    required this.item,
    required this.width,
    this.onTap,
    this.onLongPress,
    this.heroTag,
    this.showLabel = true,
    this.badge,
    this.progressPercent,
    this.subtitleOverride,
  });

  final ContentTileModel item;
  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Tag de transition partagée (null = pas de Hero).
  final Object? heroTag;

  final bool showLabel;

  /// Pastille incrustée en haut à gauche (« TOP 10 », « NOUVEAUTÉ »…).
  final String? badge;

  /// Barre de reprise incrustée en bas de l'affiche.
  final double? progressPercent;

  final String? subtitleOverride;

  @override
  Widget build(BuildContext context) {
    final List<String> tokens = CinevaContentLabels.qualityTokens(item.badge);
    final String? quality = tokens.isEmpty ? null : tokens.take(2).join(' ');

    final Widget poster = _Poster(
      item: item,
      heroTag: heroTag,
      badge: badge ?? quality,
      progressPercent: progressPercent ?? item.progressPercent,
    );

    return SizedBox(
      width: width,
      child: CinevaPressableCard(
        onTap: onTap,
        onLongPress: onLongPress,
        semanticLabel: '${CinevaContentLabels.type(item.contentType)} ${item.title}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AspectRatio(aspectRatio: 2 / 3, child: poster),
            if (showLabel) ...<Widget>[
              const SizedBox(height: CinevaSpacing.xs),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CinevaTypography.cardTitle,
              ),
              const SizedBox(height: 3),
              Text(
                subtitleOverride ?? CinevaContentLabels.meta(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CinevaTypography.meta.copyWith(fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({
    required this.item,
    required this.heroTag,
    required this.badge,
    required this.progressPercent,
  });

  final ContentTileModel item;
  final Object? heroTag;
  final String? badge;
  final double? progressPercent;

  @override
  Widget build(BuildContext context) {
    final Widget artwork = CinevaArtworkImage.forTile(
      item,
      borderRadius: CinevaRadii.posterBorder,
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (heroTag == null)
          artwork
        else
          Hero(
            tag: heroTag!,
            flightShuttleBuilder: (
              BuildContext flightContext,
              Animation<double> animation,
              HeroFlightDirection flightDirection,
              BuildContext fromHeroContext,
              BuildContext toHeroContext,
            ) =>
                artwork,
            child: artwork,
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: CinevaRadii.posterBorder,
            gradient: CinevaScrims.posterBottom,
          ),
        ),
        if (badge != null)
          Positioned(
            top: 7,
            left: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x99000000),
                borderRadius: BorderRadius.circular(CinevaRadii.hair),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  fontSize: 8.5,
                  height: 1.2,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w700,
                  color: CinevaColors.textHigh,
                ),
              ),
            ),
          ),
        if (progressPercent != null && progressPercent! > 0)
          Positioned(
            left: 8,
            right: 8,
            bottom: 7,
            child: CinevaProgressBar(value: progressPercent!, height: 2.5),
          ),
      ],
    );
  }
}

/// Carte « Continuer à regarder » : backdrop 16:9, barre de progression
/// visible, titre et position restante. Un appui reprend la lecture là où
/// l'utilisateur s'est arrêté.
class CinevaContinueCard extends StatelessWidget {
  const CinevaContinueCard({
    super.key,
    required this.item,
    required this.width,
    required this.progress,
    this.onTap,
    this.onLongPress,
    this.heroTag,
  });

  final ContentTileModel item;
  final double width;
  final PlaybackProgressModel progress;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final int remaining = (progress.durationSeconds - progress.positionSeconds).clamp(0, 1 << 30);

    return SizedBox(
      width: width,
      child: CinevaPressableCard(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: CinevaRadii.cardBorder,
        semanticLabel: 'Reprendre ${item.title}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: CinevaRadii.cardBorder,
                    child: CinevaArtworkImage.forTile(item, useBackdrop: true),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: CinevaRadii.cardBorder,
                      gradient: CinevaScrims.posterBottom,
                    ),
                  ),
                  Positioned(
                    right: 9,
                    bottom: 9,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CinevaColors.textHigh.withOpacity(0.94),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 19,
                        color: CinevaColors.textOnLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CinevaSpacing.xs),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CinevaTypography.cardTitle,
            ),
            const SizedBox(height: 5),
            CinevaProgressBar(value: progress.progressPercent, height: 2.5),
            const SizedBox(height: 6),
            Text(
              remaining <= 60
                  ? 'Terminer'
                  : '${CinevaContentLabels.duration(remaining ~/ 60)} restant',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CinevaTypography.meta.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
