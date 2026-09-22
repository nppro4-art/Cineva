import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:dio/dio.dart';

/// Nature de la source Internet Archive collée par l'administrateur.
///
/// * [collection] : une collection (`feature_films`, `prelinger`, …) à énumérer ;
/// * [item] : un élément unique (`/details/<identifiant>`) ;
/// * [query] : une recherche libre limitée aux films.
enum ArchiveOrgSourceKind { collection, item, query }

/// Source Internet Archive résolue depuis un lien, un identifiant ou des
/// mots-clés.
///
/// Ce client ne vise **que du contenu librement diffusable** : Internet Archive
/// héberge des milliers de longs-métrages du domaine public avec leurs fichiers
/// vidéo directs. Aucune URL n'est devinée ni reconstruite « au hasard » : si un
/// élément ne propose pas de MP4 lisible, il est écarté et signalé.
class ArchiveOrgReference {
  const ArchiveOrgReference({required this.kind, required this.value});

  final ArchiveOrgSourceKind kind;
  final String value;

  bool get isItem => kind == ArchiveOrgSourceKind.item;

  bool get isCollection => kind == ArchiveOrgSourceKind.collection;

  /// Accepte :
  /// * un lien élément : `https://archive.org/details/sex_madness` ;
  /// * un lien de recherche : `https://archive.org/search?query=charlie+chaplin` ;
  /// * la syntaxe courte `collection:feature_films` ;
  /// * un identifiant nu (`sex_madness`) ;
  /// * des mots-clés libres (`night of the living dead`).
  ///
  /// Retourne `null` si rien d'exploitable n'est reconnu.
  static ArchiveOrgReference? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (_looksLikeUrl(trimmed)) {
      final uri = Uri.tryParse(trimmed.startsWith('http') ? trimmed : 'https://$trimmed');
      if (uri == null || !_isArchiveHost(uri.host)) return null;

      final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
      if (segments.length >= 2 && segments.first == 'details') {
        return ArchiveOrgReference(kind: ArchiveOrgSourceKind.item, value: segments[1]);
      }

      final query = uri.queryParameters['query']?.trim() ?? '';
      if (query.isNotEmpty) {
        return ArchiveOrgReference(kind: ArchiveOrgSourceKind.query, value: query);
      }
      return null;
    }

    final collection = RegExp(r'^collection:([\w\-.]+)$', caseSensitive: false).firstMatch(trimmed);
    if (collection != null) {
      return ArchiveOrgReference(kind: ArchiveOrgSourceKind.collection, value: collection.group(1)!);
    }

    // Un slug sans espace est traité comme un identifiant d'élément ; s'il
    // s'agit en réalité d'une collection, [ArchiveOrgClient.expand] le détecte
    // via `mediatype` et bascule sur l'énumération.
    if (RegExp(r'^[\w\-.]{3,100}$').hasMatch(trimmed)) {
      return ArchiveOrgReference(kind: ArchiveOrgSourceKind.item, value: trimmed);
    }

    return ArchiveOrgReference(kind: ArchiveOrgSourceKind.query, value: trimmed);
  }

  static bool _looksLikeUrl(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('archive.org/') ||
        lower.startsWith('www.archive.org/');
  }

  static bool _isArchiveHost(String host) {
    final lower = host.toLowerCase();
    return lower == 'archive.org' || lower.endsWith('.archive.org');
  }
}

/// Résultat brut de l'API de recherche (avant résolution du fichier vidéo).
class ArchiveOrgSearchHit {
  const ArchiveOrgSearchHit({
    required this.identifier,
    required this.title,
    this.releaseYear,
    this.downloads = 0,
  });

  final String identifier;
  final String title;
  final int? releaseYear;
  final int downloads;
}

/// Fiche Internet Archive complète et **jouable** : l'URL vidéo pointe vers un
/// MP4 réellement présent dans l'élément.
class ArchiveOrgItemDraft {
  const ArchiveOrgItemDraft({
    required this.identifier,
    required this.title,
    required this.synopsis,
    required this.genres,
    required this.languages,
    required this.directorName,
    required this.videoUrl,
    required this.videoFileName,
    required this.posterUrl,
    required this.itemPageUrl,
    required this.licenseLabel,
    required this.isLicenseOpen,
    this.releaseYear,
    this.durationMinutes,
    this.videoWidth,
    this.videoHeight,
    this.videoSizeBytes,
    this.subtitleUrl,
  });

  final String identifier;
  final String title;
  final String synopsis;
  final List<String> genres;
  final List<String> languages;
  final String directorName;

  /// URL directe du MP4 (`https://archive.org/download/<id>/<fichier>`).
  final String videoUrl;

  final String videoFileName;
  final String posterUrl;
  final String itemPageUrl;

  /// Libellé de licence tel que déclaré par l'élément (« Domaine public »,
  /// « CC BY », « Licence non précisée »…).
  final String licenseLabel;

  /// Vrai si une licence ouverte est **explicitement** déclarée. Les éléments
  /// sans mention restent importables, mais l'administrateur doit vérifier les
  /// droits avant publication.
  final bool isLicenseOpen;

  final int? releaseYear;
  final int? durationMinutes;
  final int? videoWidth;
  final int? videoHeight;
  final int? videoSizeBytes;
  final String? subtitleUrl;

  String get resolutionLabel {
    final width = videoWidth;
    final height = videoHeight;
    if (width == null || height == null || width <= 0 || height <= 0) return '—';
    return '${width}×$height';
  }

  /// Élément de catalogue Cineva (film). Non publié par défaut : l'import crée
  /// des brouillons que l'administrateur relit, complète (catégories, langues)
  /// puis publie — exactement comme le flux d'import TMDB.
  AdminCatalogItemModel toCatalogItem({
    bool isPublished = false,
    List<String> categoryIds = const <String>[],
  }) {
    return AdminCatalogItemModel(
      id: '',
      contentType: 'movie',
      title: title,
      synopsis: synopsis,
      genres: genres,
      audioLanguages: languages.isEmpty ? const <String>['Anglais'] : languages,
      subtitleLanguages: subtitleUrl == null ? const <String>['Aucun'] : languages,
      castNames: const <String>[],
      categoryIds: categoryIds,
      isFeatured: false,
      isPublished: isPublished,
      posterPath: posterUrl,
      backdropPath: posterUrl,
      videoPath: videoUrl,
      releaseYear: releaseYear,
      durationMinutes: durationMinutes,
      directorName: directorName.isEmpty ? null : directorName,
      metadata: <String, dynamic>{
        'source': 'archive_org',
        'archive_identifier': identifier,
        'archive_item_url': itemPageUrl,
        'archive_license': licenseLabel,
        'archive_license_open': isLicenseOpen,
        if (subtitleUrl != null) 'archive_subtitle_url': subtitleUrl,
        if (videoSizeBytes != null) 'archive_video_bytes': videoSizeBytes,
      },
    );
  }
}

/// Client Internet Archive : énumère une source (collection, élément ou
/// recherche) et résout pour chaque film le **fichier vidéo réel**.
///
/// APIs publiques utilisées, sans clé :
/// * `GET /advancedsearch.php?...&output=json` — énumération ;
/// * `GET /metadata/<identifiant>` — fiche + liste des fichiers ;
/// * `https://archive.org/services/img/<identifiant>` — affiche ;
/// * `https://archive.org/download/<identifiant>/<fichier>` — lecture directe.
class ArchiveOrgClient {
  ArchiveOrgClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://archive.org',
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 45),
              ),
            );

  /// Nombre d'éléments remontés par défaut lors d'une énumération.
  static const int defaultLimit = 24;

  final Dio _dio;

  /// Résout [reference] en fiches jouables.
  ///
  /// Pour une collection ou une recherche, chaque candidat est ensuite passé
  /// dans `/metadata/<id>` afin de vérifier la présence d'un MP4 : les éléments
  /// sans vidéo lisible sont écartés (jamais remplacés par une URL inventée).
  /// [onProgress] reçoit `(résolus, total)` pour alimenter la barre de l'UI.
  Future<List<ArchiveOrgItemDraft>> expand(
    ArchiveOrgReference reference, {
    int limit = defaultLimit,
    void Function(int resolved, int total)? onProgress,
  }) async {
    if (reference.isItem) {
      final metadata = await _fetchMetadata(reference.value);
      if (mediatypeOf(metadata) == 'collection') {
        return _resolveHits(
          await search(query: 'collection:(${reference.value})', limit: limit),
          onProgress: onProgress,
        );
      }
      final draft = parseItemMetadata(reference.value, metadata);
      if (draft == null) {
        throw AppFailure(
          'L’élément « ${reference.value} » ne propose aucun MP4 lisible : il n’est pas importable en l’état.',
          code: 'ARCHIVE_NO_VIDEO',
        );
      }
      onProgress?.call(1, 1);
      return <ArchiveOrgItemDraft>[draft];
    }

    final query = reference.isCollection
        ? 'collection:(${reference.value})'
        : buildSearchQuery(reference.value);
    return _resolveHits(await search(query: query, limit: limit), onProgress: onProgress);
  }

  Future<List<ArchiveOrgItemDraft>> _resolveHits(
    List<ArchiveOrgSearchHit> hits, {
    void Function(int resolved, int total)? onProgress,
  }) async {
    final drafts = <ArchiveOrgItemDraft>[];
    for (var index = 0; index < hits.length; index += 1) {
      final hit = hits[index];
      try {
        final draft = parseItemMetadata(hit.identifier, await _fetchMetadata(hit.identifier));
        if (draft != null) drafts.add(draft);
      } on AppFailure catch (_) {
        // Un élément injoignable ne doit pas faire échouer tout le lot : il est
        // simplement absent du résultat.
      }
      onProgress?.call(index + 1, hits.length);
    }

    if (drafts.isEmpty) {
      throw AppFailure(
        'Aucun film jouable trouvé dans cette source (éléments sans MP4 ou injoignables).',
        code: 'ARCHIVE_NO_RESULT',
      );
    }
    return drafts;
  }

  /// Recherche limitée aux films, triée par popularité.
  Future<List<ArchiveOrgSearchHit>> search({required String query, int limit = defaultLimit, int page = 1}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw AppFailure('Recherche Internet Archive vide.', code: 'ARCHIVE_EMPTY_QUERY');
    }

    // `num.clamp` renverrait un `num` : on borne à la main pour garder un int.
    final int rows = limit < 1 ? 1 : (limit > 100 ? 100 : limit);
    // Les crochets de `fl[]` / `sort[]` doivent arriver littéraux : on compose
    // la requête plutôt que de laisser le sérialiseur les ré-encoder.
    final path = '/advancedsearch.php'
        '?q=${Uri.encodeComponent(trimmed)}'
        '&fl%5B%5D=identifier&fl%5B%5D=title&fl%5B%5D=year&fl%5B%5D=downloads'
        '&rows=$rows&page=$page&output=json&sort%5B%5D=downloads+desc';

    late final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(path);
    } on DioException catch (error) {
      throw _failureFrom(error);
    }

    final hits = parseSearchResponse(response.data);
    if (hits.isEmpty) {
      throw AppFailure('Aucun film trouvé pour « $trimmed » sur Internet Archive.', code: 'ARCHIVE_NO_RESULT');
    }
    return hits;
  }

  /// Récupère une fiche unique (avec son fichier vidéo) par identifiant.
  Future<ArchiveOrgItemDraft> fetchItem(String identifier) async {
    final draft = parseItemMetadata(identifier, await _fetchMetadata(identifier));
    if (draft == null) {
      throw AppFailure(
        'L’élément « $identifier » ne propose aucun MP4 lisible.',
        code: 'ARCHIVE_NO_VIDEO',
      );
    }
    return draft;
  }

  Future<Map<String, dynamic>> _fetchMetadata(String identifier) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) {
      throw AppFailure('Identifiant Internet Archive vide.', code: 'ARCHIVE_BAD_ID');
    }

    late final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>('/metadata/${Uri.encodeComponent(trimmed)}');
    } on DioException catch (error) {
      throw _failureFrom(error, identifier: trimmed);
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw AppFailure(
        'Réponse Internet Archive illisible pour « $trimmed ».',
        code: 'ARCHIVE_BAD_RESPONSE',
      );
    }
    return data;
  }

  AppFailure _failureFrom(DioException error, {String? identifier}) {
    final status = error.response?.statusCode;
    final where = identifier == null ? '' : ' pour « $identifier »';
    if (status == 404) {
      return AppFailure('Élément Internet Archive introuvable$where.', code: 'ARCHIVE_NOT_FOUND');
    }
    if (status == 403 || status == 429) {
      return AppFailure(
        'Internet Archive limite les requêtes$where. Réessayez dans quelques instants ou réduisez le nombre d’éléments.',
        code: 'ARCHIVE_RATE_LIMITED',
      );
    }
    return AppFailure(
      'Import Internet Archive impossible$where : ${error.message ?? 'erreur réseau'}',
      code: 'ARCHIVE_ERROR',
    );
  }

  // ---------------------------------------------------------------- analyse

  /// Restreint une recherche libre aux films, sans toucher aux requêtes déjà
  /// qualifiées (`collection:…`, `mediatype:…`).
  static String buildSearchQuery(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    final lower = trimmed.toLowerCase();
    if (lower.contains('mediatype:') || lower.startsWith('collection:')) return trimmed;
    return '$trimmed AND mediatype:(movies)';
  }

  /// `mediatype` déclaré par l'élément (`movies`, `collection`, …).
  static String? mediatypeOf(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    if (metadata is! Map) return null;
    return _string(metadata, 'mediatype');
  }

  /// Analyse la réponse d'`/advancedsearch.php`.
  static List<ArchiveOrgSearchHit> parseSearchResponse(dynamic json) {
    if (json is! Map) return const <ArchiveOrgSearchHit>[];
    final response = json['response'];
    if (response is! Map) return const <ArchiveOrgSearchHit>[];
    final docs = response['docs'];
    if (docs is! List) return const <ArchiveOrgSearchHit>[];

    final hits = <ArchiveOrgSearchHit>[];
    for (final entry in docs) {
      if (entry is! Map) continue;
      final identifier = _string(entry, 'identifier');
      if (identifier == null) continue;
      hits.add(
        ArchiveOrgSearchHit(
          identifier: identifier,
          title: _string(entry, 'title') ?? identifier,
          releaseYear: _year(_string(entry, 'year') ?? _string(entry, 'date')),
          downloads: int.tryParse(_string(entry, 'downloads') ?? '') ?? 0,
        ),
      );
    }
    return hits;
  }

  /// Analyse la réponse de `/metadata/<id>` et choisit le fichier vidéo.
  ///
  /// Retourne `null` quand l'élément n'offre **aucun MP4** : on préfère écarter
  /// un titre plutôt que d'enregistrer une URL qui ne lira rien.
  static ArchiveOrgItemDraft? parseItemMetadata(String identifier, dynamic json) {
    if (json is! Map) return null;
    final metadata = json['metadata'];
    if (metadata is! Map) return null;

    final video = _selectVideoFile(json['files']);
    if (video == null) return null;

    final fileName = _string(video, 'name');
    if (fileName == null) return null;

    final title = _string(metadata, 'title') ?? identifier;
    final lengthSeconds = double.tryParse(_string(video, 'length') ?? '');
    final license = _license(metadata);

    return ArchiveOrgItemDraft(
      identifier: identifier,
      title: title,
      synopsis: _cleanDescription(_rawList(metadata['description'])),
      genres: _genres(metadata),
      languages: _languages(metadata),
      directorName: _string(metadata, 'creator') ?? '',
      videoUrl: downloadUrlFor(identifier, fileName),
      videoFileName: fileName,
      posterUrl: 'https://archive.org/services/img/$identifier',
      itemPageUrl: 'https://archive.org/details/$identifier',
      licenseLabel: license.$1,
      isLicenseOpen: license.$2,
      releaseYear: _year(
        _string(metadata, 'year') ?? _string(metadata, 'date') ?? _string(metadata, 'publicdate'),
      ),
      durationMinutes: (lengthSeconds != null && lengthSeconds > 0) ? (lengthSeconds / 60).round() : null,
      videoWidth: int.tryParse(_string(video, 'width') ?? ''),
      videoHeight: int.tryParse(_string(video, 'height') ?? ''),
      videoSizeBytes: int.tryParse(_string(video, 'size') ?? ''),
      subtitleUrl: _subtitleUrl(identifier, json['files']),
    );
  }

  /// URL de lecture directe d'un fichier de l'élément.
  static String downloadUrlFor(String identifier, String fileName) {
    final encodedPath = fileName
        .split('/')
        .map((segment) => Uri.encodeComponent(segment))
        .join('/');
    return 'https://archive.org/download/${Uri.encodeComponent(identifier)}/$encodedPath';
  }

  /// Choisit le MP4 le plus défini, en préférant le dérivé optimisé pour la
  /// lecture en continu (ExoPlayer sur Android, libmpv sur Windows lisent le
  /// H.264 nativement — pas le MPEG2 ni l'Ogg Theora d'origine).
  static Map<dynamic, dynamic>? _selectVideoFile(dynamic files) {
    if (files is! List) return null;

    Map<dynamic, dynamic>? best;
    var bestScore = -1;
    for (final entry in files) {
      if (entry is! Map) continue;
      final name = (_string(entry, 'name') ?? '').toLowerCase();
      final format = (_string(entry, 'format') ?? '').toLowerCase();
      final isPlayable = name.endsWith('.mp4') || format.contains('h.264') || format.contains('mp4');
      if (!isPlayable) continue;

      final height = int.tryParse(_string(entry, 'height') ?? '') ?? 0;
      var score = height * 10;
      if (_string(entry, 'source') == 'derivative') score += 5;
      if (score > bestScore) {
        bestScore = score;
        best = entry;
      }
    }
    return best;
  }

  static String? _subtitleUrl(String identifier, dynamic files) {
    if (files is! List) return null;
    for (final entry in files) {
      if (entry is! Map) continue;
      final name = _string(entry, 'name');
      if (name == null) continue;
      final lower = name.toLowerCase();
      if (lower.endsWith('.srt') || lower.endsWith('.vtt')) {
        return downloadUrlFor(identifier, name);
      }
    }
    return null;
  }

  /// (libellé, licence explicitement ouverte).
  static (String, bool) _license(Map<dynamic, dynamic> metadata) {
    final licenseUrl = (_string(metadata, 'licenseurl') ?? _string(metadata, 'license') ?? '').toLowerCase();
    final rights = (_string(metadata, 'rights') ?? '').toLowerCase();
    final haystack = '$licenseUrl $rights';

    if (haystack.contains('publicdomain') || haystack.contains('public domain')) {
      return ('Domaine public', true);
    }
    if (haystack.contains('creativecommons.org')) {
      if (haystack.contains('/by-nc') || haystack.contains('/by-nd')) {
        return ('Creative Commons (usage restreint)', true);
      }
      if (haystack.contains('/zero') || haystack.contains('/by/')) return ('Creative Commons', true);
      return ('Creative Commons', true);
    }
    if (haystack.trim().isEmpty) return ('Licence non précisée', false);
    return ('Licence déclarée', false);
  }

  static List<String> _genres(Map<dynamic, dynamic> metadata) {
    const denied = <String>{
      'public domain',
      'feature film',
      'feature films',
      'feature_films',
      'movie',
      'movies',
      'film',
      'films',
    };
    final genres = <String>[];
    for (final subject in _stringList(metadata, 'subject')) {
      if (denied.contains(subject.toLowerCase())) continue;
      genres.add(subject);
      if (genres.length >= 6) break;
    }
    return genres;
  }

  static List<String> _languages(Map<dynamic, dynamic> metadata) {
    final languages = <String>[];
    for (final value in _stringList(metadata, 'language')) {
      if (languages.length >= 3) break;
      languages.add(value);
    }
    return languages;
  }

  static int? _year(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'(1[89]\d{2}|20\d{2}|21\d{2})').firstMatch(raw);
    if (match == null) return null;
    final year = int.tryParse(match.group(0)!);
    if (year == null || year < 1870 || year > 2100) return null;
    return year;
  }

  /// Valeur texte d'un champ : Internet Archive renvoie tantôt une chaîne,
  /// tantôt une liste de chaînes.
  static String? _string(Map<dynamic, dynamic> map, String key) {
    final value = map[key];
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) return value.toString();
    if (value is List) {
      for (final entry in value) {
        if (entry is String && entry.trim().isNotEmpty) return entry.trim();
        if (entry is num) return entry.toString();
      }
    }
    return null;
  }

  static List<String> _stringList(Map<dynamic, dynamic> map, String key) {
    final collected = <String>[];
    for (final value in _rawList(map[key])) {
      for (final part in value.split(';')) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty && !collected.contains(trimmed)) collected.add(trimmed);
      }
    }
    return collected;
  }

  static List<String> _rawList(dynamic value) {
    if (value is String) return <String>[value];
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return const <String>[];
  }

  /// Description archive.org : HTML brut, entities et sauts de ligne. On rend un
  /// texte propre, borné, sans rien inventer.
  static String _cleanDescription(List<String> raw) {
    if (raw.isEmpty) return '';
    final joined = raw.join('\n');
    var text = joined.replaceAll(RegExp(r'<[^>]*>'), ' ');
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', '’')
        .replaceAll('&nbsp;', ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= 1600) return text;
    final cut = text.substring(0, 1600);
    final lastSpace = cut.lastIndexOf(' ');
    return '${(lastSpace > 1200 ? cut.substring(0, lastSpace) : cut).trim()}…';
  }
}
