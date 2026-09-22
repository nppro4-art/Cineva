import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

import '../primitives/cineva_pressable.dart';

/// Barre supérieure d'un écran poussé : retour, titre, actions.
///
/// [opacity] permet le même comportement que le header de l'accueil :
/// transparente au-dessus d'un visuel, elle devient une surface sombre quand
/// le contenu défile.
class CinevaTopBar extends StatelessWidget {
  const CinevaTopBar({
    super.key,
    this.title,
    this.onBack,
    this.actions = const <Widget>[],
    this.opacity = 1,
    this.height = 52,
    this.centerTitle = false,
    this.bottom,
  });

  final String? title;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final double opacity;
  final double height;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    final double o = opacity.clamp(0.0, 1.0).toDouble();
    final double topInset = MediaQuery.viewPaddingOf(context).top;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: CinevaColors.surface.withOpacity(o),
          border: o > 0.98 ? const Border(bottom: CinevaEdges.hairlineTop) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(height: topInset),
            SizedBox(
              height: height,
              child: Row(
                children: <Widget>[
                  if (onBack != null)
                    Padding(
                      padding: const EdgeInsets.only(left: CinevaSpacing.xs),
                      child: CinevaPressable(
                        pressedScale: 0.9,
                        onTap: onBack,
                        semanticLabel: 'Retour',
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 19,
                            color: CinevaColors.textHigh,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: CinevaSpacing.lg),
                  Expanded(
                    child: AnimatedOpacity(
                      duration: CinevaMotion.fast,
                      opacity: o > 0.6 ? ((o - 0.6) / 0.4).clamp(0.0, 1.0) : 0.0,
                      child: Text(
                        title ?? '',
                        textAlign: centerTitle ? TextAlign.center : TextAlign.start,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CinevaTypography.sectionTitle.copyWith(fontSize: 16.5),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: CinevaSpacing.sm),
                    child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                  ),
                ],
              ),
            ),
            if (bottom != null) bottom!,
          ],
        ),
      ),
    );
  }
}

/// Titre d'écran plein (Recherche, Téléchargements, Bibliothèque, Profil).
class CinevaScreenTitle extends StatelessWidget {
  const CinevaScreenTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      CinevaSpacing.gutter,
      CinevaSpacing.xs,
      CinevaSpacing.gutter,
      CinevaSpacing.lg,
    ),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(title, style: CinevaTypography.screenTitle),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 5),
                    Text(subtitle!, style: CinevaTypography.bodyCompact),
                  ],
                ],
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: CinevaSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
