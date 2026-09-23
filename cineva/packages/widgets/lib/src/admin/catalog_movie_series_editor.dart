part of 'catalog_screen.dart';

Future<void> _showCatalogEditor(
  BuildContext context,
  WidgetRef ref,
  List<AdminCategoryModel> categories, {
  required String contentType,
  AdminCatalogItemModel? existing,
}) async {
  final titleController = TextEditingController(text: existing?.title ?? '');
  final originalTitleController = TextEditingController(text: existing?.originalTitle ?? '');
  final synopsisController = TextEditingController(text: existing?.synopsis ?? '');
  final yearController = TextEditingController(text: existing?.releaseYear?.toString() ?? '');
  final durationController = TextEditingController(text: existing?.durationMinutes?.toString() ?? '');
  final ageRatingController = TextEditingController(text: existing?.ageRating ?? '');
  final directorController = TextEditingController(text: existing?.directorName ?? '');
  final castController = TextEditingController(text: existing?.castNames.join(', '));
  final genresController = TextEditingController(text: existing?.genres.join(', '));
  final countriesController = TextEditingController(text: existing?.countries.join(', '));
  final audioController = TextEditingController(text: existing?.audioLanguages.join(', '));
  final subtitlesController = TextEditingController(text: existing?.subtitleLanguages.join(', '));
  final trailerController = TextEditingController(text: existing?.trailerPath ?? '');
  final videoController = TextEditingController(text: existing?.videoPath ?? '');
  final ratingController = TextEditingController(text: existing?.rating?.toString() ?? '');
  final introController = TextEditingController(text: existing?.introEndSeconds?.toString() ?? '');
  final creditsController = TextEditingController(text: existing?.creditsStartSeconds?.toString() ?? '');
  final skipSegmentRows = <_SkipSegmentRow>[
    for (final segment in (existing?.skipSegments ?? const <SkipSegment>[]))
      _SkipSegmentRow(start: segment.startSeconds.toString(), end: segment.endSeconds.toString()),
  ];

  final selectedCategoryIds = <String>{...(existing?.categoryIds ?? const <String>[])};
  bool isFeatured = existing?.isFeatured ?? false;
  bool isPublished = existing?.isPublished ?? false;
  bool saving = false;
  String? saveError;
  Uint8List? posterBytes;
  Uint8List? backdropBytes;
  String? posterFilename;
  String? backdropFilename;
  Uint8List? logoBytes;
  String? logoFilename;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickImage({required String target}) async {
            final result = await FilePicker.platform.pickFiles(withData: true, type: FileType.image);
            if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
            final file = result.files.first;
            final name = file.name.toLowerCase();
            final bytes = file.bytes!;
            final validExtension = name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.webp');
            const maxSizeBytes = 8 * 1024 * 1024;
            if (!validExtension) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Format non supporté. Utilisez JPG, PNG ou WEBP.')),
              );
              return;
            }
            if (bytes.length > maxSizeBytes) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fichier trop volumineux. Maximum 8 Mo.')),
              );
              return;
            }
            setState(() {
              if (target == 'poster') {
                posterBytes = bytes;
                posterFilename = file.name;
              } else if (target == 'backdrop') {
                backdropBytes = bytes;
                backdropFilename = file.name;
              } else {
                logoBytes = bytes;
                logoFilename = file.name;
              }
            });
          }

          return AlertDialog(
            backgroundColor: CinevaColors.surface,
            title: Text(existing == null ? 'Ajouter un ${contentType == 'movie' ? 'film' : 'série'}' : 'Modifier ${existing.title}'),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // L'erreur reste visible DANS la boîte de dialogue : rien ne
                    // se ferme tant que la fiche n'est pas enregistrée.
                    if (saveError != null) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.all(CinevaSpacing.sm),
                        decoration: BoxDecoration(
                          color: CinevaColors.danger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(CinevaRadii.small),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: CinevaColors.danger,
                            ),
                            const SizedBox(width: CinevaSpacing.sm),
                            Expanded(
                              child: Text(
                                saveError!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: CinevaColors.textSoft,
                                      height: 1.35,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: CinevaSpacing.md),
                    ],
                    Row(
                      children: <Widget>[
                        Expanded(child: TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Titre'))),
                        const SizedBox(width: CinevaSpacing.md),
                        Expanded(child: TextField(controller: originalTitleController, decoration: const InputDecoration(labelText: 'Titre original'))),
                      ],
                    ),
                    const SizedBox(height: CinevaSpacing.md),
                    TextField(controller: synopsisController, maxLines: 4, decoration: const InputDecoration(labelText: 'Synopsis')),
                    const SizedBox(height: CinevaSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(child: TextField(controller: yearController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Année'))),
                        const SizedBox(width: CinevaSpacing.md),
                        Expanded(child: TextField(controller: durationController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: contentType == 'movie' ? 'Durée (min)' : 'Durée épisode (min)'))),
                        const SizedBox(width: CinevaSpacing.md),
                        Expanded(child: TextField(controller: ageRatingController, decoration: const InputDecoration(labelText: 'Classification d’âge'))),
                      ],
                    ),
                    const SizedBox(height: CinevaSpacing.md),
                    TextField(controller: directorController, decoration: const InputDecoration(labelText: 'Réalisateur')),
                    const SizedBox(height: CinevaSpacing.md),
                    TextField(controller: castController, decoration: const InputDecoration(labelText: 'Acteurs (séparés par des virgules)')),
                    const SizedBox(height: CinevaSpacing.md),
                    TextField(controller: genresController, decoration: const InputDecoration(labelText: 'Genres')),
                    const SizedBox(height: CinevaSpacing.md),
                    TextField(controller: countriesController, decoration: const InputDecoration(labelText: 'Pays')),
                    const SizedBox(height: CinevaSpacing.md),
                    TextField(controller: audioController, decoration: const InputDecoration(labelText: 'Langues audio')),
                    const SizedBox(height: CinevaSpacing.md),
                    TextField(controller: subtitlesController, decoration: const InputDecoration(labelText: 'Sous-titres')),
                    const SizedBox(height: CinevaSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(child: TextField(controller: trailerController, decoration: const InputDecoration(labelText: 'URL / chemin bande-annonce'))),
                        const SizedBox(width: CinevaSpacing.md),
                        Expanded(
                          child: TextField(
                            controller: videoController,
                            keyboardType: TextInputType.url,
                            decoration: InputDecoration(
                              labelText: contentType == 'movie' ? 'Chemin vidéo' : 'Chemin teaser / vidéo',
                              hintText: 'https://cdn.mon-site.fr/films/inception.2010.1080p.mp4',
                              helperText: 'URL du fichier dont vous détenez les droits (MP4/H.264, HLS). '
                                  'Renseignée automatiquement par « Importer une URL vidéo ».',
                              helperMaxLines: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: CinevaSpacing.md),
                    TextField(controller: ratingController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Notation')),
                    if (contentType == 'movie') ...<Widget>[
                      const SizedBox(height: CinevaSpacing.md),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Lecture — sauts de temps', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: CinevaSpacing.sm),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: introController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Fin d’intro (sec)'),
                            ),
                          ),
                          const SizedBox(width: CinevaSpacing.md),
                          Expanded(
                            child: TextField(
                              controller: creditsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Début générique (sec)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: CinevaSpacing.md),
                      _SkipSegmentEditor(
                        rows: skipSegmentRows,
                        onAdd: () => setState(() => skipSegmentRows.add(_SkipSegmentRow())),
                        onRemove: (index) => setState(() {
                          if (index >= 0 && index < skipSegmentRows.length) {
                            skipSegmentRows.removeAt(index).dispose();
                          }
                        }),
                      ),
                    ],
                    const SizedBox(height: CinevaSpacing.lg),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Catégories d’apparition', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const SizedBox(height: CinevaSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories
                          .map((category) => FilterChip(
                                label: Text(category.name),
                                selected: selectedCategoryIds.contains(category.id),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedCategoryIds.add(category.id);
                                    } else {
                                      selectedCategoryIds.remove(category.id);
                                    }
                                  });
                                },
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: CinevaSpacing.lg),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _MediaPickerCard(
                            label: 'Affiche',
                            bytes: posterBytes,
                            existingPath: existing?.posterPath,
                            filename: posterFilename,
                            onPick: () => pickImage(target: 'poster'),
                          ),
                        ),
                        const SizedBox(width: CinevaSpacing.md),
                        Expanded(
                          child: _MediaPickerCard(
                            label: 'Bannière / fond',
                            bytes: backdropBytes,
                            existingPath: existing?.backdropPath,
                            filename: backdropFilename,
                            onPick: () => pickImage(target: 'backdrop'),
                          ),
                        ),
                      ],
                    ),
                    if (contentType == 'series') ...<Widget>[
                      const SizedBox(height: CinevaSpacing.md),
                      _MediaPickerCard(
                        label: 'Logo de série',
                        bytes: logoBytes,
                        existingPath: existing?.logoPath,
                        filename: logoFilename,
                        onPick: () => pickImage(target: 'logo'),
                      ),
                    ],
                    const SizedBox(height: CinevaSpacing.md),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: isFeatured,
                      onChanged: (value) => setState(() => isFeatured = value),
                      title: const Text('Mettre en avant ce contenu'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: isPublished,
                      onChanged: saving ? null : (value) => setState(() => isPublished = value),
                      title: const Text('Publier ce contenu'),
                      subtitle: const Text(
                        'Désactivé, la fiche est enregistrée mais reste invisible '
                        'dans l’app abonné.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (titleController.text.trim().isEmpty) {
                          setState(() => saveError = 'Le titre est obligatoire.');
                          return;
                        }

                        setState(() {
                          saving = true;
                          saveError = null;
                        });

                        // Téléversement des images : un échec du stockage ne doit
                        // pas empêcher l'enregistrement de la fiche. L'image déjà
                        // en place est conservée et l'administrateur est prévenu.
                        final List<String> uploadWarnings = <String>[];
                        Future<String?> upload({
                          required Uint8List? bytes,
                          required String? filename,
                          required String bucket,
                          required String? current,
                          required String label,
                        }) async {
                          if (bytes == null || filename == null) return current;
                          try {
                            return await ref.read(adminRepositoryProvider).uploadMedia(
                                  bucket: bucket,
                                  filename: filename,
                                  bytes: bytes,
                                  contentType: _inferContentType(filename),
                                );
                          } catch (error) {
                            uploadWarnings.add(
                              '$label non téléversée (${_catalogErrorText(error)})',
                            );
                            return current;
                          }
                        }

                        final String? posterPath = await upload(
                          bytes: posterBytes,
                          filename: posterFilename,
                          bucket: 'posters',
                          current: existing?.posterPath,
                          label: 'Affiche',
                        );
                        final String? backdropPath = await upload(
                          bytes: backdropBytes,
                          filename: backdropFilename,
                          bucket: 'backdrops',
                          current: existing?.backdropPath,
                          label: 'Image de fond',
                        );
                        final String? logoPath = await upload(
                          bytes: logoBytes,
                          filename: logoFilename,
                          bucket: 'posters',
                          current: existing?.logoPath,
                          label: 'Logo',
                        );

                        final item = AdminCatalogItemModel(
                          id: existing?.id ?? '',
                          contentType: contentType,
                          title: titleController.text.trim(),
                          synopsis: synopsisController.text.trim(),
                          genres: _splitCommaValues(genresController.text),
                          audioLanguages: _splitCommaValues(audioController.text),
                          subtitleLanguages: _splitCommaValues(subtitlesController.text),
                          castNames: _splitCommaValues(castController.text),
                          categoryIds: selectedCategoryIds.toList(),
                          isFeatured: isFeatured,
                          isPublished: isPublished,
                          originalTitle: originalTitleController.text.trim().isEmpty ? null : originalTitleController.text.trim(),
                          posterPath: posterPath,
                          backdropPath: backdropPath,
                          logoPath: logoPath,
                          trailerPath: trailerController.text.trim().isEmpty ? null : trailerController.text.trim(),
                          videoPath: videoController.text.trim().isEmpty ? null : videoController.text.trim(),
                          releaseYear: int.tryParse(yearController.text.trim()),
                          durationMinutes: int.tryParse(durationController.text.trim()),
                          ageRating: ageRatingController.text.trim().isEmpty ? null : ageRatingController.text.trim(),
                          directorName: directorController.text.trim().isEmpty ? null : directorController.text.trim(),
                          countries: _splitCommaValues(countriesController.text),
                          rating: double.tryParse(ratingController.text.trim()),
                          introEndSeconds: contentType == 'movie' ? int.tryParse(introController.text.trim()) : null,
                          creditsStartSeconds: contentType == 'movie' ? int.tryParse(creditsController.text.trim()) : null,
                          skipSegments: contentType == 'movie' ? _skipSegmentsFromRows(skipSegmentRows) : const <SkipSegment>[],
                        );

                        try {
                          final CatalogSaveOutcome outcome = contentType == 'movie'
                              ? await ref.read(adminRepositoryProvider).saveMovie(item)
                              : await ref.read(adminRepositoryProvider).saveSeries(item);

                          // La boîte de dialogue ne se ferme qu'une fois la fiche
                          // réellement en base.
                          if (!dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop();

                          final bool published = outcome.item.isPublished;
                          final String saved = contentType == 'movie'
                              ? (published
                                  ? 'Film enregistré et publié.'
                                  : 'Film enregistré — non publié : il reste invisible '
                                      'dans l’app tant que « Publier ce contenu » '
                                      'n’est pas activé.')
                              : (published
                                  ? 'Série enregistrée et publiée.'
                                  : 'Série enregistrée — non publiée : elle reste '
                                      'invisible dans l’app.');
                          final List<String> warnings = <String>[
                            if (outcome.warning != null) outcome.warning!,
                            ...uploadWarnings,
                          ];
                          _finishCatalogAction(
                            context,
                            ref,
                            message: warnings.isEmpty ? saved : '$saved ${warnings.join(' ')}',
                            long: warnings.isNotEmpty,
                          );
                        } catch (error) {
                          if (!dialogContext.mounted) return;
                          setState(() {
                            saving = false;
                            saveError = _catalogErrorText(error);
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: CinevaColors.gold,
                        ),
                      )
                    : const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );
}
