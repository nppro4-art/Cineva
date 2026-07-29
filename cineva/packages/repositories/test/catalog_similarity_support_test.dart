import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/src/catalog_similarity_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = ContentTileModel(
    id: 'movie_1',
    title: 'Radiant City',
    subtitle: 'Film',
    badge: '4K',
    contentType: 'movie',
    genres: <String>['Sci-Fi'],
  );
  const sameType = ContentTileModel(
    id: 'movie_2',
    title: 'Night Loop',
    subtitle: 'Film',
    badge: 'HD',
    contentType: 'movie',
    genres: <String>['Drama'],
  );
  const sameGenre = ContentTileModel(
    id: 'series_1',
    title: 'Orbit',
    subtitle: 'Série',
    badge: 'Series',
    contentType: 'series',
    genres: <String>['Sci-Fi'],
  );

  test('returns content with same type or genre excluding current item', () {
    final results = CatalogSimilaritySupport.findSimilar(
      baseId: 'movie_1',
      contents: const <ContentTileModel>[base, sameType, sameGenre],
    );

    expect(results, const <ContentTileModel>[sameType, sameGenre]);
  });
}
