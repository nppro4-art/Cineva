/// Titre probable extrait d'une URL de fichier vidéo.
///
/// Sert uniquement à pré-remplir une recherche TMDB : l'administrateur fournit
/// le fichier (dont il détient les droits), TMDB fournit les métadonnées
/// publiques. Rien n'est deviné en silence — la valeur est toujours affichée et
/// modifiable avant recherche, et le choix de la fiche reste manuel.
class MediaUrlTitleHint {
  const MediaUrlTitleHint({required this.title, required this.fileName, this.year});

  /// Titre nettoyé du jargon de release (« inception »), vide si le nom de
  /// fichier n'est pas exploitable (empreinte, UUID, identifiant opaque).
  final String title;

  /// Nom du fichier tel quel, pour affichage (« inception.2010.1080p.mp4 »).
  final String fileName;

  /// Année détectée dans le nom de fichier, si présente.
  final int? year;

  bool get hasTitle => title.isNotEmpty;
}

/// Jargon de release retiré du titre : qualité, codec, source, audio, rip.
const Set<String> kMediaReleaseNoise = <String>{
  '4k', '2160p', '1440p', '1080p', '1080', '720p', '720', '576p', '480p', '360p',
  'x264', 'x265', 'h264', 'h265', 'hevc', 'avc', 'xvid', 'divx', 'av1',
  'bluray', 'blu', 'ray', 'brrip', 'bdrip', 'webrip', 'web', 'dl', 'hdtv', 'dvdrip',
  'dvd', 'hdrip', 'remux', 'proper', 'repack', 'remastered', 'uncut',
  'ac3', 'dts', 'aac', 'truehd', 'atmos', 'md', 'ld', '5.1', '7.1', '2.0',
  'vostfr', 'vost', 'truefrench', 'french', 'francais', 'français', 'eng',
  'multi', 'subforced', 'hdr', 'hdr10', 'dovi', 'imax',
};

/// Extrait un titre probable de [raw] : URL complète, chemin de fichier ou nom
/// nu (`https://cdn.cineva.app/movies/inception.2010.1080p.mp4`,
/// `/storage/emulated/0/Cineva/charlie_chaplin_the_kid.mp4`, `film-vf.mp4`).
///
/// Retourne `null` si l'entrée est vide ou sans nom de fichier exploitable ;
/// retourne un [MediaUrlTitleHint] avec un [MediaUrlTitleHint.title] vide quand
/// le nom est opaque (empreinte, UUID) — l'administrateur saisit alors le titre.
MediaUrlTitleHint? titleHintFromMediaUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final fileName = _fileNameOf(trimmed);
  if (fileName.isEmpty) return null;

  final base = _stripExtension(fileName);
  if (base.trim().isEmpty) {
    return MediaUrlTitleHint(title: '', fileName: fileName);
  }

  // Manifeste HLS/DASH ou nom technique : aucun titre à en tirer, l'opérateur
  // le saisit (mieux vaut un champ vide qu'une recherche TMDB fantaisiste).
  if (kMediaManifestNames.contains(base.trim().toLowerCase())) {
    return MediaUrlTitleHint(title: '', fileName: fileName, year: _yearOf(base));
  }

  final year = _yearOf(base);
  final tokens = base
      .replaceAll(RegExp(r'[._+]+'), ' ')
      .split(RegExp(r'[\s\-]+'))
      .where((token) => token.trim().isNotEmpty)
      .toList();

  final cleaned = <String>[];
  for (final token in tokens) {
    final lower = token.toLowerCase();
    if (kMediaReleaseNoise.contains(lower)) continue;
    if (year != null && RegExp(r'^(19|20|21)\d{2}$').hasMatch(lower)) continue;
    cleaned.add(token);
  }

  // Tout le nom était du jargon (« 1080p.x264.webrip ») : on garde la base
  // plutôt que de renvoyer un titre vide.
  final source = cleaned.isEmpty ? tokens : cleaned;
  final readable = source.where((token) => !_isOpaqueToken(token)).toList();
  final title = (readable.isEmpty ? source : readable).join(' ').trim();

  if (title.isEmpty || readable.isEmpty || _isOpaqueName(base)) {
    return MediaUrlTitleHint(title: '', fileName: fileName, year: year);
  }
  return MediaUrlTitleHint(title: title, fileName: fileName, year: year);
}

String _fileNameOf(String raw) {
  final withoutQuery = raw.split('?').first.split('#').first;
  final segments = withoutQuery.split('/').where((segment) => segment.trim().isNotEmpty).toList();
  final last = segments.isEmpty ? withoutQuery : segments.last;
  try {
    return Uri.decodeComponent(last).trim();
  } on FormatException {
    return last.trim();
  }
}

String _stripExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0) return fileName;
  final extension = fileName.substring(dot + 1).toLowerCase();
  const videoExtensions = <String>{
    'mp4', 'mkv', 'mov', 'webm', 'avi', 'm4v', 'ts', 'm3u8', 'mpd', 'flv', 'wmv', 'mpg', 'mpeg', 'ogv',
  };
  if (!videoExtensions.contains(extension)) return fileName;
  return fileName.substring(0, dot);
}

int? _yearOf(String value) {
  final match = RegExp(r'(?:19|20|21)\d{2}').firstMatch(value);
  if (match == null) return null;
  final year = int.tryParse(match.group(0)!);
  if (year == null || year < 1870 || year > 2100) return null;
  return year;
}

/// Noms de fichiers qui ne portent aucun titre (manifestes, flux génériques).
const Set<String> kMediaManifestNames = <String>{
  'master', 'index', 'playlist', 'manifest', 'stream', 'hls', 'dash',
  'video', 'movie', 'film', 'media', 'content', 'output', 'final',
};

/// Nom de fichier entièrement technique : empreinte, UUID, identifiant hexadécimal.
bool _isOpaqueName(String base) {
  final compact = base.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '').toLowerCase();
  if (compact.length >= 16 && RegExp(r'^[0-9a-f]+$').hasMatch(compact)) return true;
  if (compact.length >= 20 && !RegExp(r'[aeiouy]').hasMatch(compact)) return true;
  return false;
}

/// Empreinte, UUID ou identifiant technique : aucun titre exploitable.
bool _isOpaqueToken(String token) {
  final lower = token.toLowerCase();
  if (lower.length >= 10 && RegExp(r'^[0-9a-f]+$').hasMatch(lower)) return true;
  if (lower.length >= 16 && !RegExp(r'[aeiouy]{2}').hasMatch(lower)) return true;
  return false;
}
