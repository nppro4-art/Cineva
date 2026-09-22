import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

import 'cineva_pressable.dart';

/// Pill de filtre (Films, Séries, 4K, HDR, Action…).
///
/// Sélection : la surface passe en blanc, le texte en noir, avec une
/// transition de [CinevaMotion.fast]. Non sélectionnée : surface sombre,
/// texte gris clair, liseré quasi invisible.
class CinevaChip extends StatelessWidget {
  const CinevaChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.icon,
    this.onDeleted,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;
  final VoidCallback? onDeleted;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onSelected != null || onDeleted != null;
    final Color foreground = selected ? CinevaColors.textOnLight : CinevaColors.textSoft;

    return CinevaPressable(
      enabled: enabled,
      pressedScale: 0.95,
      onTap: onSelected == null ? null : () => onSelected!(!selected),
      child: AnimatedContainer(
        duration: CinevaMotion.fast,
        curve: CinevaCurve.out,
        height: dense ? 30 : 34,
        padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 14),
        decoration: BoxDecoration(
          color: selected ? CinevaColors.textHigh : CinevaColors.card,
          borderRadius: BorderRadius.circular(CinevaRadii.chip),
          border: Border.all(
            color: selected ? Colors.transparent : CinevaColors.hairline,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: 6),
            ],
            AnimatedDefaultTextStyle(
              duration: CinevaMotion.fast,
              style: CinevaTypography.chip.copyWith(color: foreground),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (onDeleted != null) ...<Widget>[
              const SizedBox(width: 6),
              Icon(Icons.close_rounded, size: 13, color: foreground),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rangée de pills défilable horizontalement, sans barre visible.
class CinevaChipRow extends StatelessWidget {
  const CinevaChipRow({
    super.key,
    required this.children,
    this.spacing = CinevaSpacing.xs,
    this.padding = EdgeInsets.zero,
    this.dense = false,
  });

  final List<Widget> children;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: dense ? 30 : 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        physics: const BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast),
        itemCount: children.length,
        separatorBuilder: (BuildContext context, int index) => SizedBox(width: spacing),
        itemBuilder: (BuildContext context, int index) => children[index],
      ),
    );
  }
}
