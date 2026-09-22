import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';

/// Skeleton de l'accueil : même structure que la page réelle (hero + rails),
/// placeholders sombres et shimmer très discret. Jamais d'écran blanc ni de
/// spinner générique.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final CinevaMetrics metrics = CinevaMetrics.of(context);
    final double posterWidth = metrics.posterWidth;
    final double continueWidth = metrics.continueWidth;
    final double bottom = CinevaBottomNavigation.clearance(context);

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: <Widget>[
        SizedBox(height: metrics.topInset + metrics.brandHeaderHeight),
        SizedBox(
          height: metrics.heroHeight,
          child: const CinevaSkeleton(
            borderRadius: BorderRadius.all(Radius.circular(0)),
          ),
        ),
        const SizedBox(height: CinevaSpacing.xxl),
        _SkeletonRailHeader(gutter: metrics.gutter),
        const SizedBox(height: CinevaSpacing.md),
        SizedBox(
          height: (continueWidth * 9 / 16) + 56,
          child: _SkeletonRow(
            gutter: metrics.gutter,
            itemWidth: continueWidth,
            backdrop: true,
          ),
        ),
        const SizedBox(height: CinevaSpacing.lg),
        for (int index = 0; index < 3; index++) ...<Widget>[
          _SkeletonRailHeader(gutter: metrics.gutter),
          const SizedBox(height: CinevaSpacing.md),
          SizedBox(
            height: (posterWidth * 1.5) + 46,
            child: _SkeletonRow(
              gutter: metrics.gutter,
              itemWidth: posterWidth,
            ),
          ),
          const SizedBox(height: CinevaSpacing.xl),
        ],
        SizedBox(height: bottom),
      ],
    );
  }
}

class _SkeletonRailHeader extends StatelessWidget {
  const _SkeletonRailHeader({required this.gutter});

  final double gutter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: CinevaSkeleton(
        height: 14,
        width: 150,
        borderRadius: BorderRadius.circular(CinevaRadii.hair),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({
    required this.gutter,
    required this.itemWidth,
    this.backdrop = false,
  });

  final double gutter;
  final double itemWidth;
  final bool backdrop;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: gutter),
      itemCount: 6,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(width: CinevaSpacing.railGap),
      itemBuilder: (BuildContext context, int index) {
        if (backdrop) {
          return SizedBox(
            width: itemWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: const CinevaSkeleton(borderRadius: CinevaRadii.cardBorder),
                ),
                const SizedBox(height: CinevaSpacing.xs),
                CinevaSkeleton(
                  height: 10,
                  width: itemWidth * 0.6,
                  borderRadius: BorderRadius.circular(CinevaRadii.hair),
                ),
              ],
            ),
          );
        }
        return CinevaSkeletonPoster(width: itemWidth);
      },
    );
  }
}
