import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

/// Conteneur d'écran historique : fond sombre + safe areas.
///
/// Les nouveaux écrans Cineva utilisent `CinevaScreenScaffold` / `CinevaSurface`
/// (voir `primitives/cineva_surface.dart`). Celui-ci reste pour la console
/// d'administration et les écrans non refondus.
class CinevaScaffoldContainer extends StatelessWidget {
  const CinevaScaffoldContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CinevaSpacing.lg),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF0A0A0B), CinevaColors.ink],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: <double>[0, 0.55],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
