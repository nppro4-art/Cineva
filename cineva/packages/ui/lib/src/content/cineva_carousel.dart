import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

import '../primitives/cineva_section_header.dart';

/// Carrousel horizontal Cineva.
///
/// * physique de swipe naturelle et décélération franche, sans snapping
///   brutal (rien ne « saute ») ;
/// * gouttière alignée sur l'écran : la carte suivante dépasse toujours, ce
///   qui rend le swipe évident ;
/// * `cacheExtent` pour construire à l'avance les cartes qui arrivent, donc
///   aucun chargement visible pendant le geste ;
/// * `Clip.none` pour laisser l'agrandissement au toucher (1.03) et l'ombre
///   déborder sans être rognés.
class CinevaCarousel extends StatelessWidget {
  const CinevaCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemHeight,
    this.spacing = CinevaSpacing.railGap,
    this.edgePadding,
    this.verticalPadding = 8,
    this.cacheExtent = 420,
    this.controller,
    this.onScrollNotification,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final double itemHeight;
  final double spacing;

  /// Marge latérale (défaut : gouttière responsive de l'écran).
  final double? edgePadding;

  /// Réserve verticale pour l'agrandissement au toucher et l'ombre.
  final double verticalPadding;

  final double cacheExtent;
  final ScrollController? controller;
  final bool Function(ScrollNotification)? onScrollNotification;

  @override
  Widget build(BuildContext context) {
    final CinevaMetrics metrics = CinevaMetrics.of(context);
    final double pad = edgePadding ?? metrics.gutter;

    return SizedBox(
      height: itemHeight + (verticalPadding * 2),
      child: NotificationListener<ScrollNotification>(
        onNotification: onScrollNotification,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          controller: controller,
          clipBehavior: Clip.none,
          cacheExtent: cacheExtent,
          physics: const BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast),
          padding: EdgeInsets.only(
            left: pad,
            right: pad,
            top: verticalPadding,
            bottom: verticalPadding,
          ),
          itemCount: itemCount,
          itemBuilder: (BuildContext context, int index) {
            final Widget? child = itemBuilder(context, index);
            if (child == null) return const SizedBox.shrink();
            return Padding(
              padding: EdgeInsets.only(right: index == itemCount - 1 ? 0 : spacing),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

/// Section complète : en-tête + carrousel, alignés sur la même gouttière.
class CinevaRail extends StatelessWidget {
  const CinevaRail({
    super.key,
    required this.title,
    required this.itemHeight,
    required this.itemCount,
    required this.itemBuilder,
    this.overline,
    this.actionLabel,
    this.onAction,
    this.spacing = CinevaSpacing.railGap,
    this.edgePadding,
    this.bottomPadding = CinevaSpacing.sectionGap,
  });

  final String title;
  final String? overline;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double itemHeight;
  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final double spacing;
  final double? edgePadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final CinevaMetrics metrics = CinevaMetrics.of(context);
    final double pad = edgePadding ?? metrics.gutter;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(left: pad, right: pad),
              child: CinevaSectionHeader(
                title: title,
                overline: overline,
                actionLabel: actionLabel,
                onAction: onAction,
              ),
            ),
            CinevaCarousel(
              itemHeight: itemHeight,
              itemCount: itemCount,
              itemBuilder: itemBuilder,
              spacing: spacing,
              edgePadding: pad,
            ),
          ],
        ),
      ),
    );
  }
}
