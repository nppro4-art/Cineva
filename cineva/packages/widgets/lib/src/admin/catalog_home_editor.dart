part of 'catalog_screen.dart';

Future<void> _showHomeSectionEditor(
  BuildContext context,
  WidgetRef ref, {
  AdminHomeSectionModel? section,
  required List<AdminCatalogItemModel> allContent,
}) async {
  final keyController = TextEditingController(text: section?.sectionKey ?? '');
  final titleController = TextEditingController(text: section?.title ?? '');
  final orderController = TextEditingController(text: section?.sortOrder.toString() ?? '0');
  String layoutType = section?.layoutType ?? 'rail';
  bool isEnabled = section?.isEnabled ?? true;
  final selectedItems = <AdminHomeSectionItemModel>[...(section?.items ?? const <AdminHomeSectionItemModel>[])];

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          void normalizeSelectedItems() {
            for (var i = 0; i < selectedItems.length; i++) {
              selectedItems[i] = AdminHomeSectionItemModel(
                id: selectedItems[i].id,
                homeSectionId: selectedItems[i].homeSectionId,
                contentType: selectedItems[i].contentType,
                contentId: selectedItems[i].contentId,
                sortOrder: i,
                title: selectedItems[i].title,
              );
            }
          }

          void addContent(AdminCatalogItemModel item) {
            if (selectedItems.any((existing) => existing.contentId == item.id && existing.contentType == item.contentType)) return;
            selectedItems.add(
              AdminHomeSectionItemModel(
                id: '',
                homeSectionId: section?.id ?? '',
                contentType: item.contentType,
                contentId: item.id,
                sortOrder: selectedItems.length,
                title: item.title,
              ),
            );
            setState(() {});
          }

          return AlertDialog(
            backgroundColor: CinevaColors.surface,
            title: Text(section == null ? 'Ajouter une section d’accueil' : 'Modifier ${section.title}'),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: TextField(controller: keyController, decoration: const InputDecoration(labelText: 'Clé de section'))),
                        const SizedBox(width: CinevaSpacing.md),
                        Expanded(child: TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Titre'))),
                      ],
                    ),
                    const SizedBox(height: CinevaSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: layoutType,
                            decoration: const InputDecoration(labelText: 'Layout'),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem(value: 'hero', child: Text('Hero')),
                              DropdownMenuItem(value: 'rail', child: Text('Rail')),
                              DropdownMenuItem(value: 'grid', child: Text('Grid')),
                              DropdownMenuItem(value: 'continue_watching', child: Text('Continue Watching')),
                              DropdownMenuItem(value: 'my_list', child: Text('My List')),
                            ],
                            onChanged: (value) => setState(() => layoutType = value ?? 'rail'),
                          ),
                        ),
                        const SizedBox(width: CinevaSpacing.md),
                        Expanded(child: TextField(controller: orderController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ordre'))),
                      ],
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: isEnabled,
                      onChanged: (value) => setState(() => isEnabled = value),
                      title: const Text('Section visible'),
                    ),
                    const SizedBox(height: CinevaSpacing.md),
                    const Text('Ajouter des contenus'),
                    const SizedBox(height: CinevaSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allContent
                          .map(
                            (content) => ActionChip(
                              label: Text(content.title),
                              onPressed: () => addContent(content),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: CinevaSpacing.lg),
                    const Text('Contenus sélectionnés'),
                    const SizedBox(height: CinevaSpacing.sm),
                    SizedBox(
                      height: selectedItems.isEmpty ? 56 : 260,
                      child: selectedItems.isEmpty
                          ? const Center(child: Text('Aucun contenu sélectionné pour cette section.'))
                          : ReorderableListView.builder(
                              shrinkWrap: true,
                              buildDefaultDragHandles: false,
                              itemCount: selectedItems.length,
                              onReorder: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) newIndex -= 1;
                                final moved = selectedItems.removeAt(oldIndex);
                                selectedItems.insert(newIndex, moved);
                                normalizeSelectedItems();
                                setState(() {});
                              },
                              itemBuilder: (context, index) {
                                final item = selectedItems[index];
                                return Padding(
                                  key: ValueKey('${item.contentType}:${item.contentId}'),
                                  padding: const EdgeInsets.only(bottom: CinevaSpacing.sm),
                                  child: ListTile(
                                    tileColor: CinevaColors.surfaceRaised,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CinevaRadii.small)),
                                    leading: ReorderableDragStartListener(
                                      index: index,
                                      child: const Icon(Icons.drag_indicator_rounded),
                                    ),
                                    title: Text(item.title),
                                    subtitle: Text('${item.contentType} • ordre ${item.sortOrder}'),
                                    trailing: IconButton(
                                      onPressed: () {
                                        selectedItems.removeAt(index);
                                        normalizeSelectedItems();
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.remove_circle_outline_rounded),
                                    ),
                                  ),
                                );
                              },
                            ),
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
                  await _runCatalogAction(
                    context,
                    ref,
                    () => ref.read(adminRepositoryProvider).saveHomeSection(
                          AdminHomeSectionModel(
                            id: section?.id ?? '',
                            sectionKey: keyController.text.trim(),
                            title: titleController.text.trim(),
                            layoutType: layoutType,
                            sortOrder: int.tryParse(orderController.text.trim()) ?? 0,
                            isEnabled: isEnabled,
                            items: selectedItems,
                          ),
                        ),
                    successMessage: 'Section d’accueil enregistrée.',
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
