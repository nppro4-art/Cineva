import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('notNullViolationColumn', () {
    test('lit la colonne dans le message Postgres réel', () {
      const String message = 'null value in column "sources" of relation "movies" '
          'violates not-null constraint';
      expect(notNullViolationColumn(message), 'sources');
    });

    test('lit la colonne dans la trace complète d’une PostgrestException', () {
      const String trace = 'PostgrestException(message: null value in column "sources" '
          'of relation "movies" violates not-null constraint, code: 23502, '
          'details: Bad Request, hint: null)';
      expect(notNullViolationColumn(trace), 'sources');
    });

    test('accepte la forme ancienne sans « of relation »', () {
      expect(
        notNullViolationColumn('null value in column "slug" violates not-null constraint'),
        'slug',
      );
    });

    test('renvoie null sur une autre erreur', () {
      expect(notNullViolationColumn('could not find the table \'public.movie_categories\''), isNull);
      expect(notNullViolationColumn('duplicate key value violates unique constraint'), isNull);
      expect(notNullViolationColumn('column "video_path" does not exist'), isNull);
    });

    test('ne confond pas le nom de la relation avec la colonne', () {
      // « movies » est cité en premier dans le message : la colonne attendue est
      // bien celle qui précède « violates not-null constraint ».
      expect(
        notNullViolationColumn('23502 null value in column "sources" of relation "movies"'),
        'sources',
      );
    });
  });

  group('namedColumnAmong', () {
    test('retrouve une colonne déjà tentée dans une erreur de type', () {
      const String trace = 'invalid input syntax for type text: "[]" (code 22P02) '
          'for column "sources"';
      expect(namedColumnAmong(trace, <String>['sources']), 'sources');
    });

    test('renvoie null si aucune colonne suivie n’est citée', () {
      expect(namedColumnAmong('permission denied for table movies', <String>['sources']), isNull);
      expect(namedColumnAmong('quoi que ce soit', <String>[]), isNull);
    });
  });

  group('neutralValueLike', () {
    test('conserve la forme de la valeur observée', () {
      expect(neutralValueLike(<dynamic>[<String, dynamic>{'url': 'x'}]), <Object?>[]);
      expect(neutralValueLike(<String, dynamic>{'hd': 'x'}), <String, Object?>{});
      expect(neutralValueLike('texte'), '');
      expect(neutralValueLike(12), 0);
      expect(neutralValueLike(1.5), 0);
      expect(neutralValueLike(true), false);
    });

    test('renvoie null sur une forme inconnue', () {
      expect(neutralValueLike(null), isNull);
      expect(neutralValueLike(DateTime(2026)), isNull);
    });
  });

  group('neutralColumnPlan', () {
    test('place la forme observée en premier, sans doublon', () {
      final List<Object?> plan = neutralColumnPlan('texte');
      expect(plan.first, '');
      expect(plan.length, neutralColumnCandidates.length);
      expect(plan.whereType<String>().length, 1);
    });

    test('retombe sur les candidats génériques sans échantillon', () {
      expect(neutralColumnPlan(null), neutralColumnCandidates);
    });

    test('garde la liste en premier pour un jsonb tableau', () {
      final List<Object?> plan = neutralColumnPlan(<dynamic>['a', 'b']);
      expect(plan.first, <Object?>[]);
      expect(plan[1], <String, Object?>{});
    });
  });

  group('appOwnedCatalogColumns', () {
    test('couvre les colonnes NOT NULL sans défaut gérées par l’application', () {
      expect(appOwnedCatalogColumns, contains('title'));
      expect(appOwnedCatalogColumns, contains('cast_names'));
      expect(appOwnedCatalogColumns, contains('metadata'));
      expect(appOwnedCatalogColumns, contains('skip_segments'));
      // Une colonne héritée d’un autre schéma ne doit pas être déclarée nôtre.
      expect(appOwnedCatalogColumns, isNot(contains('sources')));
      expect(appOwnedCatalogColumns.toSet().length, appOwnedCatalogColumns.length);
    });
  });
}
