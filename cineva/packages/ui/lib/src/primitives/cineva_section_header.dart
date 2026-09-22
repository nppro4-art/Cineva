import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

import 'cineva_pressable.dart';

/// En-tête de section : titre, sur-étiquette optionnelle et action à droite.
class CinevaSectionHeader extends StatelessWidget {
  const CinevaSectionHeader({
    super.key,
    required this.title,
    this.overline,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: CinevaSpacing.sm),
  });

  final String title;

  /// Petite étiquette en capitales au-dessus du titre (« CINEVA ORIGINAL »).
  final String? overline;

  /// Libellé à droite : action cliquable si [onAction] est fourni, sinon
  /// simple compteur statique.
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final double actionWidth =
        actionLabel == null ? 0 : (onAction == null ? 44 : 74);

    return Padding(
      padding: padding,
      child: Stack(
        alignment: Alignment.centerRight,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(right: actionWidth),
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (overline != null) ...<Widget>[
                    Text(overline!.toUpperCase(), style: CinevaTypography.overline),
                    const SizedBox(height: 5),
                  ],
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CinevaTypography.sectionTitle,
                  ),
                ],
              ),
            ),
          ),
          if (actionLabel != null && onAction == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CinevaSpacing.xs),
              child: Text(
                actionLabel!,
                style: CinevaTypography.numeric.copyWith(
                  fontSize: 11.5,
                  color: CinevaColors.textFaint,
                ),
              ),
            ),
          if (actionLabel != null && onAction != null)
            CinevaPressable(
              pressedScale: 0.94,
              onTap: onAction,
              semanticLabel: actionLabel,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CinevaSpacing.xs,
                  vertical: CinevaSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      actionLabel!,
                      style: CinevaTypography.meta.copyWith(color: CinevaColors.textFaint),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: CinevaColors.textFaint,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
