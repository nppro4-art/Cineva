import 'package:flutter/material.dart';

import 'cineva_palette.dart';

/// Échelle typographique Cineva.
///
/// Aucune police personnalisée n'est embarquée : on travaille la pile système
/// (SF Pro sur iOS, Roboto sur Android) avec des graisses, des hauteurs de
/// ligne et des trackedings choisis — c'est le rendu natif premium attendu.
abstract final class CinevaTypography {
  /// Wordmark CINEVA : fin/moyen, très espacé.
  static const TextStyle brand = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 5.2,
    height: 1,
    color: CinevaColors.textHigh,
  );

  /// Wordmark compact (player, petits espaces).
  static const TextStyle brandSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 3.6,
    height: 1,
    color: CinevaColors.textHigh,
  );

  /// Titre du hero.
  static const TextStyle heroTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
    height: 1.06,
    color: CinevaColors.textHigh,
  );

  /// Titre d'écran poussé (Recherche, Téléchargements, Profil…).
  static const TextStyle screenTitle = TextStyle(
    fontSize: 27,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
    height: 1.12,
    color: CinevaColors.textHigh,
  );

  /// Titre de fiche contenu.
  static const TextStyle detailTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.12,
    color: CinevaColors.textHigh,
  );

  /// Titre de section (« Tendances », « Nouveautés »…).
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    height: 1.2,
    color: CinevaColors.textHigh,
  );

  /// Titre de carte / de ligne.
  static const TextStyle cardTitle = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.25,
    color: CinevaColors.textHigh,
  );

  /// Corps de texte (synopsis).
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.55,
    color: CinevaColors.textSoft,
  );

  /// Corps de texte serré (lignes de réglages).
  static const TextStyle bodyCompact = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: CinevaColors.textSoft,
  );

  /// Métadonnées (année · durée · qualité).
  static const TextStyle meta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.3,
    color: CinevaColors.textSoft,
  );

  /// Sur-étiquette en capitales espacées (« CINEVA ORIGINAL », « 4K HDR »).
  static const TextStyle overline = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    height: 1.2,
    color: CinevaColors.textFaint,
  );

  /// Libellé de bouton.
  static const TextStyle button = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
    color: CinevaColors.textOnLight,
  );

  /// Libellé de navigation basse.
  static const TextStyle navLabel = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.1,
  );

  /// Libellé de pill / chip.
  static const TextStyle chip = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.1,
  );

  /// Chiffres (durées, progression, horodatage du player).
  static const TextStyle numeric = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
    height: 1.2,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    color: CinevaColors.textSoft,
  );

  /// Note (★ 8.8).
  static const TextStyle rating = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    height: 1.2,
    color: CinevaColors.textHigh,
  );

  /// Applique l'échelle Cineva à un [TextTheme] Material pour que les
  /// composants natifs (Sheet, Dialog, SnackBar…) héritent du même rendu.
  static TextTheme applyTo(TextTheme base) {
    return base.copyWith(
      displayLarge: heroTitle.copyWith(fontSize: 44, letterSpacing: -1.4),
      displayMedium: heroTitle.copyWith(fontSize: 36, letterSpacing: -1.1),
      displaySmall: heroTitle,
      headlineLarge: screenTitle.copyWith(fontSize: 24),
      headlineMedium: screenTitle,
      headlineSmall: screenTitle.copyWith(fontSize: 22),
      titleLarge: sectionTitle.copyWith(fontSize: 19),
      titleMedium: sectionTitle.copyWith(fontSize: 15.5),
      titleSmall: cardTitle,
      bodyLarge: body.copyWith(fontSize: 15),
      bodyMedium: body,
      bodySmall: bodyCompact.copyWith(fontSize: 12.5, color: CinevaColors.textFaint),
      labelLarge: button,
      labelMedium: meta,
      labelSmall: overline,
    );
  }
}
