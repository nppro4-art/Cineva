import 'package:cineva_animations/cineva_animations.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CinevaScaffoldContainer(
        child: Center(
          child: CinevaFadeSlide(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: CinevaSpacing.md),
                Text(
                  'Initialisation de la session, du backend et des accès sécurisés...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: CinevaColors.textMuted),
                ),
                const SizedBox(height: CinevaSpacing.xl),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
