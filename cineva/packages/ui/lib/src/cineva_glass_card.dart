import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

class CinevaGlassCard extends StatelessWidget {
  const CinevaGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CinevaSpacing.lg),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CinevaRadii.medium),
        border: Border.all(color: CinevaColors.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withOpacity(0.06),
            Colors.white.withOpacity(0.02),
          ],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
