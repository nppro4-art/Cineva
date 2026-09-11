import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'catalog_repository.dart';
import 'catalog_search_support.dart';
import 'catalog_similarity_support.dart';
import 'demo_catalog_source.dart';
import 'supabase_catalog_content_repository.dart';
import 'supabase_catalog_home_repository.dart';
import 'supabase_catalog_mapper.dart';

class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(
    this._backendService, {
    DemoCatalogSource? demoCatalogSource,
  })  : _demoCatalogSource = demoCatalogSource ?? DemoCatalogSource(),
        _mapper = const SupabaseCatalogMapper(
          defaultVideoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        );

  final BackendService _backendService;
  final DemoCatalogSource _demoCatalogSource;
  final SupabaseCatalogMapper _mapper;

  late final SupabaseCatalogHomeRepository _homeRepository = SupabaseCatalogHomeRepository(
    demoCatalogSource: _demoCatalogSource,
    mapper: _mapper,
    safeClient: _safeClient,
  );

  late final SupabaseCatalogContentRepository _contentRepository = SupabaseCatalogContentRepository(
    demoCatalogSource: _demoCatalogSource,
    mapper: _mapper,
    safeClient: _safeClient,
  );

  @override
  Future<List<HomeSectionModel>> fetchHomeSections() => _homeRepository.fetchHomeSections();

  @override
  Future<ContentDetailModel?> fetchContentDetail(String contentId) => _contentRepository.fetchContentDetail(contentId);

  @override
  Future<List<ContentTileModel>> fetchSimilarContent(String contentId) async {
    final detail = await fetchContentDetail(contentId);
    final baseId = detail?.seriesId ?? detail?.id ?? contentId;
    final all = await _contentRepository.loadSearchableContents();
    return CatalogSimilaritySupport.findSimilar(baseId: baseId, contents: all);
  }

  @override
  Future<List<SearchResultModel>> search(
    String query, {
    SearchFilter filter = SearchFilter.all,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const <SearchResultModel>[];

    final contents = await _contentRepository.loadSearchableContents();
    final lowerQuery = normalized.toLowerCase();

    return contents
        .where((content) => CatalogSearchSupport.matchesContent(content, lowerQuery, filter))
        .map((content) => CatalogSearchSupport.toSearchResult(content, lowerQuery, filter))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  @override
  Future<List<SearchSuggestionModel>> fetchSearchSuggestions({
    String query = '',
    SearchFilter filter = SearchFilter.all,
  }) async {
    final contents = await _contentRepository.loadSearchableContents();
    return CatalogSearchSupport.buildSuggestions(
      contents: contents,
      query: query,
      filter: filter,
    );
  }

  Future<SupabaseClient?> _safeClient() async {
    final state = await _backendService.ensureInitialized();
    if (!state.supabaseReady) return null;
    return _backendService.client;
  }
}
