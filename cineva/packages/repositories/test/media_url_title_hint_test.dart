import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('titleHintFromMediaUrl — titres exploitables', () {
    test('nom de fichier avec points, année et jargon de release', () {
      final hint = titleHintFromMediaUrl(
        'https://cdn.cineva.app/movies/inception.2010.1080p.x264.mp4',
      );

      expect(hint, isNotNull);
      expect(hint!.title, 'inception');
      expect(hint.year, 2010);
      expect(hint.fileName, 'inception.2010.1080p.x264.mp4');
      expect(hint.hasTitle, isTrue);
    });

    test('tirets, underscores et année collée au titre', () {
      final hint = titleHintFromMediaUrl('https://x.com/a/charlie_chaplin_the_kid-1921.mkv');

      expect(hint!.title, 'charlie chaplin the kid');
      expect(hint.year, 1921);
    });

    test('le jargon de langue et de qualité est retiré', () {
      final hint = titleHintFromMediaUrl('/storage/emulated/0/Cineva/My.Movie.VOSTFR.mp4');

      expect(hint!.title, 'My Movie');
      expect(hint.year, isNull);
    });

    test('chemin de fichier nu, sans URL', () {
      final hint = titleHintFromMediaUrl('inception.mp4');

      expect(hint!.fileName, 'inception.mp4');
      expect(hint.title, 'inception');
    });

    test('paramètres de requête ignorés', () {
      final hint = titleHintFromMediaUrl(
        'https://cdn.x/films/la-haine-1995.mp4?token=abc123&expires=99',
      );

      expect(hint!.fileName, 'la-haine-1995.mp4');
      expect(hint.title, 'la haine');
      expect(hint.year, 1995);
    });
  });

  group('titleHintFromMediaUrl — noms non exploitables', () {
    test('manifeste HLS : aucun titre inventé', () {
      final hint = titleHintFromMediaUrl('https://cdn.x/hls/master.m3u8');

      expect(hint!.hasTitle, isFalse);
      expect(hint.fileName, 'master.m3u8');
    });

    test('empreinte hexadécimale', () {
      final hint = titleHintFromMediaUrl('https://cdn.x/9f8b7c6a5d4e3f2a1b0c.mp4');

      expect(hint!.hasTitle, isFalse);
    });

    test('UUID', () {
      final hint = titleHintFromMediaUrl('https://x/a3f9c2b1-1234-5678-9abc-def012345678.mp4');

      expect(hint!.hasTitle, isFalse);
    });

    test('entrée vide', () {
      expect(titleHintFromMediaUrl(''), isNull);
      expect(titleHintFromMediaUrl('   '), isNull);
    });
  });

  group('bruit de release reconnu', () {
    test('les jetons techniques usuels sont filtrés', () {
      for (final token in <String>['1080p', 'x264', 'webrip', 'vostfr', 'truehd', 'remux', '2160p']) {
        expect(kMediaReleaseNoise.contains(token), isTrue, reason: token);
      }
    });

    test('les noms de manifestes sont listés', () {
      expect(kMediaManifestNames.contains('master'), isTrue);
      expect(kMediaManifestNames.contains('playlist'), isTrue);
    });
  });
}
