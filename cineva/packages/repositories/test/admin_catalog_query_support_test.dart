import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/src/admin_catalog_query_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const item = AdminCatalogItemModel(
    id: 'movie_1',
    contentType: 'movie',
    title: 'Radiant City',
    synopsis: 'Sci-fi thriller',
    genres: <String>['Sci-Fi'],
    audioLanguages: <String>['Français'],
    subtitleLanguages: <String>['Français'],
    castNames: <String>['Lena North'],
    categoryIds: <String>['cat_1'],
    isFeatured: true,
    isPublished: true,
    directorName: 'Ava Stone',
  );

  test('matches title and director queries case insensitively', () {
    expect(AdminCatalogQuerySupport.matches(item, 'radiant'), isTrue);
    expect(AdminCatalogQuerySupport.matches(item, 'ava stone'), isTrue);
    expect(AdminCatalogQuerySupport.matches(item, 'unknown'), isFalse);
  });

  test('returns true for empty query to keep default listing', () {
    expect(AdminCatalogQuerySupport.matches(item, ''), isTrue);
  });
}
