part of 'catalog_screen.dart';

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader();

  @override
  Widget build(BuildContext context) {
    return const CinevaPageHeader(
      title: 'Catalogue',
      subtitle:
          'CMS Cineva pour gérer films, séries, saisons, épisodes, catégories et page d’accueil sans toucher à Supabase manuellement.',
    );
  }
}

class _MoviesTab extends ConsumerStatefulWidget {
  const _MoviesTab();

  @override
  ConsumerState<_MoviesTab> createState() => _MoviesTabState();
}

class _MoviesTabState extends ConsumerState<_MoviesTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: ref.read(adminMovieSearchQueryProvider));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(adminMoviesProvider);
    final categoriesAsync = ref.watch(adminCategoriesProvider);

    return ListView(
      padding: const EdgeInsets.all(CinevaSpacing.lg),
      children: <Widget>[
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 820;
            final searchField = CinevaTextField(
              controller: _searchController,
              label: 'Rechercher un film',
              hint: 'Titre ou réalisateur',
              prefixIcon: Icons.search_rounded,
              onChanged: (value) => ref.read(adminMovieSearchQueryProvider.notifier).state = value,
            );
            final addButton = FilledButton.icon(
              onPressed: categoriesAsync.hasValue
                  ? () => _showMovieEditor(context, ref, categoriesAsync.value ?? const <AdminCategoryModel>[])
                  : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter un film'),
            );
            final importButton = FilledButton.tonalIcon(
              onPressed: categoriesAsync.hasValue
                  ? () => _showTmdbImportDialog(context, ref, categoriesAsync.value ?? const <AdminCategoryModel>[], contentType: 'movie')
                  : null,
              icon: const Icon(Icons.link_rounded),
              label: const Text('Importer (TMDB)'),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  searchField,
                  const SizedBox(height: CinevaSpacing.md),
                  Align(alignment: Alignment.centerLeft, child: importButton),
                  const SizedBox(height: CinevaSpacing.sm),
                  Align(alignment: Alignment.centerLeft, child: addButton),
                ],
              );
            }

            return Row(
              children: <Widget>[
                Expanded(child: searchField),
                const SizedBox(width: CinevaSpacing.md),
                importButton,
                const SizedBox(width: CinevaSpacing.md),
                addButton,
              ],
            );
          },
        ),
        const SizedBox(height: CinevaSpacing.xl),
        moviesAsync.when(
          loading: () => const SizedBox(height: 280, child: CinevaLoadingView(label: 'Chargement des films...')),
          error: (error, _) => CinevaStatusBanner(
            title: 'Impossible de charger les films',
            message: error.toString(),
            tone: CinevaBannerTone.error,
          ),
          data: (movies) {
            if (movies.isEmpty) {
              return const CinevaStatusBanner(
                title: 'Aucun film',
                message: 'Ajoutez votre premier film pour alimenter Cineva.',
              );
            }
            final categories = categoriesAsync.value ?? const <AdminCategoryModel>[];
            return Column(
              children: movies
                  .map((movie) => Padding(
                        padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
                        child: _CatalogItemCard(
                          item: movie,
                          onEdit: () => _showMovieEditor(context, ref, categories, movie: movie),
                          onDelete: () => _confirmDelete(
                            context,
                            title: 'Supprimer le film',
                            message: 'Supprimer définitivement ${movie.title} ?',
                            onConfirm: () => _runCatalogAction(
                              context,
                              ref,
                              () => ref.read(adminRepositoryProvider).deleteMovie(movie.id),
                              successMessage: 'Film supprimé.',
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _SeriesTab extends ConsumerStatefulWidget {
  const _SeriesTab();

  @override
  ConsumerState<_SeriesTab> createState() => _SeriesTabState();
}

class _SeriesTabState extends ConsumerState<_SeriesTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: ref.read(adminSeriesSearchQueryProvider));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seriesAsync = ref.watch(adminSeriesProvider);
    final categoriesAsync = ref.watch(adminCategoriesProvider);

    return ListView(
      padding: const EdgeInsets.all(CinevaSpacing.lg),
      children: <Widget>[
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 820;
            final searchField = CinevaTextField(
              controller: _searchController,
              label: 'Rechercher une série',
              hint: 'Titre ou réalisateur',
              prefixIcon: Icons.search_rounded,
              onChanged: (value) => ref.read(adminSeriesSearchQueryProvider.notifier).state = value,
            );
            final addButton = FilledButton.icon(
              onPressed: categoriesAsync.hasValue
                  ? () => _showSeriesEditor(context, ref, categoriesAsync.value ?? const <AdminCategoryModel>[])
                  : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter une série'),
            );
            final importButton = FilledButton.tonalIcon(
              onPressed: categoriesAsync.hasValue
                  ? () => _showTmdbImportDialog(context, ref, categoriesAsync.value ?? const <AdminCategoryModel>[], contentType: 'series')
                  : null,
              icon: const Icon(Icons.link_rounded),
              label: const Text('Importer (TMDB)'),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  searchField,
                  const SizedBox(height: CinevaSpacing.md),
                  Align(alignment: Alignment.centerLeft, child: importButton),
                  const SizedBox(height: CinevaSpacing.sm),
                  Align(alignment: Alignment.centerLeft, child: addButton),
                ],
              );
            }

            return Row(
              children: <Widget>[
                Expanded(child: searchField),
                const SizedBox(width: CinevaSpacing.md),
                importButton,
                const SizedBox(width: CinevaSpacing.md),
                addButton,
              ],
            );
          },
        ),
        const SizedBox(height: CinevaSpacing.xl),
        seriesAsync.when(
          loading: () => const SizedBox(height: 280, child: CinevaLoadingView(label: 'Chargement des séries...')),
          error: (error, _) => CinevaStatusBanner(
            title: 'Impossible de charger les séries',
            message: error.toString(),
            tone: CinevaBannerTone.error,
          ),
          data: (seriesList) {
            if (seriesList.isEmpty) {
              return const CinevaStatusBanner(
                title: 'Aucune série',
                message: 'Ajoutez votre première série pour enrichir le catalogue.',
              );
            }
            final categories = categoriesAsync.value ?? const <AdminCategoryModel>[];
            return Column(
              children: seriesList
                  .map((series) => Padding(
                        padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
                        child: _CatalogItemCard(
                          item: series,
                          onEdit: () => _showSeriesEditor(context, ref, categories, series: series),
                          onDelete: () => _confirmDelete(
                            context,
                            title: 'Supprimer la série',
                            message: 'Supprimer définitivement ${series.title} et ses saisons ? ',
                            onConfirm: () => _runCatalogAction(
                              context,
                              ref,
                              () => ref.read(adminRepositoryProvider).deleteSeries(series.id),
                              successMessage: 'Série supprimée.',
                            ),
                          ),
                          extraActions: <Widget>[
                            FilledButton.tonalIcon(
                              onPressed: () => _showSeriesStructureManager(context, ref, series),
                              icon: const Icon(Icons.library_books_rounded),
                              label: const Text('Saisons / épisodes'),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(adminCategoriesProvider);

    return ListView(
      padding: const EdgeInsets.all(CinevaSpacing.lg),
      children: <Widget>[
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            const title = Expanded(
              child: CinevaSectionTitle(
                title: 'Catégories',
                actionLabel: 'Genres, recommandations éditoriales et sections d’accueil',
              ),
            );
            final addButton = FilledButton.icon(
              onPressed: () => _showCategoryEditor(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter une catégorie'),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const CinevaSectionTitle(
                    title: 'Catégories',
                    actionLabel: 'Genres, recommandations éditoriales et sections d’accueil',
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  Align(alignment: Alignment.centerLeft, child: addButton),
                ],
              );
            }

            return Row(
              children: <Widget>[title, addButton],
            );
          },
        ),
        const SizedBox(height: CinevaSpacing.xl),
        categoriesAsync.when(
          loading: () => const SizedBox(height: 220, child: CinevaLoadingView(label: 'Chargement des catégories...')),
          error: (error, _) => CinevaStatusBanner(
            title: 'Impossible de charger les catégories',
            message: error.toString(),
            tone: CinevaBannerTone.error,
          ),
          data: (categories) => Column(
            children: categories
                .map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
                    child: CinevaGlassCard(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(category.name, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  '${category.slug} • ${category.categoryType}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Modifier ${category.name}',
                            onPressed: () => _showCategoryEditor(context, ref, category: category),
                            icon: const Icon(Icons.edit_rounded),
                          ),
                          IconButton(
                            tooltip: 'Supprimer ${category.name}',
                            onPressed: () => _confirmDelete(
                              context,
                              title: 'Supprimer la catégorie',
                              message: 'Supprimer ${category.name} ?',
                              onConfirm: () => _runCatalogAction(
                                context,
                                ref,
                                () => ref.read(adminRepositoryProvider).deleteCategory(category.id),
                                successMessage: 'Catégorie supprimée.',
                              ),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _HomeEditorTab extends ConsumerWidget {
  const _HomeEditorTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(adminHomeSectionsProvider);
    final moviesAsync = ref.watch(adminMoviesProvider);
    final seriesAsync = ref.watch(adminSeriesProvider);

    return ListView(
      padding: const EdgeInsets.all(CinevaSpacing.lg),
      children: <Widget>[
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final addButton = FilledButton.icon(
              onPressed: sectionsAsync.hasValue && moviesAsync.hasValue && seriesAsync.hasValue
                  ? () => _showHomeSectionEditor(
                        context,
                        ref,
                        allContent: <AdminCatalogItemModel>[
                          ...moviesAsync.value ?? const <AdminCatalogItemModel>[],
                          ...seriesAsync.value ?? const <AdminCatalogItemModel>[],
                        ],
                      )
                  : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter une section'),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const CinevaSectionTitle(
                    title: 'Éditeur de l’accueil',
                    actionLabel: 'Bannière principale, sections, ordre et recommandations éditoriales',
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  Align(alignment: Alignment.centerLeft, child: addButton),
                ],
              );
            }

            return Row(
              children: <Widget>[
                const Expanded(
                  child: CinevaSectionTitle(
                    title: 'Éditeur de l’accueil',
                    actionLabel: 'Bannière principale, sections, ordre et recommandations éditoriales',
                  ),
                ),
                addButton,
              ],
            );
          },
        ),
        const SizedBox(height: CinevaSpacing.xl),
        sectionsAsync.when(
          loading: () => const SizedBox(height: 240, child: CinevaLoadingView(label: 'Chargement de la page d’accueil...')),
          error: (error, _) => CinevaStatusBanner(
            title: 'Impossible de charger l’accueil',
            message: error.toString(),
            tone: CinevaBannerTone.error,
          ),
          data: (sections) {
            final allContent = <AdminCatalogItemModel>[
              ...moviesAsync.value ?? const <AdminCatalogItemModel>[],
              ...seriesAsync.value ?? const <AdminCatalogItemModel>[],
            ];
            return Column(
              children: sections
                  .map(
                    (section) => Padding(
                      padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
                      child: CinevaGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(section.title, style: Theme.of(context).textTheme.titleLarge),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${section.sectionKey} • ${section.layoutType} • ordre ${section.sortOrder} • ${section.isEnabled ? 'Visible' : 'Masquée'}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Modifier ${section.title}',
                                  onPressed: () => _showHomeSectionEditor(context, ref, section: section, allContent: allContent),
                                  icon: const Icon(Icons.edit_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Supprimer ${section.title}',
                                  onPressed: () => _confirmDelete(
                                    context,
                                    title: 'Supprimer la section',
                                    message: 'Supprimer ${section.title} de la page d’accueil ?',
                                    onConfirm: () => _runCatalogAction(
                                      context,
                                      ref,
                                      () => ref.read(adminRepositoryProvider).deleteHomeSection(section.id),
                                      successMessage: 'Section supprimée.',
                                    ),
                                  ),
                                  icon: const Icon(Icons.delete_outline_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: CinevaSpacing.md),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: section.items
                                  .map((item) => Chip(label: Text('${item.title} (${item.contentType})')))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _CatalogItemCard extends StatelessWidget {
  const _CatalogItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    this.extraActions = const <Widget>[],
  });

  final AdminCatalogItemModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    return CinevaGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(item.title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '${item.contentType.toUpperCase()} • ${item.releaseYear ?? '—'} • ${item.directorName ?? 'Sans réalisateur'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                    ),
                  ],
                ),
              ),
              _StatusDot(label: item.isPublished ? 'Publié' : 'Masqué', color: item.isPublished ? CinevaColors.success : CinevaColors.warning),
              const SizedBox(width: 8),
              _StatusDot(label: item.isFeatured ? 'Mis en avant' : 'Standard', color: item.isFeatured ? CinevaColors.accentSoft : CinevaColors.surfaceRaised),
            ],
          ),
          const SizedBox(height: CinevaSpacing.md),
          Text(item.synopsis, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted)),
          const SizedBox(height: CinevaSpacing.lg),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_rounded), label: const Text('Modifier')),
              ...extraActions,
              OutlinedButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded), label: const Text('Supprimer')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(label),
      ),
    );
  }
}
