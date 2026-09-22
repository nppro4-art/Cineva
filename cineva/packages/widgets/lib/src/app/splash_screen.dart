import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';

/// Écran de démarrage : wordmark CINEVA, filet doré qui se déploie, message
/// d'initialisation. Deux animations seulement (entrée + filet), toutes deux
/// pilotées par un seul contrôleur : aucun coût pendant le bootstrap.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.title});

  final String title;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> entrance = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.45, curve: CinevaCurve.decelerate),
    );
    final Animation<double> line = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.85, curve: CinevaCurve.decelerate),
    );
    final Animation<double> message = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1, curve: CinevaCurve.out),
    );

    return Scaffold(
      backgroundColor: CinevaColors.ink,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.15),
            radius: 1.1,
            colors: <Color>[Color(0xFF101013), CinevaColors.ink],
          ),
        ),
        child: Center(
          child: Semantics(
            label: '${widget.title} — chargement',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FadeTransition(
                  opacity: entrance,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.12),
                      end: Offset.zero,
                    ).animate(entrance),
                    child: const CinevaWordmark(),
                  ),
                ),
                const SizedBox(height: CinevaSpacing.lg),
                AnimatedBuilder(
                  animation: line,
                  builder: (BuildContext context, Widget? child) {
                    return Container(
                      width: 128 * line.value,
                      height: 1.6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(CinevaRadii.chip),
                        gradient: LinearGradient(
                          colors: <Color>[
                            CinevaColors.goldDeep.withOpacity(0.2),
                            CinevaColors.gold,
                            CinevaColors.goldDeep.withOpacity(0.2),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: CinevaSpacing.lg),
                FadeTransition(
                  opacity: message,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: CinevaSpacing.xxl),
                    child: Text(
                      'Initialisation de la session, du catalogue et des accès sécurisés…',
                      textAlign: TextAlign.center,
                      style: CinevaTypography.meta.copyWith(fontSize: 11.5),
                    ),
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
