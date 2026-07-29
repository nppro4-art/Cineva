import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

class CinevaScaffoldContainer extends StatelessWidget {
  const CinevaScaffoldContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CinevaSpacing.lg),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF050505), Color(0xFF09090D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
