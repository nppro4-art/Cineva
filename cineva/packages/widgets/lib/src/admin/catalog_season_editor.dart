part of 'catalog_screen.dart';

Future<void> _showSeasonEditor(BuildContext context, WidgetRef ref, String seriesId, {SeasonModel? season}) async {
  final titleController = TextEditingController(text: season?.title ?? '');
  final synopsisController = TextEditingController(text: season?.synopsis ?? '');
  final seasonNumberController = TextEditingController(text: season?.seasonNumber.toString() ?? '1');

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: CinevaColors.surface,
      title: Text(season == null ? 'Ajouter une saison' : 'Modifier ${season.title}'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Titre')),
            const SizedBox(height: CinevaSpacing.md),
            TextField(controller: seasonNumberController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Numéro de saison')),
            const SizedBox(height: CinevaSpacing.md),
            TextField(controller: synopsisController, maxLines: 3, decoration: const InputDecoration(labelText: 'Synopsis')),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Annuler')),
        FilledButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await _runCatalogAction(
              context,
              ref,
              () => ref.read(adminRepositoryProvider).saveSeason(
                    id: season?.id,
                    seriesId: seriesId,
                    seasonNumber: int.tryParse(seasonNumberController.text.trim()) ?? 1,
                    title: titleController.text.trim(),
                    synopsis: synopsisController.text.trim().isEmpty ? null : synopsisController.text.trim(),
                  ),
              successMessage: 'Saison enregistrée.',
            );
          },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}
