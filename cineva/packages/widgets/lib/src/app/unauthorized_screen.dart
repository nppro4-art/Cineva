import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';

class UnauthorizedScreen extends StatelessWidget {
  const UnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CinevaScaffoldContainer(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: CinevaGlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Accès refusé', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: CinevaSpacing.md),
                  Text(
                    'Cette application est réservée aux administrateurs Cineva.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: CinevaColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
