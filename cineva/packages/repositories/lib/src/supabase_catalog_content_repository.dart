import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'demo_catalog_source.dart';
import 'supabase_catalog_mapper.dart';

class SupabaseCatalogContentRepository {
  SupabaseCatalogContentRepository({
    required DemoCatalogSource demoCatalogSource,
    required SupabaseCatalogMapper mapper,
    required Future<SupabaseClient?> Function() safeClient,
  })  : _demoCatalogSource = demoCatalogSource,
        _mapper = mapper,
        _safeClient = safeClient;

  final DemoCatalogSource _demoCatalogSource;
  final SupabaseCatalogMapper _mapper;
  final Future<SupabaseClient?> Function() _safeClient;

  Future<ContentDetailModel?> fetchContentDetail(String contentId) async {
    final client = await _safeClient();
    if (client == null) {
      final payload = await _demoCatalogSource.load();
      return payload.details[contentId];
    }

    try {
      final movie = await client
          .from(SupabaseConstants.moviesTable)
          .select()
          .eq('id', contentId)
          .eq('is_published', true)
          .maybeSingle();
      if (movie != null) return _mapper.movieToDetail(Map<String, dynamic>.from(movie as Map));

      final series = await client
          .from('series')
          .select()
          .eq('id', contentId)
          .eq('is_published', true)
          .maybeSingle();
      if (series != null) {
        final detail = await _loadSeriesDetail(client, Map<String, dynamic>.from(series as Map));
        if (detail.seasons.isNotEmpty) return detail;
      }

      final episode = await client
          .from('episodes')
          .select()
          .eq('id', contentId)
          .eq('is_published', true)
          .maybeSingle();
      if (episode != null) {
        return _loadEpisodeDetail(client, Map<String, dynamic>.from(episode as Map));
      }
    } catch (_) {}

    final payload = await _demoCatalogSource.load();
    return payload.details[contentId];
  }

  Future<List<ContentTileModel>> loadSearchableContents() async {
    final client = await _safeClient();
    if (client == null) {
      final payload = await _demoCatalogSource.load();
      return payload.contents;
    }

    try {
      final movies = await client
          .from(SupabaseConstants.moviesTable)
          .select()
          .eq('is_published', true)
          .order('published_at', ascending: false)
          .limit(100);
      final series = await client
          .from('series')
          .select()
          .eq('is_published', true)
          .order('published_at', ascending: false)
          .limit(100);

      final contents = <ContentTileModel>[
        ...movies.map<ContentTileModel>((row) => _mapper.movieToTile(Map<String, dynamic>.from(row as Map))),
        ...series.map<ContentTileModel>((row) => _mapper.seriesToTile(Map<String, dynamic>.from(row as Map))),
      ];
      if (contents.isNotEmpty) return contents;
    } catch (_) {}

    final payload = await _demoCatalogSource.load();
    return payload.contents;
  }

  Future<ContentDetailModel> _loadSeriesDetail(SupabaseClient client, Map<String, dynamic> row) async {
    final seasonsRows = await client
        .from('seasons')
        .select()
        .eq('series_id', row['id'] as String)
        .order('season_number', ascending: true);
    final seasonIds = seasonsRows.map<String>((season) => season['id'] as String).toList();
    final episodeRows = seasonIds.isEmpty
        ? const <dynamic>[]
        : await client
            .from('episodes')
            .select()
            .eq('is_published', true)
            .inFilter('season_id', seasonIds)
            .order('episode_number', ascending: true);

    final seasons = seasonsRows.map<SeasonModel>((season) {
      final episodes = episodeRows
          .where((episode) => episode['season_id'] == season['id'])
          .map((episode) => _mapper.episodeFromRow(
                Map<String, dynamic>.from(episode as Map),
                seasonNumber: season['season_number'] as int? ?? 1,
              ))
          .toList();
      return SeasonModel(
        id: season['id'] as String,
        seriesId: season['series_id'] as String,
        seasonNumber: season['season_number'] as int? ?? 1,
        title: season['title'] as String? ?? 'Saison ${(season['season_number'] as int?) ?? 1}',
        synopsis: season['synopsis'] as String?,
        posterPath: season['poster_path'] as String?,
        episodes: episodes,
      );
    }).toList();

    return _mapper.seriesToDetail(row, seasons: seasons);
  }

  Future<ContentDetailModel> _loadEpisodeDetail(SupabaseClient client, Map<String, dynamic> row) async {
    final seriesRow = await client.from('series').select().eq('id', row['series_id'] as String).single();
    final parent = await _loadSeriesDetail(client, Map<String, dynamic>.from(seriesRow as Map));
    final episode = _mapper.episodeFromRow(row);
    return _mapper.episodeToDetail(parent: parent, episode: episode);
  }
}
