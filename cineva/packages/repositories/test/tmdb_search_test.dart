import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

/// Réponse réelle de `search/movie` (TMDB v3), forme tronquée.
const Map<String, dynamic> _searchJson = <String, dynamic>{
  'page': 1,
  'total_results': 2,
  'results': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 27205,
      'title': 'Inception',
      'original_title': 'Inception',
      'release_date': '2010-07-15',
      'poster_path': '/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg',
      'overview': 'Un voleur spécialisé dans l’extraction d’informations.',
      'vote_average': 8.369,
    },
    <String, dynamic>{
      'id': 10160,
      'name': 'Inception: The Cobol Job',
      'original_name': 'Inception: The Cobol Job',
      'first_air_date': '2010-12-07',
      'overview': '',
    },
  ],
};

void main() {
  group('TmdbClient.parseSearchResults', () {
    test('les champs film et série sont tous deux reconnus', () {
      final hits = TmdbClient.parseSearchResults(_searchJson, TmdbMediaType.movie);

      expect(hits, hasLength(2));
      expect(hits.first.id, '27205');
      expect(hits.first.title, 'Inception');
      expect(hits.first.releaseYear, 2010);
      expect(hits.first.yearLabel, '2010');
      expect(hits.first.rating, closeTo(8.369, 0.0001));
      expect(hits.first.posterUrl, 'https://image.tmdb.org/t/p/w185/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg');
    });

    test('champs absents : année et note neutres, jamais inventées', () {
      final hits = TmdbClient.parseSearchResults(_searchJson, TmdbMediaType.movie);

      expect(hits.last.releaseYear, 2010);
      expect(hits.last.rating, isNull);
      expect(hits.last.posterUrl, isNull);
      expect(hits.last.overview, isEmpty);
    });

    test('sans date, le libellé reste honnête', () {
      final json = <String, dynamic>{
        'results': <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'title': 'Sans date'},
        ],
      };

      expect(TmdbClient.parseSearchResults(json, TmdbMediaType.movie).single.yearLabel, 'année inconnue');
    });

    test('les entrées sans identifiant ni titre sont ignorées', () {
      final json = <String, dynamic>{
        'results': <Map<String, dynamic>>[
          <String, dynamic>{'title': 'Pas d’id'},
          <String, dynamic>{'id': 5, 'title': '   '},
          <String, dynamic>{'id': 6, 'title': 'Valide'},
        ],
      };

      final hits = TmdbClient.parseSearchResults(json, TmdbMediaType.movie);

      expect(hits, hasLength(1));
      expect(hits.single.title, 'Valide');
    });

    test('réponse inattendue : liste vide', () {
      expect(TmdbClient.parseSearchResults(null, TmdbMediaType.movie), isEmpty);
      expect(TmdbClient.parseSearchResults('erreur', TmdbMediaType.movie), isEmpty);
      expect(TmdbClient.parseSearchResults(<String, dynamic>{}, TmdbMediaType.movie), isEmpty);
    });

    test('un candidat se convertit en référence TMDB', () {
      final reference = TmdbClient.parseSearchResults(_searchJson, TmdbMediaType.series).first.toReference();

      expect(reference.mediaType, TmdbMediaType.series);
      expect(reference.id, '27205');
      expect(reference.isMovie, isFalse);
    });
  });

  group('TmdbReference.tryParse', () {
    test('lien complet, lien localisé et identifiant nu', () {
      expect(TmdbReference.tryParse('https://www.themoviedb.org/movie/603')!.id, '603');
      expect(TmdbReference.tryParse('https://www.themoviedb.org/fr/tv/1396')!.mediaType, TmdbMediaType.series);
      expect(TmdbReference.tryParse('603')!.isMovie, isTrue);
    });

    test('entrée non reconnue', () {
      expect(TmdbReference.tryParse('https://example.com/movie/1'), isNull);
      expect(TmdbReference.tryParse(''), isNull);
    });
  });
}
