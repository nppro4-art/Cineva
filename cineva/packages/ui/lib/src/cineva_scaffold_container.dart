import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

import 'cineva_ambient_backdrop.dart';

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
    return Stack(
      children: <Widget>[
        const CinevaAmbientBackdrop(),
        SafeArea(
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ],
    );
  }
}
