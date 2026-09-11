import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TmdbReference.tryParse', () {
    test('parses a full movie URL', () {
      final reference = TmdbReference.tryParse('https://www.themoviedb.org/movie/603');
      expect(reference, isNotNull);
      expect(reference!.mediaType, TmdbMediaType.movie);
      expect(reference.id, '603');
      expect(reference.isMovie, isTrue);
    });

    test('parses a locale-prefixed movie URL', () {
      final reference = TmdbReference.tryParse('https://www.themoviedb.org/fr/movie/603|fr');
      expect(reference, isNotNull);
      expect(reference!.mediaType, TmdbMediaType.movie);
      expect(reference.id, '603');
    });

    test('parses a tv URL as series', () {
      final reference = TmdbReference.tryParse('https://www.themoviedb.org/tv/1396');
      expect(reference, isNotNull);
      expect(reference!.mediaType, TmdbMediaType.series);
      expect(reference.id, '1396');
    });

    test('parses a bare numeric id as movie', () {
      final reference = TmdbReference.tryParse('  603  ');
      expect(reference, isNotNull);
      expect(reference!.mediaType, TmdbMediaType.movie);
      expect(reference.id, '603');
    });

    test('rejects non-TMDB links and invalid input', () {
      expect(TmdbReference.tryParse('https://www.imdb.com/title/tt0133093/'), isNull);
      expect(TmdbReference.tryParse('https://themoviedb.org/movie/abc'), isNull);
      expect(TmdbReference.tryParse('abc'), isNull);
      expect(TmdbReference.tryParse(''), isNull);
      expect(TmdbReference.tryParse('   '), isNull);
    });
  });
}
