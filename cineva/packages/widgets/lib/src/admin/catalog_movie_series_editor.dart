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
                        Expanded(child: TextField(controller: videoController, decoration: InputDecoration(labelText: contentType == 'movie' ? 'Chemin vidéo' : 'Chemin teaser / vidéo'))),
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
                      onChanged: (value) => setState(() => isPublished = value),
                      title: const Text('Publier ce contenu'),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Annuler')),
              FilledButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();

                  String? posterPath = existing?.posterPath;
                  String? backdropPath = existing?.backdropPath;
                  String? logoPath = existing?.logoPath;
                  if (posterBytes != null && posterFilename != null) {
                    posterPath = await ref.read(adminRepositoryProvider).uploadMedia(
                          bucket: 'posters',
                          filename: posterFilename!,
                          bytes: posterBytes!,
                          contentType: _inferContentType(posterFilename!),
                        );
                  }
                  if (backdropBytes != null && backdropFilename != null) {
                    backdropPath = await ref.read(adminRepositoryProvider).uploadMedia(
                          bucket: 'backdrops',
                          filename: backdropFilename!,
                          bytes: backdropBytes!,
                          contentType: _inferContentType(backdropFilename!),
                        );
                  }
                  if (logoBytes != null && logoFilename != null) {
                    logoPath = await ref.read(adminRepositoryProvider).uploadMedia(
                          bucket: 'posters',
                          filename: logoFilename!,
                          bytes: logoBytes!,
                          contentType: _inferContentType(logoFilename!),
                        );
                  }

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

                  await _runCatalogAction(
                    context,
                    ref,
                    () => contentType == 'movie'
                        ? ref.read(adminRepositoryProvider).saveMovie(item)
                        : ref.read(adminRepositoryProvider).saveSeries(item),
                    successMessage: contentType == 'movie' ? 'Film enregistré.' : 'Série enregistrée.',
                  );
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );
}
