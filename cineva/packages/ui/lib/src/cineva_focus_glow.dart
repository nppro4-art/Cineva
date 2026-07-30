import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

/// Surbrillance focus pour la navigation clavier / D-pad / TV / desktop.
/// S'utilise comme wrapper autour d'une carte ou d'un bouton pour obtenir
/// un liseré doré luxueux quand l'élément est focusé (télécommande, flèches).
class CinevaFocusGlow extends StatefulWidget {
  const CinevaFocusGlow({
    super.key,
    required this.child,
    this.radius = CinevaRadii.medium,
    this.glowColor,
  });

  final Widget child;
  final double radius;
  final Color? glowColor;

  @override
  State<CinevaFocusGlow> createState() => _CinevaFocusGlowState();
}

class _CinevaFocusGlowState extends State<CinevaFocusGlow> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.glowColor ?? CinevaColors.accentSoft;
    return Focus(
      focusNode: _focusNode,
      child: AnimatedBuilder(
        animation: _focusNode,
        builder: (context, child) {
          final focused = _focusNode.hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: focused
                  ? <BoxShadow>[
                      BoxShadow(
                        color: glow.withOpacity(0.55),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
              border: Border.all(
                color: focused ? glow.withOpacity(0.85) : Colors.transparent,
                width: focused ? 1.5 : 0,
              ),
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
