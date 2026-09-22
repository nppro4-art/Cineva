import 'dart:async';

import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Enveloppe tactile Cineva : la seule source de retour au toucher.
///
/// Comportement :
/// * à l'appui, l'élément se réduit légèrement ([pressedScale]) en
///   [CinevaMotion.instant] ;
/// * au relâchement, il revient avec un très léger dépassement
///   ([CinevaCurve.release]) — jamais « élastique » ;
/// * aucune ondulation Material : le fond sombre ne supporte pas les ripples.
///
/// Utilise `onTapDown`/`onTapCancel` pour que l'état pressé soit annulé
/// proprement quand le geste devient un scroll.
class CinevaPressable extends StatefulWidget {
  const CinevaPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.enabled = true,
    this.haptic = true,
    this.hitSlop,
    this.semanticLabel,
    this.excludeFromSemantics = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Échelle appliquée pendant l'appui.
  final double pressedScale;

  final bool enabled;

  /// Retour haptique léger à l'appui.
  final bool haptic;

  final EdgeInsets? hitSlop;
  final String? semanticLabel;
  final bool excludeFromSemantics;

  @override
  State<CinevaPressable> createState() => _CinevaPressableState();
}

class _CinevaPressableState extends State<CinevaPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
    _setPressed(true);
    if (widget.haptic) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  void _handleTapCancel() => _setPressed(false);

  void _handleTapUp(TapUpDetails details) => _setPressed(false);

  void _handleTap() {
    if (!widget.enabled) return;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bool interactive = widget.enabled && (widget.onTap != null || widget.onLongPress != null);

    Widget child = AnimatedScale(
      scale: _pressed ? widget.pressedScale : 1,
      duration: _pressed ? CinevaMotion.instant : CinevaMotion.medium,
      curve: _pressed ? CinevaCurve.press : CinevaCurve.release,
      child: widget.child,
    );

    if (interactive) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap == null ? null : _handleTap,
        onLongPress: widget.onLongPress,
        child: child,
      );
    }

    if (widget.excludeFromSemantics || widget.semanticLabel == null) {
      return child;
    }

    return Semantics(
      button: interactive,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: child,
    );
  }
}

/// Variante « carte » : l'élément grandit très légèrement au toucher
/// (1.00 → 1.03) et gagne un halo discret, comme demandé pour les affiches.
class CinevaPressableCard extends StatefulWidget {
  const CinevaPressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = CinevaRadii.posterBorder,
    this.expandedScale = 1.03,
    this.halo = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;
  final double expandedScale;
  final bool halo;
  final String? semanticLabel;

  @override
  State<CinevaPressableCard> createState() => _CinevaPressableCardState();
}

class _CinevaPressableCardState extends State<CinevaPressableCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
        onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
        onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _pressed ? widget.expandedScale : 1,
          duration: _pressed ? CinevaMotion.instant : CinevaMotion.medium,
          curve: _pressed ? CinevaCurve.press : CinevaCurve.release,
          child: AnimatedContainer(
            duration: _pressed ? CinevaMotion.instant : CinevaMotion.medium,
            curve: CinevaCurve.out,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow:
                  _pressed && widget.halo ? CinevaShadows.touchHalo() : CinevaShadows.poster,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
