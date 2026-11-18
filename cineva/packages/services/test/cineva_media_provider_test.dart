import 'package:flutter_test/flutter_test.dart';
import 'package:cineva_services/src/media/cineva_media_provider.dart';

class FakeProvider implements CinevaMediaProvider {
  FakeProvider(this.id, {this.fail = false});
  @override
  final String id;
  @override
  String get displayName => id;
  final bool fail;

  @override
  Future<List<CinevaProviderItem>> search(String query) async {
    if (fail) throw StateError('provider failure');
    return [
      CinevaProviderItem(
        id: 'shared',
        title: 'Shared title',
        providerId: id,
        posterUrl: id == 'second' ? 'https://img.example.com/poster.jpg' : null,
        genres: id == 'second' ? const ['Drama'] : const [],
      ),
      CinevaProviderItem(id: '${id}-only', title: 'Unique', providerId: id),
    ];
  }

  @override
  Future<List<CinevaProviderItem>> catalog({
    String? catalogId,
    String? genre,
    int page = 1,
  }) async {
    if (fail) throw StateError('provider failure');
    return [CinevaProviderItem(id: '${id}-catalog', title: 'Catalog', providerId: id)];
  }

  @override
  Future<List<CinevaProviderSource>> resolve(String contentId) async {
    if (fail) throw StateError('provider failure');
    return [
      CinevaProviderSource(
        id: 'source',
        providerId: id,
        url: Uri.parse('https://cdn.example.com/$id.m3u8'),
      ),
    ];
  }
}

void main() {
  group('CinevaMediaProviderRegistry', () {
    test('aggregates search results and deduplicates stable identities', () async {
      final registry = CinevaMediaProviderRegistry([
        FakeProvider('first'),
        FakeProvider('second'),
      ]);
      final results = await registry.search('  dune  ');
      expect(results.map((item) => item.id).toSet(),
          {'shared', 'first-only', 'second-only'});
      final shared = results.firstWhere((item) => item.id == 'shared');
      expect(shared.posterUrl, 'https://img.example.com/poster.jpg');
      expect(shared.genres, contains('Drama'));
    });

    test('isolates provider failures', () async {
      final registry = CinevaMediaProviderRegistry([
        FakeProvider('broken', fail: true),
        FakeProvider('healthy'),
      ]);
      expect((await registry.search('film')).length, 2);
      expect((await registry.catalog()).single.id, 'healthy-catalog');
      expect((await registry.resolve('film')).single.providerId, 'healthy');
    });

    test('does not query providers for an empty search', () async {
      final registry = CinevaMediaProviderRegistry([FakeProvider('one')]);
      expect(await registry.search('   '), isEmpty);
    });

    test('rejects invalid catalog page', () {
      final registry = CinevaMediaProviderRegistry([FakeProvider('one')]);
      expect(() => registry.catalog(page: 0), throwsArgumentError);
    });

    test('only returns HTTP(S) sources and deduplicates them', () async {
      final registry = CinevaMediaProviderRegistry([FakeProvider('one')]);
      final sources = await registry.resolve('film');
      expect(sources, hasLength(1));
      expect(sources.single.url.scheme, 'https');
    });
  });
}
