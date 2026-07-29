import 'package:cineva_models/cineva_models.dart';
import 'package:test/test.dart';

void main() {
  test('AdminCatalogItemModel.copyWith preserves fields', () {
    const item = AdminCatalogItemModel(
      id: '1',
      contentType: 'movie',
      title: 'Radiant City',
      synopsis: 'Synopsis',
      genres: <String>['Thriller'],
      audioLanguages: <String>['Français'],
      subtitleLanguages: <String>['Français'],
      castNames: <String>['Ava Mercer'],
      categoryIds: <String>['cat1'],
      isFeatured: false,
      isPublished: false,
    );

    final updated = item.copyWith(isPublished: true, title: 'Radiant City Reloaded');

    expect(updated.isPublished, isTrue);
    expect(updated.title, 'Radiant City Reloaded');
    expect(updated.genres, item.genres);
  });
}
