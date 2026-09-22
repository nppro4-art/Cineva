import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

/// Apparition d'un élément : fondu + translation + très léger zoom.
///
/// Utilisé pour l'entrée des sections, des résultats de recherche (avec un
/// décalage de [CinevaMotion.listStagger] entre deux éléments) et des textes
/// du hero.
class CinevaReveal extends StatefulWidget {
  const CinevaReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = CinevaMotion.medium,
    this.offsetY = 14,
    this.offsetX = 0,
    this.scale = 0.985,
    this.curve = CinevaCurve.decelerate,
    this.enabled = true,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;
  final double offsetX;
  final double scale;
  final Curve curve;

  /// À `false`, l'enfant est affiché immédiatement (réduction des animations).
  final bool enabled;

  @override
  State<CinevaReveal> createState() => _CinevaRevealState();
}

class _CinevaRevealState extends State<CinevaReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration + widget.delay,
  );

  late Animation<double> _animation = _buildAnimation();

  Animation<double> _buildAnimation() {
    final int total = _controller.duration?.inMilliseconds ?? 1;
    final int delay = widget.delay.inMilliseconds;
    if (delay <= 0 || total <= delay) {
      return CurvedAnimation(parent: _controller, curve: widget.curve);
    }
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(delay / total, 1, curve: widget.curve),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(CinevaReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.delay != widget.delay || oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration + widget.delay;
      _animation = _buildAnimation();
    }
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        _controller.forward(from: 0);
      } else {
        _controller.value = 1;
      }
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
      animation: _animation,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double value = _animation.value;
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
              (1 - value) * widget.offsetX,
              (1 - value) * widget.offsetY,
            ),
            child: Transform.scale(
              scale: widget.scale + ((1 - widget.scale) * value),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Révèle ses enfants en cascade, avec un décalage borné pour que la liste
/// n'ait jamais l'air lente (au-delà de [maxStaggered] les éléments
/// apparaissent ensemble).
class CinevaStagger extends StatelessWidget {
  const CinevaStagger({
    super.key,
    required this.children,
    this.step = CinevaMotion.listStagger,
    this.maxStaggered = 12,
    this.duration = CinevaMotion.medium,
    this.offsetY = 12,
    this.enabled = true,
  });

  final List<Widget> children;
  final Duration step;
  final int maxStaggered;
  final Duration duration;
  final double offsetY;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int index = 0; index < children.length; index++)
          CinevaReveal(
            delay: index < maxStaggered ? step * index : step * maxStaggered,
            duration: duration,
            offsetY: offsetY,
            enabled: enabled,
            child: children[index],
          ),
      ],
    );
  }
}
