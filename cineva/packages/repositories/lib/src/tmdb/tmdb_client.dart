import 'package:cineva_shared/cineva_shared.dart';
import 'package:dio/dio.dart';
import 'tmdb_search_plan.dart';

/// Type de média supporté par l'import TMDB.
enum TmdbMediaType { movie, series }

/// Référence TMDB extraite d'un lien complet ou d'un identifiant brut.
class TmdbReference {
  const TmdbReference({required this.mediaType, required this.id});

  final TmdbMediaType mediaType;
  final String id;

  bool get isMovie => mediaType == TmdbMediaType.movie;

  /// Accepte :
  /// - un lien TMDB complet : `https://www.themoviedb.org/movie/603`,
  ///   `https://www.themoviedb.org/fr/movie/603`, `.../tv/1396` ;
  /// - un identifiant numérique seul (interprété comme un film).
  ///
  /// Retourne `null` si l'entrée n'est pas une référence TMDB exploitable.
  static TmdbReference? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final urlMatch =
        RegExp(r'themoviedb\.org(?:/[a-z]{2})?/(movie|tv)/(\d+)', caseSensitive: false).firstMatch(trimmed);
    if (urlMatch != null) {
      final type = urlMatch.group(1)!.toLowerCase();
      return TmdbReference(
        mediaType: type == 'tv' ? TmdbMediaType.series : TmdbMediaType.movie,
        id: urlMatch.group(2)!,
      );
    }

    if (RegExp(r'^\d{1,8}$').hasMatch(trimmed)) {
      return TmdbReference(mediaType: TmdbMediaType.movie, id: trimmed);
    }

    return null;
  }
}

/// Fiche TMDB pré-remplie, prête à être saisie dans l'éditeur de catalogue.
/// Aucune donnée n'est persistée : l'administrateur valide l'enregistrement.
class TmdbContentDraft {
  const TmdbContentDraft({
    required this.mediaType,
    required this.title,
    required this.originalTitle,
    required this.synopsis,
    required this.genres,
    required this.castNames,
    required this.directorName,
    required this.trailerUrl,
    this.posterPath,
    this.backdropPath,
    this.releaseYear,
    this.durationMinutes,
    this.ageRating,
    this.rating,
  });

  final TmdbMediaType mediaType;
  final String title;
  final String originalTitle;
  final String synopsis;
  final List<String> genres;
  final List<String> castNames;
  final String directorName;
  final String trailerUrl;
  final String? posterPath;
  final String? backdropPath;
  final int? releaseYear;
  final int? durationMinutes;
  final String? ageRating;
  final double? rating;
}

/// Résultat de recherche TMDB : assez léger pour une liste de candidats, avec
/// de quoi le convertir en [TmdbReference] pour charger la fiche complète.
class TmdbSearchHit {
  const TmdbSearchHit({
    required this.id,
    required this.mediaType,
    required this.title,
    required this.originalTitle,
    this.posterUrl,
    this.releaseYear,
    this.overview = '',
    this.rating,
  });

  final String id;
  final TmdbMediaType mediaType;
  final String title;
  final String originalTitle;

  /// Affiche w185 : suffisant pour une liste de candidats.
  final String? posterUrl;

  final int? releaseYear;
  final String overview;
  final double? rating;

  String get yearLabel => releaseYear?.toString() ?? 'année inconnue';

  TmdbReference toReference() => TmdbReference(mediaType: mediaType, id: id);
}

/// Client API TMDB (v3) : récupère les métadonnées publiques d'un film ou
/// d'une série pour l'import par lien dans la console d'administration.
///
/// La clé est injectée à la compilation via `--dart-define=TMDB_API_KEY=...`
/// (repli : clé projet, cf. .github/workflows/build-android.yml).
class TmdbClient {
  TmdbClient({String? apiKey, Dio? dio})
      : _apiKey = (apiKey == null || apiKey.isEmpty) ? _defaultApiKey : apiKey,
        _dio = dio ??
            Dio(
              BaseOptions(
                // Barre finale : dio concatène `baseUrl + path` (les chemins
                // d'appel sont relatifs, ex. `movie/603`).
                baseUrl: 'https://api.themoviedb.org/3/',
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
              ),
            );

  static const String _defaultApiKey = String.fromEnvironment(
    'TMDB_API_KEY',
    defaultValue: '953735af94772da319cdbfdf861712a6',
  );

  final String _apiKey;
  final Dio _dio;

  /// Récupère la fiche TMDB correspondant à [reference].
  ///
  /// Lève [AppFailure] avec un message lisible (introuvable, clé invalide,
  /// erreur réseau) que l'UI peut afficher tel quel.
  Future<TmdbContentDraft> fetch(TmdbReference reference) =>
      _fetch(reference.mediaType, reference.id);

  Future<TmdbContentDraft> _fetch(TmdbMediaType mediaType, String id) async {
    final path = mediaType == TmdbMediaType.movie ? 'movie' : 'tv';
    late final Response<dynamic> response;
    try {
      response = await _dio.get(
        '$path/$id',
        queryParameters: <String, dynamic>{
          'api_key': _apiKey,
          'language': 'fr-FR',
          'append_to_response': 'credits,videos',
        },
      );
    } on DioException catch (error) {
      throw _failureFrom(error, id: id);
    }

    final data = response.data;
    if (response.statusCode != 200 || data is! Map<String, dynamic>) {
      throw AppFailure('Le titre TMDB (id $id) est introuvable ou a été retiré.', code: 'TMDB_NOT_FOUND');
    }

    return _mapDraft(mediaType, data);
  }

  AppFailure _failureFrom(DioException error, {required String id}) {
    final status = error.response?.statusCode;
    if (status == 404) {
      return AppFailure('Aucun titre TMDB ne correspond à ce lien (id $id).', code: 'TMDB_NOT_FOUND');
    }
    if (status == 401) {
      return AppFailure('Clé TMDB invalide ou expirée — vérifiez TMDB_API_KEY.', code: 'TMDB_UNAUTHORIZED');
    }
    final cause = error.message ?? 'erreur réseau';
    return AppFailure('Import TMDB impossible : $cause', code: 'TMDB_ERROR');
  }

  /// Cherche des titres correspondant à [query].
  ///
  /// Utilisé par l'import « URL vidéo » : le nom du fichier donne une piste de
  /// recherche, l'administrateur choisit ensuite la bonne fiche parmi les
  /// candidats renvoyés. Aucun choix automatique.
  Future<List<TmdbSearchHit>> searchTitles({
    required String query,
    TmdbMediaType mediaType = TmdbMediaType.movie,
    int? year,
    int limit = 12,
  }) async {
    // Une seule requête suffit rarement : une année restée dans le titre, un
    // accent oublié, un sous-titre français complet (« Vaiana, la légende du
    // bout du monde ») ou un titre original anglais renvoient zéro fiche. On
    // essaie donc du plus précis au plus large, et la première tentative
    // fructueuse gagne.
    final plan = buildTmdbQueryPlan(rawQuery: query, year: year);
    if (plan.isEmpty) return const <TmdbSearchHit>[];

    for (final attempt in plan.attempts) {
      final hits = await _searchOnce(
        query: attempt.query,
        year: attempt.year,
        language: attempt.language,
        mediaType: mediaType,
        limit: limit,
      );
      if (hits.isNotEmpty) return hits;
    }
    return const <TmdbSearchHit>[];
  }

  /// Un appel `search/movie` ou `search/tv`.
  Future<List<TmdbSearchHit>> _searchOnce({
    required String query,
    required String language,
    required TmdbMediaType mediaType,
    required int limit,
    int? year,
  }) async {
    late final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        mediaType == TmdbMediaType.movie ? 'search/movie' : 'search/tv',
        queryParameters: <String, dynamic>{
          'api_key': _apiKey,
          'language': language,
          'query': query,
          'include_adult': false,
          if (year != null)
            (mediaType == TmdbMediaType.movie ? 'year' : 'first_air_date_year'): year,
        },
      );
    } on DioException catch (error) {
      throw _failureFrom(error, id: query);
    }

    final hits = parseSearchResults(response.data, mediaType);
    if (limit <= 0 || hits.length <= limit) return hits;
    return hits.sublist(0, limit);
  }

  /// Analyse la réponse de `search/movie` ou `search/tv`.
  static List<TmdbSearchHit> parseSearchResults(dynamic json, TmdbMediaType mediaType) {
    if (json is! Map) return const <TmdbSearchHit>[];
    final results = json['results'];
    if (results is! List) return const <TmdbSearchHit>[];

    final hits = <TmdbSearchHit>[];
    for (final entry in results) {
      if (entry is! Map) continue;
      final rawId = entry['id'];
      final id = rawId is num ? rawId.toInt() : int.tryParse('$rawId');
      if (id == null) continue;

      final rawTitle = entry['title'] ?? entry['name'];
      final title = rawTitle is String ? rawTitle.trim() : '';
      if (title.isEmpty) continue;

      final rawOriginal = entry['original_title'] ?? entry['original_name'];
      final originalTitle = rawOriginal is String && rawOriginal.trim().isNotEmpty
          ? rawOriginal.trim()
          : title;

      final posterPath = entry['poster_path'];
      final overview = entry['overview'];
      final rating = entry['vote_average'];

      hits.add(
        TmdbSearchHit(
          id: id.toString(),
          mediaType: mediaType,
          title: title,
          originalTitle: originalTitle,
          posterUrl: posterPath is String && posterPath.startsWith('/')
              ? 'https://image.tmdb.org/t/p/w185$posterPath'
              : null,
          releaseYear: _yearOfDate(entry['release_date'] ?? entry['first_air_date']),
          overview: overview is String ? overview.trim() : '',
          rating: rating is num ? rating.toDouble() : null,
        ),
      );
    }
    return hits;
  }

  static int? _yearOfDate(dynamic value) {
    if (value is! String) return null;
    final match = RegExp(r'(?:19|20|21)\d{2}').firstMatch(value);
    if (match == null) return null;
    final year = int.tryParse(match.group(0)!);
    if (year == null || year < 1870 || year > 2100) return null;
    return year;
  }

  TmdbContentDraft _mapDraft(TmdbMediaType mediaType, Map<String, dynamic> data) {
    final title = data['title'] as String? ?? data['name'] as String? ?? 'Sans titre';
    final originalTitle = data['original_title'] as String? ??
        data['original_name'] as String? ??
        title;
    final posterPath = _imageUrl(data['poster_path'] as String?, width: 500);
    final backdropPath = _imageUrl(data['backdrop_path'] as String?, width: 1280);

    int? releaseYear;
    final releaseDate = data['release_date'] as String? ?? data['first_air_date'] as String?;
    if (releaseDate != null && releaseDate.length >= 4) {
      releaseYear = int.tryParse(releaseDate.substring(0, 4));
    }

    int? durationMinutes;
    final runtime = data['runtime'] as num?;
    if (runtime != null && runtime.toInt() > 0) {
      durationMinutes = runtime.toInt();
    } else if (data['episode_run_time'] is List) {
      for (final entry in data['episode_run_time'] as List) {
        if (entry is num && entry.toInt() > 0) {
          durationMinutes = entry.toInt();
          break;
        }
      }
    }

    final genres = <String>[];
    if (data['genres'] is List) {
      for (final entry in data['genres'] as List) {
        final name = entry is Map ? entry['name'] : null;
        if (name is String && name.trim().isNotEmpty) genres.add(name.trim());
      }
    }

    var directorName = '';
    final castNames = <String>[];
    final credits = data['credits'];
    if (credits is Map) {
      final crew = credits['crew'];
      if (crew is List) {
        for (final entry in crew) {
          final member = entry is Map ? entry : null;
          if (member == null) continue;
          if ((member['job'] as String?)?.toLowerCase() == 'director') {
            final name = member['name'] as String?;
            if (name != null && name.trim().isNotEmpty) {
              directorName = name.trim();
              break;
            }
          }
        }
      }
      final cast = credits['cast'];
      if (cast is List) {
        for (final entry in cast) {
          final member = entry is Map ? entry : null;
          if (member == null) continue;
          final name = member['credit_name'] as String? ?? member['name'] as String?;
          if (name == null || name.trim().isEmpty) continue;
          castNames.add(name.trim());
          if (castNames.length >= 8) break;
        }
      }
    }

    var trailerUrl = '';
    String? trailerKey;
    String? teaserKey;
    final videos = data['videos'];
    if (videos is Map && videos['results'] is List) {
      for (final entry in videos['results'] as List) {
        final clip = entry is Map ? entry : null;
        if (clip == null) continue;
        final key = clip['key'] as String?;
        final site = clip['site'] as String?;
        final type = clip['type'] as String?;
        if (key == null || key.isEmpty || site != 'YouTube') continue;
        if (type == 'Trailer') {
          trailerKey = key;
          break;
        }
        teaserKey ??= key;
      }
      final chosen = trailerKey ?? teaserKey;
      if (chosen != null) trailerUrl = 'https://www.youtube.com/watch?v=$chosen';
    }

    return TmdbContentDraft(
      mediaType: mediaType,
      title: title,
      originalTitle: originalTitle,
      synopsis: data['overview'] as String? ?? '',
      posterPath: posterPath,
      backdropPath: backdropPath,
      releaseYear: releaseYear,
      durationMinutes: durationMinutes,
      ageRating: (data['adult'] as bool?) == true ? '18+' : null,
      genres: genres,
      castNames: castNames,
      directorName: directorName,
      trailerUrl: trailerUrl,
      rating: (data['vote_average'] as num?)?.toDouble(),
    );
  }

  String? _imageUrl(String? path, {required int width}) {
    if (path == null || path.isEmpty || !path.startsWith('/')) return null;
    return 'https://image.tmdb.org/t/p/w$width$path';
  }
}
