import 'package:cineva_models/cineva_models.dart';

/// Libellés dérivés des modèles : aucune donnée inventée, uniquement du
/// formatage cohérent de ce que le catalogue fournit déjà.
abstract final class CinevaContentLabels {
  static const Set<String> _qualityTokens = <String>{
    '4K',
    'UHD',
    'HDR',
    'HDR10',
    'HDR10+',
    'DOLBY',
    'VISION',
    'ATMOS',
    '1080P',
    '720P',
    '480P',
    'IMAX',
  };

  static String type(String contentType) {
    return switch (contentType) {
      'movie' => 'Film',
      'series' => 'Série',
      'episode' => 'Épisode',
      _ => 'Contenu',
    };
  }

  /// « 2 h 49 » / « 48 min » / chaîne vide si inconnue.
  static String duration(int? minutes) {
    final int? value = minutes;
    if (value == null || value <= 0) return '';
    if (value < 60) return '$value min';
    final int hours = value ~/ 60;
    final int rest = value % 60;
    return rest == 0 ? '$hours h' : '$hours h ${rest.toString().padLeft(2, '0')}';
  }

  /// Ligne de métadonnées : « 2014 · 2 h 49 · Film ».
  static String meta(ContentTileModel item) {
    return <String>[
      if (item.year != null) '${item.year}',
      duration(item.durationMinutes),
      type(item.contentType),
    ].where((String value) => value.isNotEmpty).join(' · ');
  }

  /// Ligne de métadonnées d'un résultat de recherche.
  static String searchMeta(SearchResultModel result) {
    return <String>[
      if (result.year != null) '${result.year}',
      result.subtitle,
    ].where((String value) => value.isNotEmpty).join(' · ');
  }

  /// Jetons de qualité extraits du badge (« 4K HDR » → [4K, HDR]).
  static List<String> qualityTokens(String badge) {
    final List<String> parts = badge
        .toUpperCase()
        .split(RegExp(r'[\s•·,\-/]+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    return parts.where(_qualityTokens.contains).toList();
  }

  /// Le badge contient-il une information de qualité exploitable ?
  static bool hasQuality(String badge) => qualityTokens(badge).isNotEmpty;

  /// Initiales d'un nom (avatar de profil).
  static String initials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  /// Résumé tronqué propre (coupe sur un mot, ajoute des points de suspension).
  static String clampText(String? value, {int maxChars = 132}) {
    final String text = (value ?? '').trim();
    if (text.length <= maxChars) return text;
    final String cut = text.substring(0, maxChars);
    final int lastSpace = cut.lastIndexOf(' ');
    final String trimmed = lastSpace > maxChars * 0.6 ? cut.substring(0, lastSpace) : cut;
    return '$trimmed…';
  }
}

/// Formatage des tailles (téléchargements).
abstract final class CinevaSizeLabels {
  /// « 2,3 Go » / « 850 Mo » à partir d'une taille en mégaoctets.
  static String fromMb(double mb) {
    if (mb <= 0) return '';
    if (mb >= 1024) return '${_fr((mb / 1024).toStringAsFixed(1))} Go';
    return '${mb.round()} Mo';
  }

  /// « 2,3 Go » / « 850 Mo » / « 512 Ko » à partir d'un nombre d'octets.
  static String fromBytes(int bytes) {
    if (bytes <= 0) return '';
    if (bytes >= 1073741824) return '${_fr((bytes / 1073741824).toStringAsFixed(1))} Go';
    if (bytes >= 1048576) return '${bytes ~/ 1048576} Mo';
    return '${bytes ~/ 1024} Ko';
  }

  static String _fr(String value) => value.replaceAll('.', ',');
}
