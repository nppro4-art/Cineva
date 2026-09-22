import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

import '../primitives/cineva_skeleton.dart';

/// Image de contenu Cineva : chargement progressif, cache, lazy-load,
/// placeholder sombre, fondu très court à l'arrivée de l'image.
///
/// Règles :
/// * aucune image 4K décodée pour une vignette — `cacheWidth` est calculé
///   depuis la largeur réelle du widget et la densité de l'écran ;
/// * un chemin absent ou `demo://` (catalogue de démonstration) affiche un
///   dégradé sombre déterministe, jamais une couleur saturée ;
/// * une image en échec retombe sur le même dégradé (aucun cadre rouge).
class CinevaArtworkImage extends StatelessWidget {
  const CinevaArtworkImage({
    super.key,
    required this.path,
    this.seed,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.showPlaceholder = true,
    this.watermark,
    this.maxCacheWidth,
  });

  /// Construit directement depuis une tuile de contenu.
  factory CinevaArtworkImage.forTile(
    ContentTileModel item, {
    bool useBackdrop = false,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    bool showPlaceholder = true,
    Widget? watermark,
    Key? key,
  }) {
    final String? path = useBackdrop
        ? (item.backdropPath ?? item.imagePath)
        : (item.imagePath ?? item.backdropPath);
    return CinevaArtworkImage(
      key: key,
      path: path,
      seed: item.id,
      fit: fit,
      borderRadius: borderRadius,
      showPlaceholder: showPlaceholder,
      watermark: watermark ?? _IconForContent(item.contentType),
    );
  }

  /// Construit depuis une fiche contenu.
  factory CinevaArtworkImage.forDetail(
    ContentDetailModel detail, {
    bool useBackdrop = true,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    bool showPlaceholder = true,
    Key? key,
  }) {
    final String? path = useBackdrop
        ? (detail.backdropPath ?? detail.posterPath)
        : (detail.posterPath ?? detail.backdropPath);
    return CinevaArtworkImage(
      key: key,
      path: path,
      seed: detail.id,
      fit: fit,
      borderRadius: borderRadius,
      showPlaceholder: showPlaceholder,
      watermark: _IconForContent(detail.contentType),
    );
  }

  final String? path;

  /// Graine du dégradé de repli (identifiant du contenu).
  final String? seed;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool showPlaceholder;

  /// Icône discrète affichée sur le repli (type de contenu).
  final Widget? watermark;

  /// Plafond de largeur de décodage (px physiques).
  final int? maxCacheWidth;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            return _buildImage(context, width);
          },
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, double availableWidth) {
    final String raw = (path ?? '').trim();
    final bool usable = raw.isNotEmpty && !raw.startsWith('demo://');

    if (!usable) {
      return _Fallback(seed: seed ?? raw, watermark: watermark);
    }

    final int? cacheWidth = _resolveCacheWidth(context, availableWidth);

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return Image.network(
        raw,
        fit: fit,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        frameBuilder: (
          BuildContext context,
          Widget child,
          int? frame,
          bool wasSynchronouslyLoaded,
        ) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            duration: CinevaMotion.medium,
            curve: CinevaCurve.out,
            opacity: frame == null ? 0 : 1,
            child: child,
          );
        },
        loadingBuilder: (
          BuildContext context,
          Widget child,
          ImageChunkEvent? loadingProgress,
        ) {
          if (loadingProgress == null) return child;
          if (!showPlaceholder) return const SizedBox.expand();
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _Fallback(seed: seed ?? raw, watermark: null),
              const CinevaSkeleton(borderRadius: BorderRadius.all(Radius.circular(0))),
            ],
          );
        },
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
            _Fallback(seed: seed ?? raw, watermark: watermark),
      );
    }

    return Image.asset(
      raw,
      fit: fit,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.medium,
      frameBuilder: (
        BuildContext context,
        Widget child,
        int? frame,
        bool wasSynchronouslyLoaded,
      ) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          duration: CinevaMotion.medium,
          curve: CinevaCurve.out,
          opacity: frame == null ? 0 : 1,
          child: child,
        );
      },
      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
          _Fallback(seed: seed ?? raw, watermark: watermark),
    );
  }

  /// Largeur de décodage : largeur réelle du widget × densité de l'écran,
  /// plafonnée. Une vignette de rail n'est donc jamais décodée en pleine
  /// résolution (`cacheWidth` agit sur le décodage et la mémoire ; la
  /// réduction du poids réseau relève du CDN/Supabase).
  int? _resolveCacheWidth(BuildContext context, double availableWidth) {
    if (maxCacheWidth != null) return maxCacheWidth;
    final double ratio = MediaQuery.devicePixelRatioOf(context);
    final int target = (availableWidth * ratio).ceil();
    if (target <= 0) return null;
    return target > 1600 ? 1600 : target;
  }
}

class _IconForContent extends StatelessWidget {
  const _IconForContent(this.contentType);

  final String contentType;

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (contentType) {
      'movie' => Icons.movie_rounded,
      'series' => Icons.live_tv_rounded,
      'episode' => Icons.play_circle_outline_rounded,
      _ => Icons.local_movies_rounded,
    };
    return Icon(icon, size: 30, color: const Color(0x33FFFFFF));
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.seed, this.watermark});

  final String seed;
  final Widget? watermark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: seed.isEmpty ? CinevaArtworkGradients.neutral : CinevaArtworkGradients.forSeed(seed),
      ),
      child: Center(
        child: watermark ?? const SizedBox.shrink(),
      ),
    );
  }
}
