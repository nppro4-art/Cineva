import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

class CinevaLoadingView extends StatelessWidget {
  const CinevaLoadingView({super.key, this.label = 'Chargement...'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: CinevaSpacing.md),
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted)),
        ],
      ),
    );
  }
}
