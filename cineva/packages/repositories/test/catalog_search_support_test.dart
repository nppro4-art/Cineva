import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/src/catalog_search_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const movie = ContentTileModel(
    id: 'movie_1',
    title: 'Radiant City',
    subtitle: 'Film',
    badge: '4K',
    contentType: 'movie',
    directorName: 'Ava Stone',
    genres: <String>['Sci-Fi'],
    castNames: <String>['Lena North'],
    isFeatured: true,
  );

  test('matches content according to selected search filter', () {
    expect(CatalogSearchSupport.matchesContent(movie, 'ava', SearchFilter.directors), isTrue);
    expect(CatalogSearchSupport.matchesContent(movie, 'sci', SearchFilter.genres), isTrue);
    expect(CatalogSearchSupport.matchesContent(movie, 'radiant', SearchFilter.series), isFalse);
  });

  test('builds default suggestions without duplicates', () {
    final suggestions = CatalogSearchSupport.defaultSuggestions(<ContentTileModel>[movie, movie]);

    expect(suggestions.where((item) => item.label == 'Radiant City').length, 1);
    expect(suggestions.first.type, SearchSuggestionType.title);
  });

  test('builds filtered suggestions from searchable contents', () {
    final suggestions = CatalogSearchSupport.buildSuggestions(
      contents: const <ContentTileModel>[movie],
      query: 'ava',
      filter: SearchFilter.directors,
    );

    expect(suggestions.single.label, 'Ava Stone');
    expect(suggestions.single.type, SearchSuggestionType.director);
  });

  test('builds contextual search result labels', () {
    final result = CatalogSearchSupport.toSearchResult(movie, 'ava', SearchFilter.directors);

    expect(result.matchLabel, 'Réalisateur • Ava Stone');
  });
}
