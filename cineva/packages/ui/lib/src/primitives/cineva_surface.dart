import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

/// Fond d'écran Cineva : noir profond, jamais #000000 pur, avec un très léger
/// voile vertical pour éviter un aplat totalement mort.
class CinevaSurface extends StatelessWidget {
  const CinevaSurface({
    super.key,
    required this.child,
    this.color,
    this.gradient = true,
  });

  final Widget child;
  final Color? color;

  /// Ajoute un dégradé quasi imperceptible (désactivable dans le player).
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    if (color != null) {
      return ColoredBox(color: color!, child: child);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CinevaColors.ink,
        gradient: gradient
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF0A0A0B), CinevaColors.ink],
                stops: <double>[0, 0.55],
              )
            : null,
      ),
      child: child,
    );
  }
}

/// Carte : surface posée sur l'écran, sans bordure visible par défaut.
class CinevaCard extends StatelessWidget {
  const CinevaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CinevaSpacing.md),
    this.color = CinevaColors.card,
    this.borderRadius = CinevaRadii.cardBorder,
    this.border = false,
    this.onTap,
    this.shadow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final BorderRadius borderRadius;

  /// Liseré discret (uniquement quand la carte doit se détacher d'une image).
  final bool border;
  final VoidCallback? onTap;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: border ? Border.all(color: CinevaColors.hairline) : null,
        boxShadow: shadow ? CinevaShadows.card : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: Colors.transparent,
          highlightColor: CinevaColors.veil,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Scaffold d'écran Cineva : fond, safe areas et overlay système cohérent.
///
/// [extendBody] laisse le contenu passer sous la barre de navigation
/// (nécessaire pour les rails qui doivent « sortir » de l'écran).
class CinevaScreenScaffold extends StatelessWidget {
  const CinevaScreenScaffold({
    super.key,
    required this.body,
    this.bottomNavigation,
    this.floatingActionButton,
    this.extendBody = false,
    this.resizeToAvoidBottomInset = true,
    this.safeTop = true,
    this.backgroundColor,
  });

  final Widget body;
  final Widget? bottomNavigation;
  final Widget? floatingActionButton;
  final bool extendBody;
  final bool resizeToAvoidBottomInset;

  /// Applique la safe area haute (à désactiver quand un hero plein écran
  /// doit passer sous la barre d'état).
  final bool safeTop;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: CinevaTheme.overlay,
      child: Scaffold(
        backgroundColor: backgroundColor ?? CinevaColors.ink,
        extendBody: extendBody,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigation,
        body: SafeArea(
          top: safeTop,
          bottom: false,
          child: CinevaSurface(color: backgroundColor, child: body),
        ),
      ),
    );
  }
}

/// Séparateur horizontal quasi invisible.
class CinevaDivider extends StatelessWidget {
  const CinevaDivider({super.key, this.indent = 0, this.color = CinevaColors.hairline});

  final double indent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: Container(height: 1, color: color),
    );
  }
}
