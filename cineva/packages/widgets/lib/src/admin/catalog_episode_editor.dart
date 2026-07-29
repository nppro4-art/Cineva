part of 'catalog_screen.dart';

Future<void> _showEpisodeEditor(BuildContext context, WidgetRef ref, String seriesId, SeasonModel season, {EpisodeModel? episode}) async {
  final titleController = TextEditingController(text: episode?.title ?? '');
  Uint8List? thumbnailBytes;
  String? thumbnailFilename;
  final synopsisController = TextEditingController(text: episode?.synopsis ?? '');
  final episodeNumberController = TextEditingController(text: episode?.episodeNumber.toString() ?? '1');
  final durationController = TextEditingController(text: episode?.durationMinutes.toString() ?? '48');
  final videoController = TextEditingController(text: episode?.videoUrl ?? '');
  final audioController = TextEditingController(text: episode?.audioLanguages.join(', '));
  final subtitlesController = TextEditingController(text: episode?.subtitleLanguages.join(', '));
  final ratingController = TextEditingController(text: episode?.rating?.toString() ?? '');
  final introController = TextEditingController(text: episode?.introEndSeconds?.toString() ?? '');
  final creditsController = TextEditingController(text: episode?.creditsStartSeconds?.toString() ?? '');
  final nextEpisodeController = TextEditingController(text: episode?.nextEpisodeId ?? '');

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickThumbnail() async {
            final result = await FilePicker.platform.pickFiles(withData: true, type: FileType.image);
            if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
            final file = result.files.first;
            final name = file.name.toLowerCase();
            if (!(name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.webp'))) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Miniature invalide. Utilisez JPG, PNG ou WEBP.')),
                );
              }
              return;
            }
            if (file.bytes!.length > 8 * 1024 * 1024) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Miniature trop volumineuse. Maximum 8 Mo.')),
                );
              }
              return;
            }
            setState(() {
              thumbnailBytes = file.bytes;
              thumbnailFilename = file.name;
            });
          }

          return AlertDialog(
            backgroundColor: CinevaColors.surface,
            title: Text(episode == null ? 'Ajouter un épisode' : 'Modifier ${episode.title}'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Titre')),
                    const SizedBox(height: CinevaSpacing.md),
                    TextField(controller: synopsisController, maxLines: 3, decoration: const InputDecoration(labelText: 'Synopsis')),
                    const SizedBox(height: CinevaSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: episodeNumberController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Ordre épisode'),
                          ),
                        ),
                        const SizedBox(width: CinevaSpacing.md),
                        Expanded(
                          child: TextField(
                            controller: durationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Durée (min)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: CinevaSpacing.md),
                    TextField(controller: videoController, decoration: const InputDecoration(labelText: 'Chemin vidéo / URL')),
                    const SizedBox(height: CinevaSpacing.md),
                    TextField(controller: audioController, decoration: const InputDecoration(labelText: 'Langues audio')),
                    const SizedBox(height: CinevaSpacing.md),
                    TextField(controller: subtitlesController, decoration: const InputDecoration(labelText: 'Sous-titres')),
                    const SizedBox(height: CinevaSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: ratingController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Note'),
                          ),
                        ),
                        const SizedBox(width: CinevaSpacing.md),
                        Expanded(
                          child: TextField(
                            controller: introController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Fin intro (sec)'),
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
                    TextField(controller: nextEpisodeController, decoration: const InputDecoration(labelText: 'ID épisode suivant (optionnel)')),
                    const SizedBox(height: CinevaSpacing.md),
                    _MediaPickerCard(
                      label: 'Miniature épisode',
                      bytes: thumbnailBytes,
                      existingPath: episode?.thumbnailPath,
                      filename: thumbnailFilename,
                      onPick: pickThumbnail,
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
                  String? thumbnailPath = episode?.thumbnailPath;
                  if (thumbnailBytes != null && thumbnailFilename != null) {
                    thumbnailPath = await ref.read(adminRepositoryProvider).uploadMedia(
                          bucket: 'posters',
                          filename: thumbnailFilename!,
                          bytes: thumbnailBytes!,
                          contentType: _inferContentType(thumbnailFilename!),
                        );
                  }
                  await _runCatalogAction(
                    context,
                    ref,
                    () => ref.read(adminRepositoryProvider).saveEpisode(
                          EpisodeModel(
                            id: episode?.id ?? '',
                            seriesId: seriesId,
                            seasonId: season.id,
                            seasonNumber: season.seasonNumber,
                            episodeNumber: int.tryParse(episodeNumberController.text.trim()) ?? 1,
                            title: titleController.text.trim(),
                            synopsis: synopsisController.text.trim(),
                            durationMinutes: int.tryParse(durationController.text.trim()) ?? 48,
                            videoUrl: videoController.text.trim(),
                            thumbnailPath: thumbnailPath,
                            audioLanguages: _splitCommaValues(audioController.text),
                            subtitleLanguages: _splitCommaValues(subtitlesController.text),
                            rating: double.tryParse(ratingController.text.trim()),
                            introEndSeconds: int.tryParse(introController.text.trim()),
                            creditsStartSeconds: int.tryParse(creditsController.text.trim()),
                            nextEpisodeId: nextEpisodeController.text.trim().isEmpty ? null : nextEpisodeController.text.trim(),
                          ),
                        ),
                    successMessage: 'Épisode enregistré.',
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
