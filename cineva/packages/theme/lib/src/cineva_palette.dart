import 'package:flutter/material.dart';

/// Palette Cineva — noir profond dominant, échelle de surfaces pour la
/// profondeur, or/champagne en accent rare.
///
/// Hiérarchie de surfaces (du plus profond au plus élevé) :
/// [ink] → [surface] → [card] → [raised] → [overlay] → [modal].
abstract final class CinevaColors {
  // ---------------------------------------------------------------- surfaces
  /// Fond global de l'application (le niveau le plus profond).
  static const Color ink = Color(0xFF070707);

  /// Surface d'un écran posé sur le fond.
  static const Color surface = Color(0xFF0C0C0C);

  /// Carte posée sur une surface.
  static const Color card = Color(0xFF111111);

  /// Carte élevée (élément actif, ligne survolée/pressée).
  static const Color raised = Color(0xFF171717);

  /// Surface de navigation et d'app-bars condensées.
  static const Color overlay = Color(0xFF1B1B1D);

  /// Modales, bottom sheets, menus.
  static const Color modal = Color(0xFF1F1F22);

  /// Champ de saisie au repos.
  static const Color field = Color(0xFF151517);

  // ------------------------------------------------------------------ texte
  static const Color textHigh = Color(0xFFF7F7F8);
  static const Color textSoft = Color(0xFFB9B9BF);
  static const Color textFaint = Color(0xFF7E7E86);
  static const Color textOnLight = Color(0xFF0B0B0C);

  // ------------------------------------------------------------ or/champagne
  /// Accent principal : champagne chaud, utilisé avec parcimonie.
  static const Color gold = Color(0xFFE4C48C);

  /// Variant lumineux (état pressé / actif).
  static const Color goldBright = Color(0xFFF3DFB4);

  /// Variant profond (dégradés, icônes secondaires).
  static const Color goldDeep = Color(0xFFB4935C);

  /// Halo doré très discret.
  static const Color goldGlow = Color(0x29E4C48C);

  // ------------------------------------------------------------- séparations
  /// Liseré discret : jamais de bordure marquée.
  static const Color hairline = Color(0x14FFFFFF);
  static const Color hairlineStrong = Color(0x22FFFFFF);

  /// Voile blanc utilisé sur les surfaces translucides.
  static const Color veil = Color(0x0AFFFFFF);
  static const Color veilStrong = Color(0x14FFFFFF);

  // -------------------------------------------------------------- sémantique
  static const Color success = Color(0xFF43D391);
  static const Color warning = Color(0xFFE8B24A);
  static const Color danger = Color(0xFFE5637C);
  static const Color info = Color(0xFF7FA9D9);

  // ----------------------------------------------------------------- scrims
  static const Color scrimSoft = Color(0x66000000);
  static const Color scrimMedium = Color(0xB3000000);
  static const Color scrimStrong = Color(0xE6000000);
  static const Color scrimOpaque = Color(0xFF000000);

  // ------------------------------------------------------- accents hérités
  /// Accent historique (console d'administration, composants legacy).
  static const Color accent = Color(0xFF7C4DFF);
  static const Color accentSoft = Color(0xFF9D84FF);

  // --------------------------------------------------------------- thème clair
  static const Color lightBackground = Color(0xFFF7F6F3);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceRaised = Color(0xFFF0EEF8);
  static const Color lightTextPrimary = Color(0xFF111114);
  static const Color lightTextMuted = Color(0xCC111114);
  static const Color lightBorder = Color(0x12000000);

  // --------------------------------------------------------- alias de confort
  /// Alias historiques conservés pour les écrans non refondus (admin).
  static const Color background = ink;
  static const Color surfaceRaised = card;
  static const Color surfaceOverlay = raised;
  static const Color border = hairline;
  static const Color textPrimary = textHigh;
  static const Color textMuted = textSoft;

  /// Dégradé champagne utilisé pour les actions premium rares.
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFF6E7C4), Color(0xFFE4C48C), Color(0xFFC9A468)],
    stops: <double>[0.0, 0.55, 1.0],
  );
}
