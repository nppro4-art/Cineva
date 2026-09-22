import 'package:flutter/material.dart';

import 'cineva_palette.dart';

/// Voiles dégradés qui garantissent la lisibilité du texte sur les visuels.
abstract final class CinevaScrims {
  /// Bas du hero : dégradé long pour un texte parfaitement lisible.
  static const LinearGradient heroBottom = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0x00000000),
      Color(0x33000000),
      Color(0xB3000000),
      Color(0xF2070707),
    ],
    stops: <double>[0.28, 0.52, 0.78, 1.0],
  );

  /// Haut du hero : voile léger pour le header.
  static const LinearGradient heroTop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0x8C000000), Color(0x33000000), Color(0x00000000)],
    stops: <double>[0.0, 0.45, 1.0],
  );

  /// Bas d'une affiche de rail (métadonnées incrustées).
  static const LinearGradient posterBottom = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0x00000000), Color(0x1A000000), Color(0xA6000000)],
    stops: <double>[0.45, 0.68, 1.0],
  );

  /// Haut des contrôles du player.
  static const LinearGradient playerTop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xCC000000), Color(0x59000000), Color(0x00000000)],
    stops: <double>[0.0, 0.55, 1.0],
  );

  /// Bas des contrôles du player.
  static const LinearGradient playerBottom = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: <Color>[Color(0xD9000000), Color(0x66000000), Color(0x00000000)],
    stops: <double>[0.0, 0.6, 1.0],
  );

  /// En-tête de profil : reflet doré très discret sur une surface sombre.
  static const LinearGradient profileHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0x21E4C48C),
      Color(0x0AE4C48C),
      Color(0x00000000),
    ],
    stops: <double>[0.0, 0.42, 1.0],
  );

  /// Fond d'une fiche contenu : le visuel fond dans la surface de l'écran.
  static LinearGradient detailFade(Color target) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        const Color(0x33000000),
        const Color(0x99000000),
        target,
        target,
      ],
      stops: const <double>[0.0, 0.42, 0.86, 1.0],
    );
  }
}

/// Visuels de repli : quand aucune image n'est disponible (catalogue de
/// démonstration, image en échec), on affiche un dégradé sombre déterministe
/// dérivé de l'identifiant du contenu — jamais de couleur saturée.
abstract final class CinevaArtworkGradients {
  static const List<List<Color>> _stops = <List<Color>>[
    <Color>[Color(0xFF2A2C33), Color(0xFF101114)],
    <Color>[Color(0xFF26313A), Color(0xFF0D1114)],
    <Color>[Color(0xFF332B26), Color(0xFF12100E)],
    <Color>[Color(0xFF26332C), Color(0xFF0E1210)],
    <Color>[Color(0xFF2E2635), Color(0xFF110F13)],
    <Color>[Color(0xFF35301F), Color(0xFF12110C)],
    <Color>[Color(0xFF1F2C35), Color(0xFF0C1013)],
  ];

  /// Dégradé déterministe pour un identifiant de contenu.
  static LinearGradient forSeed(String seed) {
    final int hash = seed.codeUnits.fold<int>(0, (int value, int code) => (value + code) % 100003);
    final List<Color> pair = _stops[hash % _stops.length];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: pair,
    );
  }

  /// Dégradé de repli neutre (aucune graine connue).
  static const LinearGradient neutral = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF1E1F23), Color(0xFF0C0C0E)],
  );
}

/// Liseré supérieur ultra-fin qui matérialise une surface sans bordure épaisse.
abstract final class CinevaEdges {
  static const BorderSide hairlineTop =
      BorderSide(color: CinevaColors.hairline, width: 1);

  static BoxDecoration get hairlineTopBox => const BoxDecoration(
        border: Border(top: hairlineTop),
      );
}
