import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';

class CinevaArtwork extends StatelessWidget {
  const CinevaArtwork({
    super.key,
    required this.content,
    this.borderRadius = const BorderRadius.all(Radius.circular(CinevaRadii.medium)),
    this.fit = BoxFit.cover,
    this.showTypeBadge = false,
    this.useBackdrop = false,
    this.child,
  });

  final ContentTileModel content;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final bool showTypeBadge;
  final bool useBackdrop;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final path = useBackdrop ? (content.backdropPath ?? content.imagePath) : content.imagePath;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: CinevaArtworkPalette.gradientFor(content.id),
            ),
            child: _MaybeRemoteArtwork(
              path: path,
              fit: fit,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withOpacity(0.04),
                  Colors.black.withOpacity(0.14),
                  Colors.black.withOpacity(0.65),
                ],
              ),
            ),
          ),
          if (showTypeBadge)
            Positioned(
              top: CinevaSpacing.md,
              left: CinevaSpacing.md,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    content.badge,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
            ),
          if (path == null || path.startsWith('demo://'))
            Positioned(
              right: CinevaSpacing.md,
              bottom: CinevaSpacing.md,
              child: Icon(
                content.contentType == 'movie'
                    ? Icons.local_movies_rounded
                    : Icons.live_tv_rounded,
                size: 28,
                color: Colors.white.withOpacity(0.82),
              ),
            ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _MaybeRemoteArtwork extends StatefulWidget {
  const _MaybeRemoteArtwork({
    required this.path,
    required this.fit,
  });

  final String? path;
  final BoxFit fit;

  @override
  State<_MaybeRemoteArtwork> createState() => _MaybeRemoteArtworkState();
}

class _MaybeRemoteArtworkState extends State<_MaybeRemoteArtwork> {
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    if (path == null || path.isEmpty || path.startsWith('demo://')) {
      return const SizedBox.expand();
    }

    Widget image;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      image = Image.network(
        path,
        fit: widget.fit,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          final visible = wasSynchronouslyLoaded || frame != null;
          if (visible && !_loaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _loaded = true);
            });
          }
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 320),
            opacity: visible ? 1 : 0,
            child: child,
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const CinevaSkeleton(),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 320),
                opacity: _loaded ? 1 : 0,
                child: child,
              ),
            ],
          );
        },
        errorBuilder: (context, error, stackTrace) => const SizedBox.expand(),
      );
    } else {
      image = Image.asset(
        path,
        fit: widget.fit,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          final visible = wasSynchronouslyLoaded || frame != null;
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            opacity: visible ? 1 : 0,
            child: child,
          );
        },
        errorBuilder: (context, error, stackTrace) => const SizedBox.expand(),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (!_loaded) const CinevaSkeleton(),
        image,
      ],
    );
  }
}

/// Visuels de repli historiques : délègue au design system
/// (`CinevaArtworkGradients`) pour n'avoir qu'une seule source de vérité.
abstract final class CinevaArtworkPalette {
  static LinearGradient gradientFor(String seed) => CinevaArtworkGradients.forSeed(seed);
}
