part of 'catalog_screen.dart';

Future<void> _showCategoryEditor(BuildContext context, WidgetRef ref, {AdminCategoryModel? category}) async {
  final nameController = TextEditingController(text: category?.name ?? '');
  final slugController = TextEditingController(text: category?.slug ?? '');
  String categoryType = category?.categoryType ?? 'generic';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: CinevaColors.surface,
            title: Text(category == null ? 'Ajouter une catégorie' : 'Modifier ${category.name}'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom')),
                  const SizedBox(height: CinevaSpacing.md),
                  TextField(controller: slugController, decoration: const InputDecoration(labelText: 'Slug')),
                  const SizedBox(height: CinevaSpacing.md),
                  DropdownButtonFormField<String>(
                    value: categoryType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'generic', child: Text('Générique')),
                      DropdownMenuItem(value: 'genre', child: Text('Genre')),
                      DropdownMenuItem(value: 'curation', child: Text('Curation')),
                      DropdownMenuItem(value: 'home', child: Text('Accueil')),
                    ],
                    onChanged: (value) => setState(() => categoryType = value ?? 'generic'),
                  ),
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
                    () => ref.read(adminRepositoryProvider).upsertCategory(
                          id: category?.id,
                          name: nameController.text.trim(),
                          slug: slugController.text.trim(),
                          categoryType: categoryType,
                        ),
                    successMessage: 'Catégorie enregistrée.',
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
