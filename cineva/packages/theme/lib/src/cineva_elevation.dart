import 'package:flutter/material.dart';

import 'cineva_palette.dart';

/// Ombres et halos. Très discrets : la profondeur vient d'abord des niveaux
/// de surface, l'ombre ne fait que décoller un élément du fond.
abstract final class CinevaShadows {
  /// Affiche posée sur un rail.
  static const List<BoxShadow> poster = <BoxShadow>[
    BoxShadow(
      color: Color(0x59000000),
      blurRadius: 14,
      offset: Offset(0, 6),
    ),
  ];

  /// Carte élevée (carte pressée, carte de lecture en cours).
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 22,
      offset: Offset(0, 10),
    ),
  ];

  /// Modale / bottom sheet.
  static const List<BoxShadow> modal = <BoxShadow>[
    BoxShadow(
      color: Color(0x8C000000),
      blurRadius: 40,
      offset: Offset(0, -8),
    ),
  ];

  /// Barre de navigation basse.
  static const List<BoxShadow> nav = <BoxShadow>[
    BoxShadow(
      color: Color(0x73000000),
      blurRadius: 26,
      offset: Offset(0, -6),
    ),
  ];

  /// Pill d'action posée sur la vidéo (ignorer l'intro, passer un segment).
  static const List<BoxShadow> player = <BoxShadow>[
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 22,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: CinevaColors.goldGlow,
      blurRadius: 26,
      spreadRadius: -6,
    ),
  ];

  /// Halo d'une carte au toucher : à peine visible, jamais coloré criard.
  static List<BoxShadow> touchHalo({Color color = Colors.white, double opacity = 0.10}) {
    return <BoxShadow>[
      BoxShadow(
        color: color.withOpacity(opacity),
        blurRadius: 18,
        spreadRadius: -2,
      ),
      BoxShadow(
        color: const Color(0x59000000),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ];
  }

  /// Halo doré du bouton principal « Regarder ».
  static List<BoxShadow> goldGlow({double opacity = 0.30}) {
    return <BoxShadow>[
      BoxShadow(
        color: CinevaColors.gold.withOpacity(opacity),
        blurRadius: 26,
        offset: const Offset(0, 8),
      ),
    ];
  }
}
