part of 'catalog_screen.dart';

/// Import de contenu par lien TMDB (film ou série).
///
/// Le lien ou l'identifiant TMDB est résolu vers une fiche (titre, synopsis,
/// affiches, note, casting, réalisateur, bande-annonce) qui pré-remplit
/// l'éditeur de catalogue. L'enregistrement reste manuel : l'administrateur
/// ajoute ensuite le chemin vidéo et publie.
Future<void> _showTmdbImportDialog(
  BuildContext context,
  WidgetRef ref,
  List<AdminCategoryModel> categories, {
  required String contentType,
}) async {
  final linkController = TextEditingController();
  TmdbMediaType mediaType = contentType == 'movie' ? TmdbMediaType.movie : TmdbMediaType.series;
  var loading = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (builderContext, setState) {
          final trimmed = linkController.text.trim();
          final parsed = TmdbReference.tryParse(trimmed);
          // Le type est « verrouillé » quand le lien contient movie/ ou tv/.
          final typeLocked = parsed != null && !RegExp(r'^\d{1,8}$').hasMatch(trimmed);

          return AlertDialog(
            backgroundColor: CinevaColors.surface,
            title: const Text('Importer depuis TMDB'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Collez un lien ou un identifiant TMDB. La fiche est pré-remplie '
                    '(titre, synopsis, affiches, note, casting, bande-annonce) puis '
                    'proposée à l’éditeur avant enregistrement.',
                    style: TextStyle(color: CinevaColors.textMuted),
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  TextField(
                    controller: linkController,
                    decoration: const InputDecoration(
                      labelText: 'Lien TMDB ou identifiant',
                      hintText: 'https://www.themoviedb.org/movie/603  —  ou  603',
                    ),
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  if (!typeLocked)
                    SegmentedButton<TmdbMediaType>(
                      segments: const <ButtonSegment<TmdbMediaType>>[
                        ButtonSegment(value: TmdbMediaType.movie, label: Text('Film')),
                        ButtonSegment(value: TmdbMediaType.series, label: Text('Série')),
                      ],
                      selected: <TmdbMediaType>{mediaType},
                      onSelectionChanged: (selection) => setState(() => mediaType = selection.first),
                    ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annuler'),
              ),
              FilledButton.icon(
                onPressed: loading
                    ? null
                    : () async {
                        final reference = TmdbReference.tryParse(linkController.text);
                        if (reference == null) {
                          if (builderContext.mounted) {
                            ScaffoldMessenger.of(builderContext).showSnackBar(
                              const SnackBar(
                                content: Text('Lien TMDB invalide. Utilisez un lien themoviedb.org ou un identifiant numérique.'),
                              ),
                            );
                          }
                          return;
                        }

                        final resolvedReference = typeLocked
                            ? reference
                            : TmdbReference(mediaType: mediaType, id: reference.id);
                        setState(() => loading = true);
                        try {
                          final draft = await ref.read(adminRepositoryProvider).fetchTmdbDraft(resolvedReference);
                          // Ferme la boîte d'import puis ouvre l'éditeur
                          // pré-rempli (contexte du tab, encore monté).
                          Navigator.of(dialogContext).pop();
                          if (!context.mounted) return;
                          await _showCatalogEditor(
                            context,
                            ref,
                            categories,
                            contentType: draft.mediaType == TmdbMediaType.movie ? 'movie' : 'series',
                            existing: _tmdbDraftToCatalogItem(draft),
                          );
                        } catch (error) {
                          if (!builderContext.mounted) return;
                          setState(() => loading = false);
                          ScaffoldMessenger.of(builderContext).showSnackBar(SnackBar(content: Text(error.toString())));
                        }
                      },
                icon: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_rounded),
                label: Text(loading ? 'Import en cours…' : 'Importer'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Convertit la fiche TMDB en élément de catalogue (brouillon non publié,
/// sans chemin vidéo : à compléter par l'administrateur).
AdminCatalogItemModel _tmdbDraftToCatalogItem(TmdbContentDraft draft) {
  return AdminCatalogItemModel(
    id: '',
    contentType: draft.mediaType == TmdbMediaType.movie ? 'movie' : 'series',
    title: draft.title,
    synopsis: draft.synopsis,
    genres: draft.genres,
    audioLanguages: const <String>['Français'],
    subtitleLanguages: const <String>['Français'],
    castNames: draft.castNames,
    categoryIds: const <String>[],
    isFeatured: false,
    isPublished: false,
    originalTitle: draft.originalTitle,
    posterPath: draft.posterPath,
    backdropPath: draft.backdropPath,
    trailerPath: draft.trailerUrl.isEmpty ? null : draft.trailerUrl,
    videoPath: null,
    releaseYear: draft.releaseYear,
    durationMinutes: draft.durationMinutes,
    ageRating: draft.ageRating,
    directorName: draft.directorName.isEmpty ? null : draft.directorName,
    countries: const <String>[],
    rating: draft.rating,
  );
}
