import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

/// Recherche TMDB : le titre saisi par l'administrateur arrive rarement dans la
/// forme exacte attendue par l'API (année collée au titre, accents manquants,
/// sous-titre français complet, balises de copie issues d'un nom de fichier).
/// Le plan de recherche élargit progressivement la requête au lieu d'échouer.
void main() {
  group('sanitizeTmdbTitle', () {
    test('retire une année entre parenthèses et une entité HTML collée', () {
      expect(
        sanitizeTmdbTitle('Vaiana, la legende du bout du monde (2026) &gt;'),
        'Vaiana, la legende du bout du monde',
      );
    });

    test('nettoie un titre issu d’un nom de fichier', () {
      expect(
        sanitizeTmdbTitle('Vaiana.2026.1080p.WEB-DL.x264-VOSTFR'),
        'Vaiana 2026',
      );
    });

    test('conserve la virgule et l’apostrophe d’un titre français', () {
      expect(sanitizeTmdbTitle('L’Âge de glace'), 'L’Âge de glace');
      expect(
        sanitizeTmdbTitle('2001, l’odyssée de l’espace'),
        '2001, l’odyssée de l’espace',
      );
    });

    test('ne retire pas un mot de langue placé au milieu du titre', () {
      expect(sanitizeTmdbTitle('The French Dispatch'), 'The French Dispatch');
    });

    test('retire les guillemets et la ponctuation finale', () {
      expect(sanitizeTmdbTitle('« Inception » -'), 'Inception');
    });

    test('une saisie vide reste vide', () {
      expect(sanitizeTmdbTitle('   '), '');
    });
  });

  group('extractTmdbYear', () {
    test('entre parenthèses', () {
      expect(extractTmdbYear('Vaiana (2026)'), 2026);
    });

    test('entre crochets', () {
      expect(extractTmdbYear('Vaiana [1998]'), 1998);
    });

    test('en fin de titre, sans parenthèses', () {
      expect(extractTmdbYear('Blade Runner 2049'), 2049);
    });

    test('absente', () {
      expect(extractTmdbYear('Inception'), isNull);
    });

    test('une année en début de titre n’est pas une année de sortie', () {
      expect(extractTmdbYear('2001, l’odyssée de l’espace'), isNull);
    });
  });

  group('stripTrailingYear', () {
    test('retire l’année finale', () {
      expect(stripTrailingYear('Blade Runner 2049'), 'Blade Runner');
    });

    test('laisse une année initiale', () {
      expect(stripTrailingYear('2001, l’odyssée de l’espace'), '2001, l’odyssée de l’espace');
    });
  });

  group('shortTmdbTitle', () {
    test('coupe avant la virgule', () {
      expect(shortTmdbTitle('Vaiana, la légende du bout du monde'), 'Vaiana');
    });

    test('coupe avant les deux-points', () {
      expect(shortTmdbTitle('Star Wars: The Last Jedi'), 'Star Wars');
    });

    test('un titre numérique n’est pas coupé', () {
      expect(shortTmdbTitle('2001, l’odyssée de l’espace'), '2001, l’odyssée de l’espace');
    });

    test('sans séparateur, le titre est inchangé', () {
      expect(shortTmdbTitle('Inception'), 'Inception');
    });
  });

  group('stripTmdbAccents', () {
    test('retire les accents', () {
      expect(stripTmdbAccents('légende'), 'legende');
      expect(stripTmdbAccents('L’Été de Kikujiro'), 'L’Ete de Kikujiro');
    });

    test('ne change pas la longueur de la chaîne', () {
      const value = 'Àpéritif Œuf Ça été';
      expect(stripTmdbAccents(value).length, value.length);
    });

    test('laisse ce qui n’est pas accentué', () {
      expect(stripTmdbAccents('Inception'), 'Inception');
    });
  });

  group('buildTmdbQueryPlan', () {
    test('le titre signalé en échec produit un plan élargi', () {
      final plan = buildTmdbQueryPlan(
        rawQuery: 'Vaiana, la legende du bout du monde (2026) &gt;',
      );

      expect(plan.title, 'Vaiana, la legende du bout du monde');
      expect(plan.year, 2026);
      expect(plan.isEmpty, isFalse);

      // Première tentative : la plus précise.
      expect(plan.attempts.first.query, 'Vaiana, la legende du bout du monde');
      expect(plan.attempts.first.year, 2026);
      expect(plan.attempts.first.language, 'fr-FR');

      // Le titre court et la fiche anglaise font partie du plan.
      expect(
        plan.attempts.any(
          (TmdbSearchAttempt attempt) => attempt.query == 'Vaiana' && attempt.year == 2026,
        ),
        isTrue,
      );
      expect(
        plan.attempts.any(
          (TmdbSearchAttempt attempt) =>
              attempt.query == 'Vaiana' && attempt.language == 'en-US',
        ),
        isTrue,
      );
    });

    test('l’année de l’URL sert de repli à celle du titre', () {
      final plan = buildTmdbQueryPlan(rawQuery: 'Vaiana', year: 2016);

      expect(plan.year, 2016);
      expect(plan.attempts.first.year, 2016);
      // Une tentative sans année suit toujours : l'année peut être fausse.
      expect(
        plan.attempts.any((TmdbSearchAttempt attempt) => attempt.year == null),
        isTrue,
      );
    });

    test('l’année écrite dans le titre prime sur celle de l’URL', () {
      final plan = buildTmdbQueryPlan(rawQuery: 'Vaiana (2026)', year: 2016);

      expect(plan.title, 'Vaiana');
      expect(plan.year, 2026);
    });

    test('un titre simple ne produit pas de tentatives en double', () {
      final plan = buildTmdbQueryPlan(rawQuery: 'Inception');

      expect(plan.attempts, hasLength(2));
      expect(plan.attempts.map((TmdbSearchAttempt a) => a.language).toSet(),
          <String>{'fr-FR', 'en-US'});
    });

    test('un titre accentué ajoute une tentative sans accents', () {
      final plan = buildTmdbQueryPlan(rawQuery: 'Amélie Poulain');

      expect(
        plan.attempts.any((TmdbSearchAttempt attempt) => attempt.query == 'Amelie Poulain'),
        isTrue,
      );
    });

    test('un nom de fichier brut reste exploitable', () {
      final plan = buildTmdbQueryPlan(rawQuery: 'Vaiana.2026.1080p.WEB-DL.x264-VOSTFR');

      expect(plan.title, 'Vaiana');
      expect(plan.year, 2026);
      expect(plan.attempts.first.query, 'Vaiana');
    });

    test('rien d’exploitable : plan vide, aucun appel réseau', () {
      expect(buildTmdbQueryPlan(rawQuery: '').isEmpty, isTrue);
      expect(buildTmdbQueryPlan(rawQuery: '   &gt; ').isEmpty, isTrue);
      expect(buildTmdbQueryPlan(rawQuery: 'x').isEmpty, isTrue);
    });

    test('le résumé des tentatives est lisible', () {
      final plan = buildTmdbQueryPlan(rawQuery: 'Vaiana, la légende (2026)');

      expect(plan.attemptsSummary, contains('titre complet'));
      expect(plan.attemptsSummary, contains('titre court'));
    });
  });
}
