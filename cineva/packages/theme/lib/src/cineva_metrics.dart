import 'package:flutter/material.dart';

/// Rythme vertical/horizontal de l'interface. Échelle en 4 dp.
abstract final class CinevaSpacing {
  static const double none = 0;
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 44;
  static const double huge = 64;

  /// Gouttière latérale par défaut d'un écran mobile.
  static const double gutter = 20;

  /// Espace entre deux cartes d'un rail.
  static const double railGap = 12;

  /// Espace entre deux sections.
  static const double sectionGap = 30;

  /// Taille minimale d'une zone tactile (recommandation accessibilité).
  static const double hitTarget = 44;
}

/// Rayons. Volontairement sobres : aucun élément n'est « bulle ».
abstract final class CinevaRadii {
  static const double hair = 6;
  static const double chip = 999;
  static const double small = 10;
  static const double poster = 12;
  static const double medium = 14;
  static const double card = 18;
  static const double large = 22;
  static const double sheet = 26;
  static const double legacySmall = 18;
  static const double legacyMedium = 24;
  static const double legacyLarge = 32;

  /// Rayons composés (expressions constantes : utilisables dans un `const`).
  static const BorderRadius posterBorder = BorderRadius.all(Radius.circular(poster));
  static const BorderRadius cardBorder = BorderRadius.all(Radius.circular(card));
  static const BorderRadius sheetBorder =
      BorderRadius.vertical(top: Radius.circular(sheet));
}

/// Mesures responsive dérivées de l'écran courant.
///
/// Rien n'est codé en dur dans les écrans : on passe toujours par
/// [CinevaMetrics.of] pour les largeurs de cartes, gouttières et hauteurs.
@immutable
class CinevaMetrics {
  const CinevaMetrics({
    required this.width,
    required this.height,
    required this.topInset,
    required this.bottomInset,
    required this.textScale,
  });

  factory CinevaMetrics.of(BuildContext context) {
    final MediaQueryData query = MediaQuery.of(context);
    final Size size = query.size;
    return CinevaMetrics(
      width: size.width,
      height: size.height,
      topInset: query.padding.top,
      bottomInset: query.padding.bottom,
      textScale: query.textScaler.scale(1),
    );
  }

  final double width;
  final double height;
  final double topInset;
  final double bottomInset;
  final double textScale;

  /// Petit téléphone (≤ 359 dp) : on resserre tout.
  bool get isTiny => width < 360;

  /// Téléphone portrait standard.
  bool get isPhone => width < 600;

  /// Tablette / paysage.
  bool get isTablet => width >= 600 && width < 1024;

  bool get isDesktop => width >= 1024;

  /// Gouttière latérale : 16 dp sur petit écran, 20 dp sinon.
  double get gutter => isTiny ? 16 : CinevaSpacing.gutter;

  /// Largeur d'une affiche de rail (2:3). Laisse toujours apparaître une
  /// partie de la carte suivante pour signifier le swipe.
  double get posterWidth {
    if (isTiny) return width * 0.34;
    if (isPhone) return width * 0.315;
    if (isTablet) return 176;
    return 200;
  }

  /// Largeur d'une carte « Continuer à regarder » (backdrop 16:9).
  double get continueWidth => isPhone ? width * 0.66 : 320;

  /// Hauteur du hero : dominante à l'ouverture, jamais plus de 72 % d'écran.
  double get heroHeight {
    final double base = height - topInset - bottomInset;
    if (isTiny) return (base * 0.62).clamp(360.0, 520.0);
    if (isPhone) return (base * 0.66).clamp(400.0, 620.0);
    if (isTablet) return (base * 0.6).clamp(420.0, 640.0);
    return (base * 0.72).clamp(460.0, 780.0);
  }

  /// Nombre de colonnes de la grille Bibliothèque.
  int get gridColumns {
    if (isTiny) return 2;
    if (isPhone) return 3;
    if (isTablet) return 5;
    return 7;
  }

  /// Taille du titre du hero : suit la largeur, bornée pour rester lisible
  /// avec un texte agrandi.
  double get heroTitleSize => (width * 0.086).clamp(26.0, 40.0);

  /// Taille d'un titre de section.
  double get sectionTitleSize => isTiny ? 16 : 17;

  /// Hauteur de la barre de navigation basse (hors safe area).
  double get bottomNavHeight => 62;

  /// Hauteur du header de marque (hors safe area).
  double get brandHeaderHeight => 52;

  /// Hauteur d'affiche du backdrop de la fiche contenu.
  double get detailBackdropHeight {
    if (isPhone) return (height * 0.58).clamp(320.0, 520.0);
    return (height * 0.5).clamp(320.0, 560.0);
  }
}
