import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

/// Placeholder de chargement Cineva : surface sombre + shimmer très discret.
///
/// Le shimmer est volontairement faible (4 % de blanc) : on doit percevoir un
/// chargement, pas un effet lumineux. L'animation s'arrête si l'utilisateur a
/// demandé la réduction des animations du système.
class CinevaSkeleton extends StatefulWidget {
  const CinevaSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(CinevaRadii.medium)),
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxShape shape;

  @override
  State<CinevaSkeleton> createState() => _CinevaSkeletonState();
}

class _CinevaSkeletonState extends State<CinevaSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: CinevaMotion.shimmer,
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    if (reduce) {
      _controller.stop();
      _controller.value = 0;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double shift = (_controller.value * 2.4) - 1.2;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: CinevaColors.card,
            borderRadius: widget.shape == BoxShape.circle ? null : widget.borderRadius,
            shape: widget.shape,
            gradient: LinearGradient(
              begin: Alignment(shift, -0.4),
              end: Alignment(shift + 1.1, 0.4),
              colors: const <Color>[
                Color(0x00FFFFFF),
                Color(0x0AFFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: const <double>[0.15, 0.5, 0.85],
            ),
          ),
        );
      },
    );
  }
}

/// Placeholder d'affiche (2:3) avec le titre fantôme en dessous.
class CinevaSkeletonPoster extends StatelessWidget {
  const CinevaSkeletonPoster({super.key, required this.width, this.showLabel = true});

  final double width;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 2 / 3,
            child: const CinevaSkeleton(borderRadius: CinevaRadii.posterBorder),
          ),
          if (showLabel) ...<Widget>[
            const SizedBox(height: CinevaSpacing.xs),
            CinevaSkeleton(
              height: 10,
              width: width * 0.78,
              borderRadius: BorderRadius.circular(CinevaRadii.hair),
            ),
            const SizedBox(height: 5),
            CinevaSkeleton(
              height: 8,
              width: width * 0.5,
              borderRadius: BorderRadius.circular(CinevaRadii.hair),
            ),
          ],
        ],
      ),
    );
  }
}

/// Placeholder d'un rail complet (titre + N affiches).
class CinevaSkeletonRail extends StatelessWidget {
  const CinevaSkeletonRail({
    super.key,
    required this.posterWidth,
    this.itemCount = 4,
    this.titleWidth = 170,
  });

  final double posterWidth;
  final int itemCount;
  final double titleWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CinevaSkeleton(
          height: 14,
          width: titleWidth,
          borderRadius: BorderRadius.circular(CinevaRadii.hair),
        ),
        const SizedBox(height: CinevaSpacing.md),
        SizedBox(
          height: posterWidth * 1.5 + 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: CinevaSpacing.railGap),
            itemBuilder: (BuildContext context, int index) =>
                CinevaSkeletonPoster(width: posterWidth),
          ),
        ),
      ],
    );
  }
}

/// Placeholder du hero.
class CinevaSkeletonHero extends StatelessWidget {
  const CinevaSkeletonHero({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const CinevaSkeleton(borderRadius: BorderRadius.all(Radius.circular(0))),
    );
  }
}
