import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

/// Fond animé et subtil (luxueux, minimaliste) : dégradés circulaires
/// très légers qui dérivent lentement pour éviter une UI statique.
class CinevaAmbientBackdrop extends StatefulWidget {
  const CinevaAmbientBackdrop({super.key, this.accent});

  final Color? accent;

  @override
  State<CinevaAmbientBackdrop> createState() => _CinevaAmbientBackdropState();
}

class _CinevaAmbientBackdropState extends State<CinevaAmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  )..repeat(reverse: true);

  late final Animation<Alignment> _a1 = Tween<Alignment>(
    begin: const Alignment(-0.9, -0.8),
    end: const Alignment(0.9, 0.8),
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));

  late final Animation<Alignment> _a2 = Tween<Alignment>(
    begin: const Alignment(0.9, -0.6),
    end: const Alignment(-0.9, 0.6),
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = widget.accent ?? CinevaColors.accentSoft;
    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF040406), Color(0xFF0A0A0E)],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _a1,
            builder: (_, __) => Align(
              alignment: _a1.value,
              child: _blob(gold.withOpacity(0.10), 560),
            ),
          ),
          AnimatedBuilder(
            animation: _a2,
            builder: (_, __) => Align(
              alignment: _a2.value,
              child: _blob(CinevaColors.accent.withOpacity(0.07), 480),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withOpacity(0)],
          ),
        ),
      );
}
