import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

class CinevaSectionTitle extends StatelessWidget {
  const CinevaSectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
  });

  final String title;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: CinevaColors.textPrimary),
          ),
        ),
        if (actionLabel != null)
          Text(
            actionLabel!,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: CinevaColors.textMuted),
          ),
      ],
    );
  }
}
