import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

/// Chargement plein écran : anneau fin + libellé discret.
///
/// À éviter là où un skeleton est possible (`CinevaSkeleton*`) : ce composant
/// sert aux chargements courts (session, lecteur, préférences).
class CinevaLoadingView extends StatelessWidget {
  const CinevaLoadingView({super.key, this.label = 'Chargement…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: CinevaColors.gold,
            ),
          ),
          const SizedBox(height: CinevaSpacing.md),
          Text(
            label,
            textAlign: TextAlign.center,
            style: CinevaTypography.bodyCompact.copyWith(color: CinevaColors.textFaint),
          ),
        ],
      ),
    );
  }
}
