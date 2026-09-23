/// Qualification d'une adresse vidéo **avant** de la donner à un moteur de
/// lecture.
///
/// Le lecteur Cineva s'appuie sur un vrai moteur média (`video_player` sur
/// mobile, `media_kit` sur desktop) : il décode un **flux** (MP4/H.264, MKV,
/// WebM, HLS, DASH) ou un fichier local. Une adresse qui renvoie du HTML —
/// iframe d'un lecteur tiers, page de visionnage, lien de type
/// `…/watch?v=…` — ne contient aucun flux décodable : aucun réglage du lecteur
/// ne peut la rendre lisible.
///
/// Sans cette qualification, le moteur tente l'ouverture, charge pendant de
/// longues secondes, puis échoue avec un message cryptique
/// (« failed to load video »). Ici l'administrateur et l'abonné voient tout de
/// suite ce qui est attendu.
library;

/// Nature d'une adresse vidéo.
enum MediaSourceKind {
  /// Fichier local (téléchargement, chemin disque, `file://`).
  localFile,

  /// Flux HLS (`.m3u8`).
  hlsStream,

  /// Flux DASH (`.mpd`).
  dashStream,

  /// Fichier vidéo en accès direct (`.mp4`, `.mkv`, `.webm`…).
  directVideo,

  /// Page web / lecteur tiers embarqué : pas un flux.
  webPage,

  /// Fichier audio seul : pas une vidéo.
  audioOnly,

  /// Aucune adresse renseignée.
  empty,

  /// Adresse non reconnue : à tenter, la sonde réseau tranchera.
  unknown,
}

const Set<String> videoFileExtensions = <String>{
  'mp4',
  'm4v',
  'mov',
  'mkv',
  'webm',
  'ts',
  'm2ts',
  'avi',
  'mpg',
  'mpeg',
  '3gp',
  'ogv',
};

const Set<String> audioFileExtensions = <String>{
  'mp3',
  'm4a',
  'aac',
  'flac',
  'opus',
  'ogg',
  'wav',
};

const Set<String> webPageExtensions = <String>{
  'html',
  'htm',
  'php',
  'asp',
  'aspx',
  'jsp',
  'shtml',
};

/// Marqueurs d'URL qui renvoient une page (lecteur tiers embarqué, page de
/// visionnage). Volontairement restreints aux cas sans ambiguïté : un chemin
/// comme `/stream/…` peut très bien servir un fichier direct.
const List<String> webPageMarkers = <String>[
  '/iframe',
  '/embed/',
  '/watch?v=',
  '/watch/',
  'youtube.com',
  'youtu.be',
  'dailymotion.com',
  'vimeo.com',
  'twitch.tv',
  '/pages/',
];

/// Explications en clair, réutilisées par le lecteur et par l'admin.
const String mediaSourceEmptyReason = 'Aucune adresse vidéo n’est renseignée pour ce contenu.';

const String mediaSourceAudioReason =
    'Cette adresse pointe vers un fichier audio, pas vers une vidéo.';

const String mediaSourceWebPageReason =
    'Cette adresse renvoie une page web (lecteur tiers ou iframe), pas un '
    'fichier vidéo : aucun moteur de lecture ne peut en tirer un flux. Le '
    'lecteur accepte un MP4/H.264 (ou MKV, WebM, MOV) en accès direct, un flux '
    'HLS (.m3u8), un fichier local, ou un contenu importé d’Internet Archive. '
    'Une page HTML ne se lit pas, quel que soit le réglage du lecteur.';

final RegExp _windowsPath = RegExp(r'^[A-Za-z]:[\\/]');

/// Résultat de la qualification d'une adresse.
class MediaSourceAssessment {
  const MediaSourceAssessment({required this.kind, required this.url, this.reason});

  /// Nature détectée.
  final MediaSourceKind kind;

  /// Adresse telle que reçue (trimée).
  final String url;

  /// Explication lisible quand la lecture est impossible, sinon `null`.
  final String? reason;

  /// `true` si un moteur de lecture peut tenter l'ouverture.
  bool get isPlayable =>
      kind != MediaSourceKind.webPage &&
      kind != MediaSourceKind.audioOnly &&
      kind != MediaSourceKind.empty;

  /// Message destiné à l'écran, vide si la source est lisible.
  String get explanation => reason ?? '';

  @override
  String toString() => 'MediaSourceAssessment(${kind.name}, $url)';
}

/// Qualifie [rawUrl] sans aucun accès réseau.
///
/// Les adresses non reconnues renvoient [MediaSourceKind.unknown] : on laisse
/// alors le moteur (ou la sonde [MediaStreamProbe]) trancher plutôt que de
/// bloquer un flux légitime servi sans extension.
MediaSourceAssessment assessMediaSource(String? rawUrl) {
  final String url = (rawUrl ?? '').trim();
  if (url.isEmpty) {
    return const MediaSourceAssessment(
      kind: MediaSourceKind.empty,
      url: '',
      reason: mediaSourceEmptyReason,
    );
  }

  final String lower = url.toLowerCase();

  if (lower.startsWith('file://') || url.startsWith('/') || _windowsPath.hasMatch(url)) {
    return MediaSourceAssessment(kind: MediaSourceKind.localFile, url: url);
  }

  final String path = _pathWithoutQuery(url).toLowerCase();
  final String extension = _extensionOf(path);

  if (extension == 'm3u8' || lower.contains('.m3u8')) {
    return MediaSourceAssessment(kind: MediaSourceKind.hlsStream, url: url);
  }
  if (extension == 'mpd') {
    return MediaSourceAssessment(kind: MediaSourceKind.dashStream, url: url);
  }
  if (videoFileExtensions.contains(extension)) {
    return MediaSourceAssessment(kind: MediaSourceKind.directVideo, url: url);
  }
  if (audioFileExtensions.contains(extension)) {
    return MediaSourceAssessment(
      kind: MediaSourceKind.audioOnly,
      url: url,
      reason: mediaSourceAudioReason,
    );
  }
  if (webPageExtensions.contains(extension) ||
      webPageMarkers.any((String marker) => lower.contains(marker))) {
    return MediaSourceAssessment(
      kind: MediaSourceKind.webPage,
      url: url,
      reason: mediaSourceWebPageReason,
    );
  }

  return MediaSourceAssessment(kind: MediaSourceKind.unknown, url: url);
}

/// Raison bloquante de [rawUrl], ou `null` si la lecture peut être tentée.
String? mediaSourceBlockingReason(String? rawUrl) {
  final MediaSourceAssessment assessment = assessMediaSource(rawUrl);
  return assessment.isPlayable ? null : assessment.explanation;
}

/// Chemin sans paramètre de requête ni fragment.
String _pathWithoutQuery(String url) {
  final int hash = url.indexOf('#');
  final String withoutFragment = hash >= 0 ? url.substring(0, hash) : url;
  final int question = withoutFragment.indexOf('?');
  return question >= 0 ? withoutFragment.substring(0, question) : withoutFragment;
}

/// Extension basse du dernier segment de chemin, vide si aucune.
String _extensionOf(String path) {
  final int slash = path.lastIndexOf('/');
  final String last = slash >= 0 ? path.substring(slash + 1) : path;
  final int dot = last.lastIndexOf('.');
  if (dot < 0 || dot == last.length - 1) return '';
  return last.substring(dot + 1);
}
