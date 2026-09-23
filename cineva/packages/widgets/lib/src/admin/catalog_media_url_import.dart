part of 'catalog_screen.dart';

/// Import par URL vidéo : l'administrateur fournit **son** fichier (droits
/// détenus, hébergement propre ou sous licence), TMDB fournit les métadonnées
/// publiques.
///
/// Déroulé : coller l'URL → le titre est pré-rempli depuis le nom du fichier →
/// recherche TMDB → l'administrateur choisit la fiche parmi les candidats →
/// l'éditeur s'ouvre pré-rempli, l'URL vidéo déjà en place. Rien n'est deviné en
/// silence : si le nom de fichier est opaque, le titre est demandé.
Future<void> _showMediaUrlImportDialog(
  BuildContext context,
  WidgetRef ref,
  List<AdminCategoryModel> categories, {
  String contentType = 'movie',
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _MediaUrlImportDialog(
      catalogContext: context,
      outerRef: ref,
      categories: categories,
      contentType: contentType,
    ),
  );
}

class _MediaUrlImportDialog extends StatefulWidget {
  const _MediaUrlImportDialog({
    required this.catalogContext,
    required this.outerRef,
    required this.categories,
    required this.contentType,
  });

  /// Contexte de l'onglet catalogue : sert à ouvrir l'éditeur une fois la boîte
  /// de dialogue fermée (le contexte de la boîte ne survit pas au `pop`).
  final BuildContext catalogContext;

  final WidgetRef outerRef;
  final List<AdminCategoryModel> categories;
  final String contentType;

  @override
  State<_MediaUrlImportDialog> createState() => _MediaUrlImportDialogState();
}

class _MediaUrlImportDialogState extends State<_MediaUrlImportDialog> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  TmdbMediaType _mediaType = TmdbMediaType.movie;
  List<TmdbSearchHit> _hits = const <TmdbSearchHit>[];
  MediaUrlTitleHint? _hint;
  bool _searching = false;
  bool _opening = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _mediaType = widget.contentType == 'series' ? TmdbMediaType.series : TmdbMediaType.movie;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  bool get _busy => _searching || _opening;

  /// Lit le nom du fichier et pré-remplit le titre (jamais à l'insu de
  /// l'administrateur : la valeur apparaît dans le champ et reste modifiable).
  void _onUrlChanged(String value) {
    final hint = titleHintFromMediaUrl(value);
    setState(() {
      _hint = hint;
      _hits = const <TmdbSearchHit>[];
      _message = null;
      if (hint != null && hint.hasTitle && _titleController.text.trim().isEmpty) {
        _titleController.text = hint.title;
      }
    });
  }

  Future<void> _search() async {
    final query = _titleController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _message = _hint != null && !_hint!.hasTitle
            ? 'Le nom du fichier n’est pas exploitable (empreinte ou identifiant technique). Saisissez le titre du film.'
            : 'Saisissez un titre à chercher sur TMDB.';
      });
      return;
    }

    setState(() {
      _searching = true;
      _message = null;
      _hits = const <TmdbSearchHit>[];
    });

    // Même préparation que dans le client : sert à dire à l'administrateur ce
    // qui a été cherché (titre nettoyé, année détectée) quand rien ne remonte.
    final TmdbQueryPlan plan = buildTmdbQueryPlan(rawQuery: query, year: _hint?.year);

    try {
      final hits = await widget.outerRef.read(adminRepositoryProvider).searchTmdbTitles(
            query: query,
            mediaType: _mediaType,
            year: _hint?.year,
          );
      if (!mounted) return;
      setState(() {
        _searching = false;
        _hits = hits;
        _message = hits.isEmpty
            ? _noResultMessage(query, plan)
            : '${hits.length} fiche(s) trouvée(s) — choisissez la bonne.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _message = _importErrorMessage(error);
      });
    }
  }

  /// Message d'échec : ce qui a été cherché, et comment débloquer la situation.
  String _noResultMessage(String query, TmdbQueryPlan plan) {
    final String title = plan.title.isEmpty ? query : plan.title;
    final String year = plan.year == null ? '' : ' (${plan.year})';
    return 'Aucune fiche TMDB pour « $title »$year. Recherche tentée sur le titre '
        'complet, le titre court, sans accents et sur la fiche anglaise. '
        'Vérifiez l’orthographe — un titre court suffit souvent (« Vaiana ») —, '
        'retirez l’année si elle est incertaine, ou créez la fiche sans '
        'métadonnées.';
  }

  Future<void> _openFromHit(TmdbSearchHit hit) async {
    final url = _urlController.text.trim();
    setState(() => _opening = true);
    try {
      final draft = await widget.outerRef.read(adminRepositoryProvider).fetchTmdbDraft(hit.toReference());
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!widget.catalogContext.mounted) return;
      await _showCatalogEditor(
        widget.catalogContext,
        widget.outerRef,
        widget.categories,
        contentType: draft.mediaType == TmdbMediaType.movie ? 'movie' : 'series',
        existing: _tmdbDraftToCatalogItem(draft, videoPath: url.isEmpty ? null : url),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _message = _importErrorMessage(error);
      });
    }
  }

  /// Repli assumé : une fiche créée sans TMDB, avec l'URL vidéo et le titre
  /// saisis. À compléter dans l'éditeur — aucune donnée n'est inventée.
  Future<void> _openWithoutMetadata() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _message = 'Collez d’abord l’URL de la vidéo.');
      return;
    }

    Navigator.of(context).pop();
    if (!widget.catalogContext.mounted) return;
    await _showCatalogEditor(
      widget.catalogContext,
      widget.outerRef,
      widget.categories,
      contentType: _mediaType == TmdbMediaType.movie ? 'movie' : 'series',
      existing: AdminCatalogItemModel(
        id: '',
        contentType: _mediaType == TmdbMediaType.movie ? 'movie' : 'series',
        title: _titleController.text.trim(),
        synopsis: '',
        genres: const <String>[],
        audioLanguages: const <String>[],
        subtitleLanguages: const <String>[],
        castNames: const <String>[],
        categoryIds: const <String>[],
        isFeatured: false,
        isPublished: false,
        videoPath: url,
        releaseYear: _hint?.year,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = _hint;

    return AlertDialog(
      backgroundColor: CinevaColors.surface,
      title: const Text('Importer depuis une URL vidéo'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Collez l’URL du fichier vidéo dont vous détenez les droits '
              '(hébergement Cineva, CDN, stockage Supabase). Le titre est déduit '
              'du nom du fichier, puis TMDB fournit synopsis, affiches, note, '
              'casting et bande-annonce.',
              style: theme.textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
            ),
            const SizedBox(height: CinevaSpacing.md),
            TextField(
              controller: _urlController,
              onChanged: _onUrlChanged,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'URL de la vidéo',
                hintText: 'https://cdn.mon-site.fr/films/inception.2010.1080p.mp4',
              ),
            ),
            if (hint != null && hint.fileName.isNotEmpty) ...<Widget>[
              const SizedBox(height: CinevaSpacing.sm),
              Text(
                'Fichier : ${hint.fileName}'
                '${hint.year == null ? '' : '  ·  année détectée : ${hint.year}'}'
                '${hint.hasTitle ? '' : '  ·  titre non exploitable, à saisir'}',
                style: theme.textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
              ),
            ],
            const SizedBox(height: CinevaSpacing.md),
            TextField(
              controller: _titleController,
              enabled: !_busy,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                labelText: 'Titre à chercher sur TMDB',
                hintText: 'Inception',
              ),
            ),
            const SizedBox(height: CinevaSpacing.md),
            SegmentedButton<TmdbMediaType>(
              segments: const <ButtonSegment<TmdbMediaType>>[
                ButtonSegment(value: TmdbMediaType.movie, label: Text('Film')),
                ButtonSegment(value: TmdbMediaType.series, label: Text('Série')),
              ],
              selected: <TmdbMediaType>{_mediaType},
              showSelectedIcon: false,
              onSelectionChanged: _busy
                  ? null
                  : (selection) => setState(() {
                        _mediaType = selection.first;
                        _hits = const <TmdbSearchHit>[];
                      }),
            ),
            if (_message != null) ...<Widget>[
              const SizedBox(height: CinevaSpacing.md),
              Text(_message!, style: theme.textTheme.bodySmall?.copyWith(color: CinevaColors.textPrimary)),
            ],
            if (_hits.isNotEmpty) ...<Widget>[
              const SizedBox(height: CinevaSpacing.md),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _hits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: CinevaSpacing.sm),
                  itemBuilder: (listContext, index) => _TmdbHitTile(
                    hit: _hits[index],
                    enabled: !_busy,
                    onTap: () => _openFromHit(_hits[index]),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        TextButton.icon(
          onPressed: _busy ? null : _openWithoutMetadata,
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Créer sans TMDB'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _search,
          icon: _searching
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search_rounded),
          label: Text(_searching ? 'Recherche…' : 'Chercher sur TMDB'),
        ),
      ],
    );
  }
}

/// Candidat TMDB : affiche, titre, année, note et amorce de synopsis.
class _TmdbHitTile extends StatelessWidget {
  const _TmdbHitTile({required this.hit, required this.onTap, this.enabled = true});

  final TmdbSearchHit hit;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = hit.rating;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(CinevaRadii.small),
      child: Padding(
        padding: const EdgeInsets.all(CinevaSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(CinevaRadii.small),
              child: SizedBox(
                width: 46,
                height: 68,
                child: hit.posterUrl == null
                    ? _posterFallback(theme)
                    : Image.network(
                        hit.posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _posterFallback(theme),
                        loadingBuilder: (imageContext, child, progress) =>
                            progress == null ? child : _posterFallback(theme),
                      ),
              ),
            ),
            const SizedBox(width: CinevaSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(hit.title, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${hit.yearLabel}'
                    '${rating == null || rating <= 0 ? '' : '  ·  note ${rating.toStringAsFixed(1)}'}'
                    '${hit.originalTitle == hit.title ? '' : '  ·  ${hit.originalTitle}'}',
                    style: theme.textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hit.overview.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      hit.overview,
                      style: theme.textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: CinevaColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _posterFallback(ThemeData theme) {
    return ColoredBox(
      color: CinevaColors.surfaceRaised,
      child: Center(
        child: Icon(Icons.movie_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// Message lisible : `AppFailure` porte déjà un texte destiné à l'utilisateur.
String _importErrorMessage(Object error) {
  if (error is AppFailure) return error.message;
  return error.toString();
}
