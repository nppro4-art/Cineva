import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const ContentTileModel tile = ContentTileModel(
  id: 'movie_1',
  title: 'Interstellar',
  subtitle: 'Christopher Nolan',
  badge: '4K HDR',
  contentType: 'movie',
  year: 2014,
  durationMinutes: 169,
);

void main() {
  group('CinevaContentLabels.type', () {
    test('libellés français des types connus', () {
      expect(CinevaContentLabels.type('movie'), 'Film');
      expect(CinevaContentLabels.type('series'), 'Série');
      expect(CinevaContentLabels.type('episode'), 'Épisode');
    });

    test('repli neutre pour un type inconnu', () {
      expect(CinevaContentLabels.type('documentaire'), 'Contenu');
      expect(CinevaContentLabels.type(''), 'Contenu');
    });
  });

  group('CinevaContentLabels.duration', () {
    test('heures et minutes formatées à la française', () {
      expect(CinevaContentLabels.duration(169), '2 h 49');
      expect(CinevaContentLabels.duration(149), '2 h 29');
      expect(CinevaContentLabels.duration(120), '2 h');
      expect(CinevaContentLabels.duration(45), '45 min');
    });

    test('durée inconnue : chaîne vide (jamais « 0 min »)', () {
      expect(CinevaContentLabels.duration(null), '');
      expect(CinevaContentLabels.duration(0), '');
      expect(CinevaContentLabels.duration(-12), '');
    });
  });

  group('CinevaContentLabels.meta', () {
    test('année · durée · type, segments vides ignorés', () {
      expect(CinevaContentLabels.meta(tile), '2014 · 2 h 49 · Film');
    });

    test('sans année ni durée, le type suffit', () {
      const ContentTileModel minimal = ContentTileModel(
        id: 'series_1',
        title: 'Série',
        subtitle: '',
        badge: '',
        contentType: 'series',
      );
      expect(CinevaContentLabels.meta(minimal), 'Série');
    });
  });

  group('CinevaContentLabels.qualityTokens', () {
    test('extrait uniquement les jetons de qualité réels', () {
      expect(CinevaContentLabels.qualityTokens('4K HDR'), <String>['4K', 'HDR']);
      expect(
        CinevaContentLabels.qualityTokens('Dolby Vision • Atmos'),
        <String>['DOLBY', 'VISION', 'ATMOS'],
      );
      expect(CinevaContentLabels.hasQuality('1080p'), isTrue);
    });

    test('les pastilles éditoriales ne sont pas de la qualité', () {
      expect(CinevaContentLabels.qualityTokens('TOP 10'), isEmpty);
      expect(CinevaContentLabels.qualityTokens('Nouveauté'), isEmpty);
      expect(CinevaContentLabels.hasQuality(''), isFalse);
    });
  });

  group('CinevaContentLabels.initials', () {
    test('une ou deux initiales, toujours en capitales', () {
      expect(CinevaContentLabels.initials('Jean Dupont'), 'JD');
      expect(CinevaContentLabels.initials('madonna'), 'M');
      expect(CinevaContentLabels.initials('  Anna  Marie  Klein '), 'AK');
      expect(CinevaContentLabels.initials(''), '');
    });
  });

  group('CinevaContentLabels.clampText', () {
    test('coupe sur un mot et ajoute des points de suspension', () {
      const String text =
          'Un voyage interstellaire à travers un trou de ver pour sauver l’humanité';
      final String clamped = CinevaContentLabels.clampText(text, maxChars: 40);
      expect(clamped.length, lessThanOrEqualTo(41));
      expect(clamped.endsWith('…'), isTrue);
      expect(clamped.contains('  '), isFalse);
    });

    test('texte court inchangé, null traité comme vide', () {
      expect(CinevaContentLabels.clampText('Court'), 'Court');
      expect(CinevaContentLabels.clampText(null), '');
    });
  });

  group('CinevaSizeLabels', () {
    test('mégaoctets et gigaoctets avec virgule décimale', () {
      expect(CinevaSizeLabels.fromMb(850), '850 Mo');
      expect(CinevaSizeLabels.fromMb(2355), '2,3 Go');
      expect(CinevaSizeLabels.fromMb(0), '');
    });

    test('octets : Ko, Mo puis Go', () {
      expect(CinevaSizeLabels.fromBytes(2048), '2 Ko');
      expect(CinevaSizeLabels.fromBytes(5242880), '5 Mo');
      expect(CinevaSizeLabels.fromBytes(1073741824), '1,0 Go');
      expect(CinevaSizeLabels.fromBytes(0), '');
    });
  });
}
