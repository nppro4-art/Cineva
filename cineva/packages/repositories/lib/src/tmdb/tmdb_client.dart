import 'package:cineva_shared/cineva_shared.dart';
import 'package:dio/dio.dart';

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
                baseUrl: 'https://api.themoviedb.org/3',
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
