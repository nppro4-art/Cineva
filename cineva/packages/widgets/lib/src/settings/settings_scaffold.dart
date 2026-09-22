import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Scaffolding commun des écrans de réglages Cineva.
///
/// Barre supérieure (retour + titre + actions), gouttière responsive, scroll
/// souple et rafraîchissement optionnel. Toutes les pages de réglages passent
/// par là : aucun `AppBar` Material, aucune bordure autour des groupes.
class SettingsScreenScaffold extends StatelessWidget {
  const SettingsScreenScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions = const <Widget>[],
    this.onBack,
    this.onRefresh,
    this.bottomPadding,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final Future<void> Function()? onRefresh;

  /// Marge basse supplémentaire (barre de navigation, bouton flottant…).
  final double? bottomPadding;

  @override
  Widget build(BuildContext context) {
    final CinevaMetrics metrics = CinevaMetrics.of(context);

    final Widget scroll = CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
        decelerationRate: ScrollDecelerationRate.fast,
      ),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: CinevaTopBar(title: title, onBack: onBack ?? () => _back(context), actions: actions),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            metrics.gutter,
            CinevaSpacing.xs,
            metrics.gutter,
            bottomPadding ?? CinevaSpacing.xxl,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              <Widget>[
                if (subtitle != null) ...<Widget>[
                  Text(subtitle!, style: CinevaTypography.bodyCompact),
                  const SizedBox(height: CinevaSpacing.lg),
                ],
                ...children,
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: CinevaColors.ink,
      body: onRefresh == null
          ? scroll
          : RefreshIndicator(
              onRefresh: onRefresh!,
              color: CinevaColors.gold,
              backgroundColor: CinevaColors.raised,
              edgeOffset: 96,
              child: scroll,
            ),
    );
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/home');
  }
}

/// Groupe de réglages posé sur une seule surface sombre.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CinevaColors.surface,
          borderRadius: BorderRadius.circular(CinevaRadii.card),
        ),
        child: Padding(
          padding: padding ??
              const EdgeInsets.symmetric(vertical: CinevaSpacing.xxs),
          child: Column(children: children),
        ),
      ),
    );
  }
}

/// Option sélectionnable (langue, thème, profil…) : libellé, sous-titre et
/// coche dorée. Un seul groupe visuel, jamais de bordure par option.
class SettingsOption<T> extends StatelessWidget {
  const SettingsOption({
    super.key,
    required this.value,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.subtitle,
    this.icon,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return CinevaPressable(
      pressedScale: 0.99,
      onTap: () => onSelected(value),
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CinevaSpacing.md,
          vertical: CinevaSpacing.sm + 2,
        ),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 17, color: CinevaColors.textFaint),
              const SizedBox(width: CinevaSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: CinevaTypography.cardTitle.copyWith(
                      fontSize: 14,
                      color: selected ? CinevaColors.textHigh : CinevaColors.textSoft,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: CinevaTypography.bodyCompact.copyWith(fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: CinevaSpacing.sm),
            AnimatedScale(
              duration: CinevaMotion.fast,
              curve: CinevaCurve.release,
              scale: selected ? 1 : 0.6,
              child: Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 19,
                color: selected ? CinevaColors.gold : CinevaColors.textFaint.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// En-tête de groupe discret (titre + valeur courante à droite).
class SettingsGroupHeader extends StatelessWidget {
  const SettingsGroupHeader({super.key, required this.title, this.value});

  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 2,
        bottom: CinevaSpacing.xs,
        top: CinevaSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: CinevaTypography.overline.copyWith(fontSize: 9.5),
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: CinevaTypography.numeric.copyWith(
                fontSize: 11,
                color: CinevaColors.textFaint,
              ),
            ),
        ],
      ),
    );
  }
}
