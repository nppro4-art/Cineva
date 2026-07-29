import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:cineva_widgets/src/search/search_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SearchController loads suggestions and history on init', () async {
    final controller = SearchController(
      catalogRepository: _FakeCatalogRepository(),
      localPreferencesService: _FakeLocalPreferencesService(history: <String>['Nova Zero']),
    );

    await Future<void>.delayed(Duration.zero);

    expect(controller.state.history, contains('Nova Zero'));
    expect(controller.state.suggestions, isNotEmpty);
  });

  test('SearchController filters and searches dynamically', () async {
    final controller = SearchController(
      catalogRepository: _FakeCatalogRepository(),
      localPreferencesService: _FakeLocalPreferencesService(),
    );

    await Future<void>.delayed(Duration.zero);
    await controller.setFilter(SearchFilter.series);
    await controller.onQueryChanged('Nova');

    expect(controller.state.results, isNotEmpty);
    expect(controller.state.results.first.contentType, 'series');
  });

  test('SearchController stores submitted history', () async {
    final prefs = _FakeLocalPreferencesService();
    final controller = SearchController(
      catalogRepository: _FakeCatalogRepository(),
      localPreferencesService: prefs,
    );

    await Future<void>.delayed(Duration.zero);
    await controller.onQueryChanged('Radiant');
    await controller.submitCurrentQuery();

    expect(controller.state.history.first, 'Radiant');
    expect(prefs.history.first, 'Radiant');
  });
}

class _FakeCatalogRepository implements CatalogRepository {
  final _contents = <ContentTileModel>[
    const ContentTileModel(
      id: 'movie_1',
      title: 'Radiant City',
      subtitle: 'Film • 2026',
      badge: '4K',
      contentType: 'movie',
      genres: <String>['Thriller'],
      castNames: <String>['Ava Mercer'],
      directorName: 'Lina Voss',
      year: 2026,
      description: 'Ville néon',
    ),
    const ContentTileModel(
      id: 'series_1',
      title: 'Nova Zero',
      subtitle: 'Série • 2026',
      badge: 'Hit',
      contentType: 'series',
      genres: <String>['Science-fiction'],
      castNames: <String>['Kira Sol'],
      directorName: 'Tara Quinn',
      year: 2026,
      description: 'Station orbitale',
      isFeatured: true,
    ),
  ];

  @override
  Future<List<SearchSuggestionModel>> fetchSearchSuggestions({String query = '', SearchFilter filter = SearchFilter.all}) async {
    if (query.isEmpty) {
      return const <SearchSuggestionModel>[
        SearchSuggestionModel(label: 'Nova Zero', type: SearchSuggestionType.title),
        SearchSuggestionModel(label: 'Science-fiction', type: SearchSuggestionType.genre),
      ];
    }

    return <SearchSuggestionModel>[
      SearchSuggestionModel(label: query, type: SearchSuggestionType.title),
    ];
  }

  @override
  Future<ContentDetailModel?> fetchContentDetail(String contentId) async => null;

  @override
  Future<List<HomeSectionModel>> fetchHomeSections() async => const <HomeSectionModel>[];

  @override
  Future<List<ContentTileModel>> fetchSimilarContent(String contentId) async => const <ContentTileModel>[];

  @override
  Future<List<SearchResultModel>> search(String query, {SearchFilter filter = SearchFilter.all}) async {
    final lower = query.toLowerCase();
    return _contents
        .where((content) {
          final matchesQuery = content.title.toLowerCase().contains(lower);
          final matchesFilter = switch (filter) {
            SearchFilter.series => content.contentType == 'series',
            SearchFilter.movies => content.contentType == 'movie',
            _ => true,
          };
          return matchesQuery && matchesFilter;
        })
        .map(
          (content) => SearchResultModel(
            id: content.id,
            title: content.title,
            contentType: content.contentType,
            subtitle: content.subtitle,
          ),
        )
        .toList();
  }
}

class _FakeLocalPreferencesService extends LocalPreferencesService {
  _FakeLocalPreferencesService({List<String>? history}) : history = history ?? <String>[];

  List<String> history;

  @override
  Future<void> clearSearchHistory() async {
    history = <String>[];
  }

  @override
  Future<List<String>> readSearchHistory() async => history;

  @override
  Future<void> saveSearchHistory(List<String> values) async {
    history = values;
  }
}
