import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'demo_catalog_source.dart';
import 'supabase_catalog_mapper.dart';

class SupabaseCatalogHomeRepository {
  SupabaseCatalogHomeRepository({
    required DemoCatalogSource demoCatalogSource,
    required SupabaseCatalogMapper mapper,
    required Future<SupabaseClient?> Function() safeClient,
  })  : _demoCatalogSource = demoCatalogSource,
        _mapper = mapper,
        _safeClient = safeClient;

  final DemoCatalogSource _demoCatalogSource;
  final SupabaseCatalogMapper _mapper;
  final Future<SupabaseClient?> Function() _safeClient;

  Future<List<HomeSectionModel>> fetchHomeSections() async {
    final client = await _safeClient();
    if (client == null) return _loadDemoSections();

    try {
      final sectionRows = await client
          .from(SupabaseConstants.homeSectionsTable)
          .select()
          .eq('is_enabled', true)
          .order('sort_order', ascending: true);
      if (sectionRows.isEmpty) return _loadDemoSections();

      final sectionIds = sectionRows.map<String>((row) => row['id'] as String).toList();
      final itemRows = await client
          .from(SupabaseConstants.homeSectionItemsTable)
          .select()
          .inFilter('home_section_id', sectionIds)
          .order('sort_order', ascending: true);
      if (itemRows.isEmpty) return _loadDemoSections();

      final contentByKey = await _loadContentByKeyFromItems(client, itemRows);
      final builtSections = sectionRows.map<HomeSectionModel>((section) {
        final items = itemRows
            .where((item) => item['home_section_id'] == section['id'])
            .map((item) => contentByKey['${item['content_type']}:${item['content_id']}'])
            .whereType<ContentTileModel>()
            .toList();
        return HomeSectionModel(
          key: section['section_key'] as String? ?? 'section',
          title: section['title'] as String? ?? 'Section',
          layoutType: section['layout_type'] as String? ?? 'rail',
          items: items,
        );
      }).where((section) => section.items.isNotEmpty).toList();

      return builtSections.isEmpty ? _loadDemoSections() : builtSections;
    } catch (_) {
      return _loadDemoSections();
    }
  }

  Future<List<HomeSectionModel>> _loadDemoSections() async {
    final payload = await _demoCatalogSource.load();
    return payload.sections;
  }

  Future<Map<String, ContentTileModel>> _loadContentByKeyFromItems(
    SupabaseClient client,
    List<dynamic> itemRows,
  ) async {
    final movieIds = itemRows
        .where((row) => row['content_type'] == 'movie')
        .map<String>((row) => row['content_id'] as String)
        .toSet()
        .toList();
    final seriesIds = itemRows
        .where((row) => row['content_type'] == 'series')
        .map<String>((row) => row['content_id'] as String)
        .toSet()
        .toList();

    final contentByKey = <String, ContentTileModel>{};
    if (movieIds.isNotEmpty) {
      final movies = await client
          .from(SupabaseConstants.moviesTable)
          .select()
          .eq('is_published', true)
          .inFilter('id', movieIds);
      for (final row in movies) {
        final tile = _mapper.movieToTile(Map<String, dynamic>.from(row as Map));
        contentByKey['movie:${tile.id}'] = tile;
      }
    }
    if (seriesIds.isNotEmpty) {
      final series = await client
          .from('series')
          .select()
          .eq('is_published', true)
          .inFilter('id', seriesIds);
      for (final row in series) {
        final tile = _mapper.seriesToTile(Map<String, dynamic>.from(row as Map));
        contentByKey['series:${tile.id}'] = tile;
      }
    }
    return contentByKey;
  }
}
