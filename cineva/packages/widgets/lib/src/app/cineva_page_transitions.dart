import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Transitions de page Cineva.
///
/// Cohérentes et rapides : un fondu + une translation + un très léger zoom.
/// Jamais de changement brutal de route, jamais d'animation lente.
abstract final class CinevaPageTransitions {
  /// Pile standard (Accueil → Fiche, Profil → Réglages…).
  static CustomTransitionPage<void> push({
    required GoRouterState state,
    required Widget child,
    bool opaque = true,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      opaque: opaque,
      transitionDuration: CinevaMotion.page,
      reverseTransitionDuration: CinevaMotion.medium,
      transitionsBuilder: _fadeSlideUp,
    );
  }

  /// Fiche → lecteur : le visuel « s'agrandit » pendant que la page arrive.
  static CustomTransitionPage<void> player({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: CinevaMotion.player,
      reverseTransitionDuration: CinevaMotion.medium,
      transitionsBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        final Animation<double> curved = CurvedAnimation(
          parent: animation,
          curve: CinevaCurve.decelerate,
          reverseCurve: CinevaCurve.out,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.06, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Écrans modaux (plein écran, fond sombre).
  static CustomTransitionPage<void> modal({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: CinevaMotion.medium,
      reverseTransitionDuration: CinevaMotion.fast,
      transitionsBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        final Animation<double> curved = CurvedAnimation(
          parent: animation,
          curve: CinevaCurve.out,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Widget _fadeSlideUp(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animation<double> curved = CurvedAnimation(
      parent: animation,
      curve: CinevaCurve.decelerate,
      reverseCurve: CinevaCurve.out,
    );
    final Animation<double> outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: CinevaCurve.out,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
          child: FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0.86).animate(outgoing),
            child: child,
          ),
        ),
      ),
    );
  }
}
