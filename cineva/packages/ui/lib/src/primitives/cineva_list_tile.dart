import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

/// Ligne de navigation de réglages : icône, titre, sous-titre, chevron.
///
/// Réagit au toucher par une très légère mise en surface (pas de ripple).
class CinevaListTile extends StatelessWidget {
  const CinevaListTile({
    super.key,
    required this.title,
    this.onTap,
    this.icon,
    this.subtitle,
    this.trailing,
    this.showChevron = true,
    this.accentIcon = false,
    this.dense = false,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool accentIcon;
  final bool dense;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return _TilePressSurface(
      onTap: onTap,
      semanticLabel: semanticLabel ?? title,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: CinevaSpacing.md,
          vertical: dense ? CinevaSpacing.sm : 13,
        ),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: 20,
                color: accentIcon ? CinevaColors.gold : CinevaColors.textSoft,
              ),
              const SizedBox(width: CinevaSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: CinevaTypography.cardTitle.copyWith(fontSize: 14.5),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CinevaTypography.bodyCompact.copyWith(fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: CinevaSpacing.sm),
              trailing!,
            ],
            if (showChevron) ...<Widget>[
              const SizedBox(width: CinevaSpacing.xs),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: CinevaColors.textFaint,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Groupe de lignes dans une carte arrondie, séparées par des liserés.
class CinevaTileGroup extends StatelessWidget {
  const CinevaTileGroup({
    super.key,
    required this.children,
    this.title,
    this.margin = const EdgeInsets.only(bottom: CinevaSpacing.xl),
  });

  final List<Widget> children;
  final String? title;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(const CinevaHairline(indent: CinevaSpacing.md + 20 + CinevaSpacing.md));
      }
    }

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(
                left: CinevaSpacing.xxs,
                bottom: CinevaSpacing.xs,
              ),
              child: Text(
                title!.toUpperCase(),
                style: CinevaTypography.overline,
              ),
            ),
          ],
          DecoratedBox(
            decoration: BoxDecoration(
              color: CinevaColors.surface,
              borderRadius: BorderRadius.circular(CinevaRadii.card),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(CinevaRadii.card),
              child: Column(children: rows),
            ),
          ),
        ],
      ),
    );
  }
}

/// Liseré de séparation à l'intérieur d'un groupe.
class CinevaHairline extends StatelessWidget {
  const CinevaHairline({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: EdgeInsets.only(left: indent),
      color: CinevaColors.hairline,
    );
  }
}

/// Surface qui réagit à la pression en s'éclairant très légèrement.
class _TilePressSurface extends StatefulWidget {
  const _TilePressSurface({required this.child, this.onTap, this.semanticLabel});

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<_TilePressSurface> createState() => _TilePressSurfaceState();
}

class _TilePressSurfaceState extends State<_TilePressSurface> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
        onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
        onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: CinevaMotion.instant,
          curve: CinevaCurve.out,
          color: _pressed ? CinevaColors.raised : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Variante « carte pressable » pour les tuiles isolées (non groupées).
class CinevaActionCard extends StatelessWidget {
  const CinevaActionCard({
    super.key,
    required this.title,
    required this.onTap,
    this.icon,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CinevaSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CinevaColors.surface,
          borderRadius: BorderRadius.circular(CinevaRadii.card),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CinevaRadii.card),
          child: CinevaListTile(
            title: title,
            subtitle: subtitle,
            icon: icon,
            trailing: trailing,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
