/// Lecture des erreurs provoquées par une base qui a dérivé du schéma.
///
/// Une base installée avant la version courante — ou reprise d'un autre projet
/// — peut conserver des colonnes que l'application n'écrit pas. Deux familles
/// d'erreurs PostgREST en découlent :
///
/// * `42703` : le payload contient une colonne que la base ne connaît pas
///   (colonne ajoutée par l'application, migration pas encore jouée) ;
/// * `23502` : la base exige une valeur pour une colonne `NOT NULL` sans valeur
///   par défaut que le payload ne fournit pas (colonne héritée d'un schéma plus
///   ancien, par exemple `movies.sources`).
///
/// Fonctions pures, sans dépendance Supabase, pour rester testables et
/// réutilisables côté interface (messages d'erreur en clair).
library;

final RegExp _notNullColumn = RegExp(r'null value in column "([^"]+)"');
final RegExp _quotedNames = RegExp(r'"([A-Za-z_][A-Za-z0-9_]*)"');

/// Colonnes écrites par l'application pour `movies` et `series`
/// (`supabase/schema.sql`). Tout ce qui est `NOT NULL` sans défaut **hors** de
/// cette liste vient d'ailleurs et doit être réparé en base.
const List<String> appOwnedCatalogColumns = <String>[
  'id',
  'title',
  'original_title',
  'synopsis',
  'poster_path',
  'backdrop_path',
  'logo_path',
  'trailer_path',
  'video_path',
  'release_year',
  'duration_minutes',
  'age_rating',
  'director_name',
  'cast_names',
  'genres',
  'countries',
  'audio_languages',
  'subtitles',
  'metadata',
  'intro_end_seconds',
  'credits_start_seconds',
  'skip_segments',
  'is_featured',
  'is_published',
  'published_at',
  'created_at',
  'updated_at',
];

/// Nom de la colonne `NOT NULL` en défaut dans une violation `23502`, ou
/// `null` si [text] ne décrit pas cette erreur.
///
/// [text] peut être le message seul ou la trace complète d'une
/// `PostgrestException` : la détection accepte les deux.
String? notNullViolationColumn(String text) {
  final bool concerned = text.contains('23502') || text.contains('not-null constraint');
  if (!concerned) return null;
  return _notNullColumn.firstMatch(text)?.group(1);
}

/// Première colonne de [columns] citée dans [text].
///
/// Sert à repérer qu'une valeur neutre déjà tentée a été refusée (mauvais type,
/// erreur `22P02` ou `400`) afin de passer à la candidate suivante.
String? namedColumnAmong(String text, Iterable<String> columns) {
  final Set<String> quoted = _quotedNames.allMatches(text).map((Match match) => match.group(1)!).toSet();
  for (final String column in columns) {
    if (quoted.contains(column)) return column;
  }
  return null;
}

/// Valeur neutre de même forme que [sample] : liste jsonb, objet jsonb, texte,
/// nombre ou booléen. `null` si la forme n'est pas reconnue.
Object? neutralValueLike(Object? sample) {
  if (sample is List) return <Object?>[];
  if (sample is Map) return <String, Object?>{};
  if (sample is bool) return false;
  if (sample is num) return 0;
  if (sample is String) return '';
  return null;
}

/// Valeurs neutres proposées pour une colonne héritée, de la plus courante
/// (jsonb / tableau) à la plus rare.
const List<Object?> neutralColumnCandidates = <Object?>[
  <Object?>[],
  <String, Object?>{},
  '',
  0,
  false,
];

/// Plan de tentative pour une colonne : la forme observée sur une ligne
/// existante d'abord, puis les autres formes, sans doublon.
List<Object?> neutralColumnPlan(Object? sample) {
  final Object? shaped = neutralValueLike(sample);
  if (shaped == null) return neutralColumnCandidates;
  return <Object?>[
    shaped,
    ...neutralColumnCandidates.where((Object? candidate) => candidate.runtimeType != shaped.runtimeType),
  ];
}
