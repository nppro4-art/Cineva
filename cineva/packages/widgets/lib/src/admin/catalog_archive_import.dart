part of 'catalog_screen.dart';

/// Import en masse depuis **Internet Archive** : films du domaine public,
/// hébergés par l'archive avec leurs fichiers vidéo directs.
///
/// Même forme qu'un aspirateur de catalogue (une source collée → énumération →
/// fiches enrichies → entrées créées), sur une source dont la diffusion est
/// autorisée. Les éléments sans MP4 lisible sont écartés, jamais remplacés par
/// une URL inventée. Par défaut l'import crée des **brouillons non publiés** :
/// l'administrateur relit, vérifie la licence affichée, puis publie.
Future<void> _showArchiveImportDialog(
  BuildContext context,
  WidgetRef ref,
  List<AdminCategoryModel> categories,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _ArchiveImportDialog(
      outerRef: ref,
      categories: categories,
    ),
  );
}

class _ArchiveImportDialog extends StatefulWidget {
  const _ArchiveImportDialog({
    required this.outerRef,
    required this.categories,
  });

  final WidgetRef outerRef;
  final List<AdminCategoryModel> categories;

  @override
  State<_ArchiveImportDialog> createState() => _ArchiveImportDialogState();
}

class _ArchiveImportDialogState extends State<_ArchiveImportDialog> {
  final TextEditingController _sourceController = TextEditingController(text: 'collection:feature_films');

  List<ArchiveOrgItemDraft> _candidates = const <ArchiveOrgItemDraft>[];
  final Set<String> _selected = <String>{};

  int _limit = 24;
  String? _categoryId;
  bool _openLicenseOnly = false;
  bool _publishImmediately = false;
  bool _scanning = false;
  bool _importing = false;
  int _resolved = 0;
  int _total = 0;
  int _imported = 0;
  int _failed = 0;
  String? _message;

  @override
  void dispose() {
    _sourceController.dispose();
    super.dispose();
  }

  bool get _busy => _scanning || _importing;

  Future<void> _scan() async {
    final reference = ArchiveOrgReference.tryParse(_sourceController.text);
    if (reference == null) {
      setState(() {
        _message = 'Source non reconnue. Utilisez un lien archive.org/details/…, '
            '« collection:feature_films » ou des mots-clés.';
      });
      return;
    }

    setState(() {
      _scanning = true;
      _message = null;
      _candidates = const <ArchiveOrgItemDraft>[];
      _selected.clear();
      _resolved = 0;
      _total = 0;
      _imported = 0;
      _failed = 0;
    });

    try {
      final drafts = await widget.outerRef.read(archiveOrgClientProvider).expand(
            reference,
            limit: _limit,
            onProgress: (resolved, total) {
              if (!mounted) return;
              setState(() {
                _resolved = resolved;
                _total = total;
              });
            },
          );
      if (!mounted) return;

      final kept = _openLicenseOnly ? drafts.where((draft) => draft.isLicenseOpen).toList() : drafts;
      setState(() {
        _scanning = false;
        _candidates = kept;
        _selected.addAll(kept.map((draft) => draft.identifier));
        _message = kept.isEmpty
            ? 'Aucun élément jouable'
                '${_openLicenseOnly ? ' avec une licence explicitement ouverte' : ''}'
                ' dans cette source.'
            : '${kept.length} film(s) jouable(s) — vérifiez les licences avant publication.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _message = _importErrorMessage(error);
      });
    }
  }

  Future<void> _import() async {
    final chosen = _candidates.where((draft) => _selected.contains(draft.identifier)).toList();
    if (chosen.isEmpty) {
      setState(() => _message = 'Sélectionnez au moins un film à importer.');
      return;
    }

    setState(() {
      _importing = true;
      _imported = 0;
      _failed = 0;
      _message = null;
    });

    final repository = widget.outerRef.read(adminRepositoryProvider);
    final failures = <String>[];
    String? categoryWarning;
    for (final draft in chosen) {
      try {
        final outcome = await repository.saveMovie(
          draft.toCatalogItem(
            isPublished: _publishImmediately,
            categoryIds: _categoryId == null ? const <String>[] : <String>[_categoryId!],
          ),
        );
        _imported += 1;
        // La fiche est en base : un échec de liaison des catégories ne doit pas
        // être confondu avec un échec d'import.
        categoryWarning ??= outcome.warning;
      } catch (error) {
        _failed += 1;
        if (failures.length < 3) failures.add('${draft.title} : ${_importErrorMessage(error)}');
      }
      if (!mounted) return;
      setState(() {});
    }

    if (!mounted) return;
    widget.outerRef.invalidate(adminMoviesProvider);
    setState(() {
      _importing = false;
      _message = '$_imported film(s) importé(s)'
          '${_publishImmediately ? ' et publié(s)' : ' en brouillon'}'
          '${_failed == 0 ? '.' : ' · $_failed échec(s) — ${failures.join(' | ')}'}'
          '${categoryWarning == null ? '' : ' · $categoryWarning'}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _total == 0 ? null : (_resolved / _total).clamp(0.0, 1.0).toDouble();
    final importProgress = _selected.isEmpty
        ? null
        : ((_imported + _failed) / _selected.length).clamp(0.0, 1.0).toDouble();

    return AlertDialog(
      backgroundColor: CinevaColors.surface,
      title: const Text('Importer depuis Internet Archive'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Collez une source Internet Archive : lien d’une collection ou d’un '
              'élément, « collection:feature_films », ou des mots-clés. Chaque '
              'candidat est vérifié (fichier MP4 présent) puis proposé avec son '
              'affiche, sa durée et sa licence.',
              style: theme.textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
            ),
            const SizedBox(height: CinevaSpacing.md),
            TextField(
              controller: _sourceController,
              enabled: !_busy,
              onSubmitted: (_) => _scan(),
              decoration: const InputDecoration(
                labelText: 'Source Internet Archive',
                hintText: 'https://archive.org/details/feature_films  ·  night of the living dead',
              ),
            ),
            const SizedBox(height: CinevaSpacing.md),
            SegmentedButton<int>(
              segments: const <ButtonSegment<int>>[
                ButtonSegment(value: 12, label: Text('12')),
                ButtonSegment(value: 24, label: Text('24')),
                ButtonSegment(value: 48, label: Text('48')),
              ],
              selected: <int>{_limit},
              showSelectedIcon: false,
              onSelectionChanged: _busy ? null : (selection) => setState(() => _limit = selection.first),
            ),
            const SizedBox(height: CinevaSpacing.sm),
            CheckboxListTile(
              value: _openLicenseOnly,
              onChanged: _busy ? null : (value) => setState(() => _openLicenseOnly = value ?? false),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Ne garder que les licences explicitement ouvertes'),
            ),
            if (widget.categories.isNotEmpty) ...<Widget>[
              DropdownButtonFormField<String?>(
                value: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ranger dans la catégorie'),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(value: null, child: Text('Aucune catégorie')),
                  ...widget.categories.map(
                    (category) => DropdownMenuItem<String?>(value: category.id, child: Text(category.name)),
                  ),
                ],
                onChanged: _busy ? null : (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: CinevaSpacing.sm),
            ],
            CheckboxListTile(
              value: _publishImmediately,
              onChanged: _busy ? null : (value) => setState(() => _publishImmediately = value ?? false),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Publier immédiatement (sinon : brouillons à relire)'),
            ),
            if (_scanning && progress != null) ...<Widget>[
              const SizedBox(height: CinevaSpacing.sm),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 4),
              Text(
                'Analyse des fichiers vidéo… $_resolved / $_total',
                style: theme.textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
              ),
            ],
            if (_importing && importProgress != null) ...<Widget>[
              const SizedBox(height: CinevaSpacing.sm),
              LinearProgressIndicator(value: importProgress),
              const SizedBox(height: 4),
              Text(
                'Création des fiches… ${_imported + _failed} / ${_selected.length}',
                style: theme.textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
              ),
            ],
            if (_message != null) ...<Widget>[
              const SizedBox(height: CinevaSpacing.sm),
              Text(_message!, style: theme.textTheme.bodySmall?.copyWith(color: CinevaColors.textPrimary)),
            ],
            if (_candidates.isNotEmpty) ...<Widget>[
              const SizedBox(height: CinevaSpacing.md),
              Row(
                children: <Widget>[
                  Text(
                    '${_selected.length} / ${_candidates.length} sélectionné(s)',
                    style: theme.textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              if (_selected.length == _candidates.length) {
                                _selected.clear();
                              } else {
                                _selected
                                  ..clear()
                                  ..addAll(_candidates.map((draft) => draft.identifier));
                              }
                            }),
                    child: Text(_selected.length == _candidates.length ? 'Aucun' : 'Tout sélectionner'),
                  ),
                ],
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _candidates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: CinevaColors.border),
                  itemBuilder: (listContext, index) {
                    final draft = _candidates[index];
                    return CheckboxListTile(
                      value: _selected.contains(draft.identifier),
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                                if (value ?? false) {
                                  _selected.add(draft.identifier);
                                } else {
                                  _selected.remove(draft.identifier);
                                }
                              }),
                      dense: true,
                      secondary: ClipRRect(
                        borderRadius: BorderRadius.circular(CinevaRadii.small),
                        child: SizedBox(
                          width: 46,
                          height: 68,
                          child: Image.network(
                            draft.posterUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: CinevaColors.surfaceRaised,
                              child: Center(child: Icon(Icons.movie_rounded, size: 20)),
                            ),
                            loadingBuilder: (imageContext, child, progressDetails) =>
                                progressDetails == null
                                    ? child
                                    : const ColoredBox(
                                        color: CinevaColors.surfaceRaised,
                                      ),
                          ),
                        ),
                      ),
                      title: Text(draft.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${draft.releaseYear?.toString() ?? 'année inconnue'}'
                        '${draft.durationMinutes == null ? '' : '  ·  ${draft.durationMinutes} min'}'
                        '  ·  ${draft.resolutionLabel}'
                        '  ·  ${draft.licenseLabel}',
                        style: theme.textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(_imported > 0 ? 'Fermer' : 'Annuler'),
        ),
        if (_candidates.isNotEmpty)
          FilledButton.icon(
            onPressed: _busy ? null : _import,
            icon: _importing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(_importing ? 'Import…' : 'Importer ${_selected.length} film(s)'),
          ),
        FilledButton.tonalIcon(
          onPressed: _busy ? null : _scan,
          icon: _scanning
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.travel_explore_rounded),
          label: Text(_scanning ? 'Parcours…' : 'Parcourir la source'),
        ),
      ],
    );
  }
}
