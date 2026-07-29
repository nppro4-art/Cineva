import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';

class CinevaStatTile extends StatelessWidget {
  const CinevaStatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return CinevaGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, color: CinevaColors.accentSoft),
            const SizedBox(height: CinevaSpacing.md),
          ],
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: CinevaSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted)),
        ],
      ),
    );
  }
}
