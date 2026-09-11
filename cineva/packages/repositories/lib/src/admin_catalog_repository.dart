import 'dart:typed_data';

import 'package:cineva_models/cineva_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_catalog_query_support.dart';
import 'admin_supabase_gateway.dart';
import 'supabase_support.dart';

class SupabaseAdminCatalogRepository {
  SupabaseAdminCatalogRepository(this._gateway);

  final AdminSupabaseGateway _gateway;

  Future<void> deleteCategory(String id) async {
    final client = await _gateway.client();
    await client.from('categories').delete().eq('id', id);
  }

  Future<void> deleteEpisode(String episodeId) async {
    final client = await _gateway.client();
    await client.from('episodes').delete().eq('id', episodeId);
  }

  Future<void> deleteMovie(String id) async {
    final client = await _gateway.client();
    await client.from('movies').delete().eq('id', id);
  }

  Future<void> deleteSeason(String seasonId) async {
    final client = await _gateway.client();
    await client.from('seasons').delete().eq('id', seasonId);
  }

  Future<void> deleteSeries(String id) async {
    final client = await _gateway.client();
    await client.from('series').delete().eq('id', id);
  }

  Future<List<AdminCategoryModel>> fetchCategories() async {
    final client = await _gateway.client();
    final rows = await client.from('categories').select().order('name');
    return rows.map<AdminCategoryModel>((dynamic row) => _mapCategory(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<List<EpisodeModel>> fetchEpisodes(String seasonId, {String? seriesId, int? seasonNumber}) async {
    final client = await _gateway.client();
    final rows = await client.from('episodes').select().eq('season_id', seasonId).order('episode_number');
    return rows
        .map<EpisodeModel>((dynamic row) => _mapEpisode(
              Map<String, dynamic>.from(row as Map),
              seriesId: seriesId,
              seasonNumber: seasonNumber,
            ))
        .toList();
  }

  Future<List<AdminCatalogItemModel>> fetchMovies({String query = ''}) {
    return _fetchCatalogItems(
      contentTable: 'movies',
      categoryTable: 'movie_categories',
      categoryKey: 'movie_id',
      query: query,
      mapper: _mapCatalogMovie,
    );
  }

  Future<List<SeasonModel>> fetchSeasons(String seriesId) async {
    final client = await _gateway.client();
    final seasonRows = await client.from('seasons').select().eq('series_id', seriesId).order('season_number');
    return seasonRows.map<SeasonModel>((dynamic row) {
      final map = Map<String, dynamic>.from(row as Map);
      return SeasonModel(
        id: map['id'] as String,
        seriesId: map['series_id'] as String,
        seasonNumber: map['season_number'] as int? ?? 1,
        title: map['title'] as String? ?? 'Saison ${(map['season_number'] as int?) ?? 1}',
        synopsis: map['synopsis'] as String?,
        posterPath: map['poster_path'] as String?,
        episodes: const <EpisodeModel>[],
      );
    }).toList();
  }

  Future<List<AdminCatalogItemModel>> fetchSeries({String query = ''}) {
    return _fetchCatalogItems(
      contentTable: 'series',
      categoryTable: 'series_categories',
      categoryKey: 'series_id',
      query: query,
      mapper: _mapCatalogSeries,
    );
  }

  Future<EpisodeModel> saveEpisode(EpisodeModel episode) async {
    final client = await _gateway.client();
    final payload = <String, dynamic>{
      if (_looksLikeUuid(episode.id)) 'id': episode.id,
      'series_id': episode.seriesId,
      'season_id': episode.seasonId,
      'episode_number': episode.episodeNumber,
      'title': episode.title,
      'synopsis': episode.synopsis,
      'thumbnail_path': episode.thumbnailPath,
      'video_path': episode.videoUrl,
      'duration_minutes': episode.durationMinutes,
      'audio_languages': episode.audioLanguages,
      'subtitles': episode.subtitleLanguages,
      // Colonne skip_segments ; si la migration n'a pas encore été appliquée
      // sur la base, le repli metadata prend le relais.
      'skip_segments': _skipSegmentsJson(episode.skipSegments),
      'metadata': <String, dynamic>{
        'rating': episode.rating,
        'intro_end_seconds': episode.introEndSeconds,
        'credits_start_seconds': episode.creditsStartSeconds,
        'next_episode_id': episode.nextEpisodeId,
        'skip_segments': _skipSegmentsJson(episode.skipSegments),
      },
      'is_published': true,
      'published_at': DateTime.now().toIso8601String(),
    }..removeWhere((key, value) => value == null);

    final row = await _upsertWithSchemaFallback(
      client,
      table: 'episodes',
      payload: payload,
      columnKeys: const <String>['skip_segments'],
    );
    return _mapEpisode(row, seriesId: episode.seriesId);
  }

  Future<AdminCatalogItemModel> saveMovie(AdminCatalogItemModel movie) async {
    final client = await _gateway.client();
    final skipSegmentsJson = _skipSegmentsJson(movie.skipSegments);
    final metadata = Map<String, dynamic>.from(movie.metadata)
      ..['rating'] = movie.rating
      ..['intro_end_seconds'] = movie.introEndSeconds
      ..['credits_start_seconds'] = movie.creditsStartSeconds
      ..['skip_segments'] = skipSegmentsJson;
    final payload = <String, dynamic>{
      if (movie.id.isNotEmpty) 'id': movie.id,
      'title': movie.title,
      'original_title': movie.originalTitle,
      'synopsis': movie.synopsis,
      'poster_path': movie.posterPath,
      'backdrop_path': movie.backdropPath,
      'trailer_path': movie.trailerPath,
      'video_path': movie.videoPath,
      'release_year': movie.releaseYear,
      'duration_minutes': movie.durationMinutes,
      'age_rating': movie.ageRating,
      'director_name': movie.directorName,
      'cast_names': movie.castNames,
      'genres': movie.genres,
      'countries': movie.countries,
      'audio_languages': movie.audioLanguages,
      'subtitles': movie.subtitleLanguages,
      // Colonnes de sauts de temps ; si la migration n'a pas encore été
      // appliquée sur la base, le repli metadata prend le relais.
      'intro_end_seconds': movie.introEndSeconds,
      'credits_start_seconds': movie.creditsStartSeconds,
      'skip_segments': skipSegmentsJson,
      'metadata': metadata,
      'is_featured': movie.isFeatured,
      'is_published': movie.isPublished,
      'published_at': movie.isPublished ? DateTime.now().toIso8601String() : null,
    }..removeWhere((key, value) => value == null);

    final row = await _upsertWithSchemaFallback(
      client,
      table: 'movies',
      payload: payload,
      columnKeys: const <String>['intro_end_seconds', 'credits_start_seconds', 'skip_segments'],
    );
    final id = row['id'] as String;
    await _replaceCategoryLinks(client, table: 'movie_categories', foreignKey: 'movie_id', contentId: id, categoryIds: movie.categoryIds);
    return _mapCatalogMovie(row, movie.categoryIds);
  }

  Future<SeasonModel> saveSeason({String? id, required String seriesId, required int seasonNumber, required String title, String? synopsis, String? posterPath}) async {
    final client = await _gateway.client();
    final payload = <String, dynamic>{
      if (id != null && id.isNotEmpty) 'id': id,
      'series_id': seriesId,
      'season_number': seasonNumber,
      'title': title,
      'synopsis': synopsis,
      'poster_path': posterPath,
    };
    final row = await client.from('seasons').upsert(payload).select().single();
    return SeasonModel(
      id: row['id'] as String,
      seriesId: row['series_id'] as String,
      seasonNumber: row['season_number'] as int? ?? seasonNumber,
      title: row['title'] as String? ?? title,
      synopsis: row['synopsis'] as String?,
      posterPath: row['poster_path'] as String?,
      episodes: const <EpisodeModel>[],
    );
  }

  Future<AdminCatalogItemModel> saveSeries(AdminCatalogItemModel series) async {
    final client = await _gateway.client();
    final metadata = Map<String, dynamic>.from(series.metadata)
      ..['rating'] = series.rating
      ..['pilot_episode_id'] = series.pilotEpisodeId
      ..['logo_path'] = series.logoPath;
    final payload = <String, dynamic>{
      if (series.id.isNotEmpty) 'id': series.id,
      'title': series.title,
      'original_title': series.originalTitle,
      'synopsis': series.synopsis,
      'poster_path': series.posterPath,
      'backdrop_path': series.backdropPath,
      'trailer_path': series.trailerPath,
      'release_year': series.releaseYear,
      'age_rating': series.ageRating,
      'director_name': series.directorName,
      'cast_names': series.castNames,
      'genres': series.genres,
      'countries': series.countries,
      'metadata': metadata,
      'is_featured': series.isFeatured,
      'is_published': series.isPublished,
      'published_at': series.isPublished ? DateTime.now().toIso8601String() : null,
    }..removeWhere((key, value) => value == null);

    final row = await client.from('series').upsert(payload).select().single();
    final id = row['id'] as String;
    await _replaceCategoryLinks(client, table: 'series_categories', foreignKey: 'series_id', contentId: id, categoryIds: series.categoryIds);
    return _mapCatalogSeries(Map<String, dynamic>.from(row), series.categoryIds);
  }

  Future<String> uploadMedia({required String bucket, required String filename, required Uint8List bytes, required String contentType}) async {
    final client = await _gateway.client();
    final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return path;
  }

  Future<AdminCategoryModel> upsertCategory({String? id, required String name, required String slug, required String categoryType}) async {
    final client = await _gateway.client();
    final payload = <String, dynamic>{
      if (id != null && id.isNotEmpty) 'id': id,
      'name': name,
      'slug': slug,
      'category_type': categoryType,
    };
    final row = await client.from('categories').upsert(payload).select().single();
    return _mapCategory(Map<String, dynamic>.from(row));
  }

  Future<void> _replaceCategoryLinks(
    SupabaseClient client, {
    required String table,
    required String foreignKey,
    required String contentId,
    required List<String> categoryIds,
  }) async {
    await client.from(table).delete().eq(foreignKey, contentId);
    if (categoryIds.isEmpty) return;
    await client.from(table).insert(categoryIds.map((categoryId) => <String, dynamic>{
          foreignKey: contentId,
          'category_id': categoryId,
        }).toList());
  }

  Future<List<AdminCatalogItemModel>> _fetchCatalogItems({
    required String contentTable,
    required String categoryTable,
    required String categoryKey,
    required String query,
    required AdminCatalogItemModel Function(Map<String, dynamic>, List<String>) mapper,
  }) async {
    final client = await _gateway.client();
    final rows = await client.from(contentTable).select().order('updated_at', ascending: false);
    final categoryLinks = await client.from(categoryTable).select();
    final categoryIdsByContent = <String, List<String>>{};
    for (final dynamic row in categoryLinks) {
      final map = Map<String, dynamic>.from(row as Map);
      categoryIdsByContent.putIfAbsent(map[categoryKey] as String, () => <String>[]).add(map['category_id'] as String);
    }

    return rows
        .map<AdminCatalogItemModel>((dynamic row) {
          final map = Map<String, dynamic>.from(row as Map);
          return mapper(map, categoryIdsByContent[map['id'] as String] ?? const <String>[]);
        })
        .where((item) => AdminCatalogQuerySupport.matches(item, query))
        .toList();
  }

  AdminCategoryModel _mapCategory(Map<String, dynamic> row) {
    return AdminCategoryModel(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      slug: row['slug'] as String? ?? '',
      categoryType: row['category_type'] as String? ?? 'generic',
    );
  }

  AdminCatalogItemModel _mapCatalogMovie(Map<String, dynamic> row, List<String> categoryIds) {
    final metadata = asJsonMap(row['metadata']) ?? <String, dynamic>{};
    return AdminCatalogItemModel(
      id: row['id'] as String,
      contentType: 'movie',
      title: row['title'] as String? ?? '',
      synopsis: row['synopsis'] as String? ?? '',
      genres: asStringList(row['genres']),
      audioLanguages: asStringList(row['audio_languages']),
      subtitleLanguages: asSubtitleLanguages(row['subtitles']),
      castNames: asStringList(row['cast_names']),
      categoryIds: categoryIds,
      isFeatured: row['is_featured'] as bool? ?? false,
      isPublished: row['is_published'] as bool? ?? false,
      originalTitle: row['original_title'] as String?,
      posterPath: row['poster_path'] as String?,
      backdropPath: row['backdrop_path'] as String?,
      trailerPath: row['trailer_path'] as String?,
      videoPath: row['video_path'] as String?,
      releaseYear: row['release_year'] as int?,
      durationMinutes: row['duration_minutes'] as int?,
      ageRating: row['age_rating'] as String?,
      directorName: row['director_name'] as String?,
      countries: asStringList(row['countries']),
      rating: (metadata['rating'] as num?)?.toDouble(),
      introEndSeconds: (row['intro_end_seconds'] as num?)?.toInt() ?? (metadata['intro_end_seconds'] as num?)?.toInt(),
      creditsStartSeconds: (row['credits_start_seconds'] as num?)?.toInt() ?? (metadata['credits_start_seconds'] as num?)?.toInt(),
      skipSegments: asSkipSegments(row['skip_segments'] ?? metadata['skip_segments']),
      metadata: metadata,
    );
  }

  AdminCatalogItemModel _mapCatalogSeries(Map<String, dynamic> row, List<String> categoryIds) {
    final metadata = asJsonMap(row['metadata']) ?? <String, dynamic>{};
    return AdminCatalogItemModel(
      id: row['id'] as String,
      contentType: 'series',
      title: row['title'] as String? ?? '',
      synopsis: row['synopsis'] as String? ?? '',
      genres: asStringList(row['genres']),
      audioLanguages: asStringList(metadata['audio_languages']),
      subtitleLanguages: asSubtitleLanguages(metadata['subtitles']),
      castNames: asStringList(row['cast_names']),
      categoryIds: categoryIds,
      isFeatured: row['is_featured'] as bool? ?? false,
      isPublished: row['is_published'] as bool? ?? false,
      originalTitle: row['original_title'] as String?,
      posterPath: row['poster_path'] as String?,
      backdropPath: row['backdrop_path'] as String?,
      logoPath: metadata['logo_path'] as String?,
      trailerPath: row['trailer_path'] as String?,
      releaseYear: row['release_year'] as int?,
      ageRating: row['age_rating'] as String?,
      directorName: row['director_name'] as String?,
      countries: asStringList(row['countries']),
      rating: (metadata['rating'] as num?)?.toDouble(),
      pilotEpisodeId: metadata['pilot_episode_id'] as String?,
      introEndSeconds: (row['intro_end_seconds'] as num?)?.toInt() ?? (metadata['intro_end_seconds'] as num?)?.toInt(),
      creditsStartSeconds: (row['credits_start_seconds'] as num?)?.toInt() ?? (metadata['credits_start_seconds'] as num?)?.toInt(),
      skipSegments: asSkipSegments(row['skip_segments'] ?? metadata['skip_segments']),
      metadata: metadata,
    );
  }

  EpisodeModel _mapEpisode(Map<String, dynamic> row, {String? seriesId, int? seasonNumber}) {
    final metadata = asJsonMap(row['metadata']) ?? <String, dynamic>{};
    return EpisodeModel(
      id: row['id'] as String,
      seriesId: row['series_id'] as String? ?? seriesId ?? '',
      seasonId: row['season_id'] as String? ?? '',
      seasonNumber: row['season_number'] as int? ?? seasonNumber ?? 1,
      episodeNumber: row['episode_number'] as int? ?? 1,
      title: row['title'] as String? ?? 'Épisode',
      synopsis: row['synopsis'] as String? ?? '',
      durationMinutes: row['duration_minutes'] as int? ?? 48,
      videoUrl: row['video_path'] as String? ?? metadata['video_url'] as String? ?? '',
      thumbnailPath: row['thumbnail_path'] as String?,
      audioLanguages: asStringList(row['audio_languages']),
      subtitleLanguages: asSubtitleLanguages(row['subtitles']),
      rating: (metadata['rating'] as num?)?.toDouble(),
      introEndSeconds: metadata['intro_end_seconds'] as int?,
      creditsStartSeconds: metadata['credits_start_seconds'] as int?,
      skipSegments: asSkipSegments(row['skip_segments'] ?? metadata['skip_segments']),
      nextEpisodeId: metadata['next_episode_id'] as String?,
    );
  }

  bool _looksLikeUuid(String value) => _uuidRegex.hasMatch(value);

  static final RegExp _uuidRegex = RegExp(r'^[0-9a-fA-F-]{36}$');

  /// Sérialise les segments pour la colonne `skip_segments` (jsonb).
  List<Map<String, dynamic>> _skipSegmentsJson(List<SkipSegment> segments) {
    return segments.map((segment) => segment.toJson()).toList();
  }

  /// Upsert tolérant au schéma : si les colonnes cibles n'existent pas
  /// encore dans la base (migration non appliquée), réessaye sans elles.
  /// Les valeurs restent disponibles dans `metadata` (écriture double).
  Future<Map<String, dynamic>> _upsertWithSchemaFallback(
    SupabaseClient client, {
    required String table,
    required Map<String, dynamic> payload,
    required List<String> columnKeys,
  }) async {
    try {
      final row = await client.from(table).upsert(payload).select().single();
      return Map<String, dynamic>.from(row as Map);
    } on PostgrestException catch (error) {
      if (!_isMissingColumn(error)) rethrow;
      final fallback = Map<String, dynamic>.from(payload);
      for (final key in columnKeys) {
        fallback.remove(key);
      }
      final row = await client.from(table).upsert(fallback).select().single();
      return Map<String, dynamic>.from(row as Map);
    }
  }

  bool _isMissingColumn(PostgrestException error) {
    final details = '${error.code} ${error.message} ${error.details} ${error.hint}';
    return details.contains('42703') || details.contains('does not exist');
  }
}
