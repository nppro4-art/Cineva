/// Préparation d'une recherche TMDB à partir d'un titre saisi (ou déduit d'un
/// nom de fichier).
///
/// TMDB ne pardonne pas grand-chose : une année laissée dans le titre, un
/// accent manquant, un sous-titre français complet (« Vaiana, la légende du bout
/// du monde »), des balises de copie (`1080p.WEB-DL.x264-VOSTFR`) ou un titre
/// original attendu en anglais suffisent à renvoyer **zéro** fiche. Plutôt que
/// d'interroger l'API une seule fois et d'afficher « aucune fiche », on
/// construit une liste ordonnée de tentatives, de la plus précise à la plus
/// large ; la première qui renvoie des fiches gagne.
///
/// Fonctions pures (aucun appel réseau) : testables sans clé API.
library;

/// Une tentative de recherche.
class TmdbSearchAttempt {
  const TmdbSearchAttempt({
    required this.query,
    required this.language,
    required this.label,
    this.year,
  });

  /// Titre envoyé à TMDB.
  final String query;

  /// Filtre d'année (`year` pour un film, `first_air_date_year` pour une série).
  final int? year;

  /// `fr-FR` (titres français) ou `en-US` (titres originaux).
  final String language;

  /// Libellé lisible, pour les tests et les messages de diagnostic.
  final String label;

  @override
  String toString() => '$label → « $query »${year == null ? '' : ' ($year)'} [$language]';

  @override
  bool operator ==(Object other) =>
      other is TmdbSearchAttempt &&
      other.query == query &&
      other.year == year &&
      other.language == language;

  @override
  int get hashCode => Object.hash(query, year, language);
}

/// Titre nettoyé, année détectée et tentatives ordonnées.
class TmdbQueryPlan {
  const TmdbQueryPlan({
    required this.title,
    required this.attempts,
    this.year,
  });

  /// Titre cherché : nettoyé, sans année. C'est celui qu'on affiche à
  /// l'administrateur.
  final String title;

  /// Année retenue (celle du titre saisi en priorité, sinon celle de l'URL).
  final int? year;

  /// Tentatives, de la plus précise à la plus large. Vide si rien d'exploitable.
  final List<TmdbSearchAttempt> attempts;

  bool get isEmpty => attempts.isEmpty;

  /// Ce qui sera essayé, dans l'ordre.
  String get attemptsSummary =>
      attempts.map((TmdbSearchAttempt attempt) => attempt.label).join(' → ');
}

/// Construit le plan de recherche pour [rawQuery].
///
/// [year] est l'année connue par ailleurs (nom du fichier de l'URL collée) ;
/// une année écrite dans le titre (« … (2026) ») est prioritaire, car c'est la
/// dernière intention de l'administrateur.
TmdbQueryPlan buildTmdbQueryPlan({required String rawQuery, int? year}) {
  final String cleaned = sanitizeTmdbTitle(rawQuery);
  final int? titleYear = extractTmdbYear(rawQuery) ?? extractTmdbYear(cleaned);
  final int? effectiveYear = titleYear ?? year;
  final String title = stripTrailingYear(cleaned);

  if (title.length < 2) {
    return const TmdbQueryPlan(title: '', attempts: <TmdbSearchAttempt>[]);
  }

  final String shortTitle = shortTmdbTitle(title);
  final String unaccented = stripTmdbAccents(title);
  final String unaccentedShort = stripTmdbAccents(shortTitle);

  final List<TmdbSearchAttempt> candidates = <TmdbSearchAttempt>[
    TmdbSearchAttempt(
      query: title,
      year: effectiveYear,
      language: 'fr-FR',
      label: 'titre complet',
    ),
    TmdbSearchAttempt(
      query: title,
      language: 'fr-FR',
      label: 'titre complet sans année',
    ),
    TmdbSearchAttempt(
      query: shortTitle,
      year: effectiveYear,
      language: 'fr-FR',
      label: 'titre court',
    ),
    TmdbSearchAttempt(
      query: shortTitle,
      language: 'fr-FR',
      label: 'titre court sans année',
    ),
    TmdbSearchAttempt(
      query: unaccented,
      language: 'fr-FR',
      label: 'sans accents',
    ),
    TmdbSearchAttempt(
      query: title,
      language: 'en-US',
      label: 'fiche anglaise',
    ),
    TmdbSearchAttempt(
      query: shortTitle,
      language: 'en-US',
      label: 'titre court en anglais',
    ),
    TmdbSearchAttempt(
      query: unaccentedShort,
      language: 'en-US',
      label: 'titre court sans accents en anglais',
    ),
  ];

  // Dédoublonnage : plusieurs tentatives retombent souvent sur la même requête
  // (aucune année détectée, titre sans virgule, aucun accent…).
  final List<TmdbSearchAttempt> attempts = <TmdbSearchAttempt>[];
  final Set<TmdbSearchAttempt> seen = <TmdbSearchAttempt>{};
  for (final TmdbSearchAttempt attempt in candidates) {
    if (attempt.query.trim().length < 2) continue;
    if (seen.add(attempt)) attempts.add(attempt);
  }

  return TmdbQueryPlan(title: title, year: effectiveYear, attempts: attempts);
}

/// Nettoie un titre saisi ou déduit d'un nom de fichier.
///
/// Retire : entités HTML (`&gt;`, `&amp;`…), guillemets et chevrons, années
/// entre parenthèses, balises de copie non ambiguës (`1080p`, `x264`,
/// `WEB-DL`…), mots de doublage **en fin de titre** (`VOSTFR`, `TRUEFRENCH`),
/// ponctuation finale et espaces superflus.
///
/// Les virgules et apostrophes internes sont conservées : elles font partie des
/// titres français (« Vaiana, la légende du bout du monde », « L'Âge de glace »).
String sanitizeTmdbTitle(String raw) {
  String value = raw.trim();
  if (value.isEmpty) return '';

  // Entités HTML échappées (collage depuis un navigateur, un fichier .nfo…).
  const Map<String, String> entities = <String, String>{
    '&amp;': '&',
    '&gt;': ' ',
    '&lt;': ' ',
    '&quot;': ' ',
    '&#39;': "'",
    '&apos;': "'",
    '&nbsp;': ' ',
  };
  entities.forEach((String entity, String replacement) {
    value = value.replaceAll(entity, replacement);
  });

  // Guillemets, chevrons et caractères de balisage : jamais utiles à TMDB.
  value = value.replaceAll(RegExp(r'''[«»“”„<>{}|\\/@#*+=~^]'''), ' ');

  // Années entre parenthèses ou crochets (le filtre d'année est extrait à part).
  value = value.replaceAll(RegExp(r'[\(\[]\s*(?:18|19|20|21)\d{2}\s*[\)\]]'), ' ');

  // Séparateurs de noms de fichiers : « Vaiana.2026.1080p » → mots séparés.
  value = value.replaceAll(RegExp(r'[._]+'), ' ');

  // Balises de copie non ambiguës, où qu'elles soient : aucune ne peut faire
  // partie d'un titre de film.
  value = value.replaceAll(_copyTags, ' ');

  // Mots de langue ou de doublage, uniquement en fin de titre : « The French
  // Dispatch » doit garder son titre intact.
  value = value.replaceAll(_trailingLanguageTags, '');

  // Espaces multiples puis ponctuation et séparateurs restés en fin de titre.
  value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  value = value.replaceAll(RegExp(r'''[.,;:!?\-–—_'"’\)\]\s]+$'''), '').trim();
  return value;
}

/// Retire une année nue en fin de titre : « Blade Runner 2049 » → « Blade
/// Runner » (l'année part dans le filtre, ce qui retrouve la bonne fiche).
///
/// Une année en **début** de titre n'est jamais touchée : « 2001, l'odyssée de
/// l'espace » reste intact.
String stripTrailingYear(String title) {
  final String value = title.trim();
  final String stripped = value.replaceAll(RegExp(r'\s+(?:18|19|20|21)\d{2}$'), '').trim();
  return stripped.length >= 2 ? stripped : value;
}

final RegExp _copyTags = RegExp(
  r'\b(?:1080p|2160p|720p|480p|x264|x265|h264|h265|web[\s.\-]*(?:dl|rip)|bluray|brrip|hdrip|dvdrip|hdcam|hdr10\+?|xvid|dts|ac3)\b',
  caseSensitive: false,
);

final RegExp _trailingLanguageTags = RegExp(
  r'(?:\b(?:vostfr|vost|truefrench|french|francais|français|multi|vf|vo)\b[\s.\-]*)+$',
  caseSensitive: false,
);

/// Année contenue dans un titre : « … (2026) », « … [2026] » ou « … 2026 ».
int? extractTmdbYear(String raw) {
  final Match? inBrackets =
      RegExp(r'[\(\[]\s*((?:18|19|20|21)\d{2})\s*[\)\]]').firstMatch(raw);
  final int? fromBrackets = int.tryParse(inBrackets?.group(1) ?? '');
  if (fromBrackets != null) return fromBrackets;

  final Match? trailing = RegExp(r'((?:18|19|20|21)\d{2})\s*$').firstMatch(raw.trim());
  final int? fromEnd = int.tryParse(trailing?.group(1) ?? '');
  if (fromEnd != null && fromEnd >= 1870 && fromEnd <= 2100) return fromEnd;
  return null;
}

/// Titre court : la partie avant la première virgule, deux-points ou
/// point-virgule. « Vaiana, la légende du bout du monde » → « Vaiana ».
///
/// TMDB indexe le titre principal ; le sous-titre français complet est la
/// première cause de recherche infructueuse.
String shortTmdbTitle(String title) {
  final String cut = title.split(RegExp(r'[,;:]')).first.trim();
  // « 2001, l'odyssée de l'espace » : le titre court serait « 2001 », une
  // requête inutile. Un titre entièrement numérique reste tel quel.
  if (cut.length < 3 || RegExp(r'^\d+$').hasMatch(cut)) return title.trim();
  return cut;
}

/// Retire les accents (à longueur de chaîne constante) : une saisie sans accent
/// clavier reste trouvable.
String stripTmdbAccents(String value) {
  const String accented = 'àáâãäåèéêëìíîïòóôõöùúûüýÿçñœæ'
      'ÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝÇÑŒÆ';
  const String plain = 'aaaaaaeeeeiiiiooooouuuuyycnoe'
      'AAAAAAEEEEIIIIOOOOUUUUYCNOE';

  final StringBuffer buffer = StringBuffer();
  for (int index = 0; index < value.length; index += 1) {
    final int position = accented.indexOf(value[index]);
    buffer.write(position >= 0 ? plain[position] : value[index]);
  }
  return buffer.toString();
}
