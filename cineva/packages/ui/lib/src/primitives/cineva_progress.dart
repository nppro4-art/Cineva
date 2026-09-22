import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

/// Barre de progression fine (reprise de lecture, téléchargement).
class CinevaProgressBar extends StatelessWidget {
  const CinevaProgressBar({
    super.key,
    required this.value,
    this.height = 3,
    this.activeColor = CinevaColors.gold,
    this.trackColor = const Color(0x33FFFFFF),
    this.radius = CinevaRadii.chip,
    this.animate = true,
  });

  /// Progression de 0 à 1.
  final double value;
  final double height;
  final Color activeColor;
  final Color trackColor;
  final double radius;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final double fraction = value.clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: trackColor),
            AnimatedFractionallySizedBox(
              duration: animate ? CinevaMotion.medium : Duration.zero,
              curve: CinevaCurve.out,
              widthFactor: fraction,
              alignment: Alignment.centerLeft,
              child: ColoredBox(color: activeColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progression annulaire indéterminée très fine (chargements discrets).
class CinevaSpinner extends StatelessWidget {
  const CinevaSpinner({
    super.key,
    this.size = 22,
    this.strokeWidth = 2.2,
    this.color = CinevaColors.gold,
  });

  final double size;
  final double strokeWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: strokeWidth, color: color),
    );
  }
}
