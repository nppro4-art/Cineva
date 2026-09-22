import 'package:flutter/animation.dart';

/// Courbes Cineva.
///
/// On reste sur des courbes Material/Flutter éprouvées (GPU-friendly, sans
/// simulation physique coûteuse). Les ressorts ne servent qu'à deux endroits :
/// le relâchement d'un bouton et l'apparition d'une carte pressée.
abstract final class CinevaCurve {
  /// Sortie franche : apparitions, translations courtes.
  static const Curve out = Curves.easeOutCubic;

  /// Sortie très amortie : entrées de page, hero.
  static const Curve decelerate = Curves.easeOutQuint;

  /// Aller/retour : crossfades, changements d'état.
  static const Curve inOut = Curves.easeInOutCubic;

  /// Emphase douce (zoom léger).
  static const Curve emphasize = Curves.easeOutQuart;

  /// Relâchement de bouton : très léger dépassement, jamais élastique.
  static const Curve release = Cubic(0.34, 1.24, 0.64, 1);

  /// Pression : réaction immédiate.
  static const Curve press = Cubic(0.2, 0, 0.4, 1);

  /// Rotation du hero : accélération puis décélération très amortie.
  static const Curve heroRotate = Curves.easeInOutCubic;
}

/// Durées Cineva. Rapides : aucune animation ne doit donner l'impression
/// que l'application traîne.
abstract final class CinevaMotion {
  /// Réaction tactile (scale de presse, halo).
  static const Duration instant = Duration(milliseconds: 110);

  /// Micro-interactions : chips, switches, focus de recherche.
  static const Duration fast = Duration(milliseconds: 180);

  /// Transitions d'état courantes : nav basse, cartes, menus.
  static const Duration medium = Duration(milliseconds: 260);

  /// Transitions plus amples : sheets, modales, hero text.
  static const Duration slow = Duration(milliseconds: 400);

  /// Transition de page standard.
  static const Duration page = Duration(milliseconds: 320);

  /// Transition vers le lecteur (le backdrop « s'agrandit »).
  static const Duration player = Duration(milliseconds: 420);

  /// Entrée du backdrop du hero (crossfade + zoom).
  static const Duration heroImage = Duration(milliseconds: 720);

  /// Entrée du texte du hero (titre, métadonnées, description, bouton).
  static const Duration heroText = Duration(milliseconds: 520);

  /// Décalage entre deux éléments du texte du hero.
  static const Duration heroStagger = Duration(milliseconds: 80);

  /// Décalage entre deux éléments d'une liste de résultats.
  static const Duration listStagger = Duration(milliseconds: 38);

  /// Cadence de la rotation automatique des suggestions du hero.
  static const Duration heroRotation = Duration(seconds: 7);

  /// Durée avant masquage automatique des contrôles du player.
  static const Duration controlsTimeout = Duration(seconds: 3);

  /// Durée d'affichage d'un retour visuel de geste (±10 s, volume…).
  static const Duration gestureToast = Duration(milliseconds: 820);

  /// Shimmer des skeletons.
  static const Duration shimmer = Duration(milliseconds: 1500);
}
