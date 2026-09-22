import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

/// Destination de la barre de navigation basse.
@immutable
class CinevaNavDestination {
  const CinevaNavDestination({
    required this.label,
    required this.icon,
    this.activeIcon,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final IconData? activeIcon;

  /// Pastille de compteur (téléchargements en cours, par exemple).
  final int badgeCount;
}

/// Barre de navigation Cineva.
///
/// * surface sombre élevée, quasi opaque, liseré supérieur de 1 px — pas de
///   flou (un `BackdropFilter` permanent coûterait des images par seconde) ;
/// * respecte la safe area basse (geste iOS, barre Android) ;
/// * à la sélection : l'icône bascule et gagne un léger rebond, le libellé
///   apparaît en fondu + translation, un point doré se déploie sous l'icône.
class CinevaBottomNavigation extends StatelessWidget {
  const CinevaBottomNavigation({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.backgroundOpacity = 0.97,
  });

  final List<CinevaNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Opacité de la surface (0 = totalement transparent).
  final double backgroundOpacity;

  /// Espace à réserver en bas d'un contenu qui passe sous la barre
  /// (`Scaffold.extendBody = true`) : hauteur de barre + safe area + marge.
  static double clearance(BuildContext context, {double extra = CinevaSpacing.xl}) {
    return CinevaMetrics.of(context).bottomNavHeight +
        MediaQuery.viewPaddingOf(context).bottom +
        extra;
  }

  @override
  Widget build(BuildContext context) {
    final CinevaMetrics metrics = CinevaMetrics.of(context);
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CinevaColors.surface.withOpacity(backgroundOpacity),
          border: const Border(top: CinevaEdges.hairlineTop),
          boxShadow: CinevaShadows.nav,
        ),
        child: SizedBox(
          height: metrics.bottomNavHeight + bottomInset,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Row(
              children: <Widget>[
                for (int index = 0; index < destinations.length; index++)
                  Expanded(
                    child: _NavItem(
                      destination: destinations[index],
                      selected: index == currentIndex,
                      onTap: () => onDestinationSelected(index),
                      height: metrics.bottomNavHeight,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.height,
  });

  final CinevaNavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected ? CinevaColors.textHigh : CinevaColors.textFaint;
    final IconData icon = selected
        ? (destination.activeIcon ?? destination.icon)
        : destination.icon;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: _NavPressSurface(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedScale(
                scale: selected ? 1.08 : 1,
                duration: CinevaMotion.medium,
                curve: CinevaCurve.release,
                child: AnimatedSwitcher(
                  duration: CinevaMotion.fast,
                  switchInCurve: CinevaCurve.out,
                  switchOutCurve: CinevaCurve.inOut,
                  transitionBuilder: (Widget child, Animation<double> animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: Stack(
                    key: ValueKey<IconData>(icon),
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Icon(icon, size: 23, color: foreground),
                      if (destination.badgeCount > 0)
                        Positioned(
                          right: -7,
                          top: -3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            constraints: const BoxConstraints(minWidth: 15),
                            decoration: BoxDecoration(
                              color: CinevaColors.gold,
                              borderRadius: BorderRadius.circular(CinevaRadii.chip),
                            ),
                            child: Text(
                              destination.badgeCount > 9
                                  ? '9+'
                                  : '${destination.badgeCount}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 9,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                                color: CinevaColors.textOnLight,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: CinevaMotion.medium,
                curve: CinevaCurve.out,
                width: selected ? 14 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: CinevaColors.gold,
                  borderRadius: BorderRadius.circular(CinevaRadii.chip),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedOpacity(
                duration: CinevaMotion.medium,
                curve: CinevaCurve.out,
                opacity: selected ? 1 : 0,
                child: AnimatedSlide(
                  duration: CinevaMotion.medium,
                  curve: CinevaCurve.decelerate,
                  offset: selected ? Offset.zero : const Offset(0, 0.35),
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: CinevaTypography.navLabel.copyWith(color: foreground),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Réaction au toucher : léger éclaircissement de la zone, sans ripple.
class _NavPressSurface extends StatefulWidget {
  const _NavPressSurface({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_NavPressSurface> createState() => _NavPressSurfaceState();
}

class _NavPressSurfaceState extends State<_NavPressSurface> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: CinevaMotion.instant,
        color: _pressed ? CinevaColors.veil : Colors.transparent,
        child: widget.child,
      ),
    );
  }
}
