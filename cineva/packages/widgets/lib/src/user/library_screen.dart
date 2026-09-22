import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../library/library_controller.dart';

part 'library_screen_sections.dart';

/// Onglets de la bibliothèque.
enum LibraryTab { list, resume }

/// Bibliothèque Cineva : « Ma liste » et « Reprendre ».
///
/// Les deux onglets lisent l'état réel de [LibraryController] (favoris
/// synchronisés avec le dépôt, progressions suivies par le lecteur). Aucune
/// donnée simulée : les états vides renvoient vers le catalogue.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, this.initialTab = LibraryTab.list});

  final LibraryTab initialTab;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibraryTab _tab = LibraryTab.list;
  bool _moviesOnly = false;
  bool _seriesOnly = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final LibraryState library = ref.watch(libraryControllerProvider);
    final CinevaMetrics metrics = CinevaMetrics.of(context);
    final List<ContentTileModel> saved = _favoriteTiles(library);
    final List<ContentTileModel> favorites = _filtered(saved);
    final List<PlaybackProgressModel> resume =
        _inProgress(library.continueWatching);

    return Scaffold(
      backgroundColor: CinevaColors.ink,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
          decelerationRate: ScrollDecelerationRate.fast,
        ),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: SizedBox(
              height: metrics.topInset + CinevaSpacing.xxxl,
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: metrics.gutter),
            sliver: SliverToBoxAdapter(
              child: CinevaScreenTitle(
                title: 'Bibliothèque',
                padding: EdgeInsets.zero,
                subtitle: _subtitle(library, saved.length),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                left: metrics.gutter,
                right: metrics.gutter,
                top: CinevaSpacing.md,
              ),
              child: LibraryTabs(
                tab: _tab,
                listCount: saved.length,
                resumeCount: library.continueWatching.length,
                onChanged: (LibraryTab value) => setState(() => _tab = value),
              ),
            ),
          ),
          ..._tabSlivers(context, library, saved, favorites, resume, metrics),
          SliverToBoxAdapter(
            child: SizedBox(
              height: CinevaBottomNavigation.clearance(
                context,
                extra: CinevaSpacing.xxl,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Corps de l'écran selon l'onglet actif.
  List<Widget> _tabSlivers(
    BuildContext context,
    LibraryState library,
    List<ContentTileModel> saved,
    List<ContentTileModel> favorites,
    List<PlaybackProgressModel> resume,
    CinevaMetrics metrics,
  ) {
    if (_tab == LibraryTab.resume) {
      if (resume.isEmpty) {
        return <Widget>[
          _emptySliver(
            metrics,
            'Rien à reprendre',
            'Vos lectures en cours apparaîtront ici, avec la position exacte.',
          ),
        ];
      }
      return <Widget>[_resumeSliver(context, resume, metrics)];
    }

    if (saved.isEmpty) {
      return <Widget>[_emptySliver(metrics, _emptyTitle, _emptyMessage)];
    }

    final List<Widget> slivers = <Widget>[
      SliverPadding(
        padding: EdgeInsets.only(left: metrics.gutter, top: CinevaSpacing.lg),
        sliver: SliverToBoxAdapter(
          child: LibraryTypeFilters(
            moviesOnly: _moviesOnly,
            seriesOnly: _seriesOnly,
            onMovies: () => setState(() {
              _moviesOnly = !_moviesOnly;
              _seriesOnly = false;
            }),
            onSeries: () => setState(() {
              _seriesOnly = !_seriesOnly;
              _moviesOnly = false;
            }),
          ),
        ),
      ),
    ];

    if (favorites.isEmpty) {
      slivers.add(
        _emptySliver(
          metrics,
          _emptyTitle,
          'Retirez ce filtre ou ajoutez des titres depuis leur fiche.',
        ),
      );
    } else {
      slivers.add(_gridSliver(context, favorites, metrics));
    }

    if (library.continueWatching.isNotEmpty) {
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            metrics.gutter,
            CinevaSpacing.xxl,
            metrics.gutter,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: ResumeHintCard(
              count: library.continueWatching.length,
              onTap: () => setState(() => _tab = LibraryTab.resume),
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _emptySliver(
    CinevaMetrics metrics,
    String title,
    String message,
  ) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        metrics.gutter,
        CinevaSpacing.xxl,
        metrics.gutter,
        0,
      ),
      sliver: SliverToBoxAdapter(
        child: LibraryEmptyState(
          title: title,
          message: message,
          actionLabel: 'Parcourir le catalogue',
          onAction: () => context.go('/home'),
        ),
      ),
    );
  }

  Widget _gridSliver(
    BuildContext context,
    List<ContentTileModel> favorites,
    CinevaMetrics metrics,
  ) {
    final int columns = metrics.gridColumns.clamp(2, 4);
    final double spacing = CinevaSpacing.railGap;
    final double available =
        metrics.width - (metrics.gutter * 2) - ((columns - 1) * spacing);
    final double itemWidth = available / columns;
    final double itemHeight = (itemWidth * 1.5) + 46;

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(metrics.gutter, CinevaSpacing.lg, metrics.gutter, 0),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: spacing,
          mainAxisSpacing: CinevaSpacing.lg,
          childAspectRatio: itemWidth / itemHeight,
        ),
        delegate: SliverChildBuilderDelegate(
          childCount: favorites.length,
          (BuildContext context, int index) {
            final ContentTileModel item = favorites[index];
            return CinevaReveal(
              delay: CinevaMotion.listStagger * (index > 11 ? 11 : index),
              offsetY: 12,
              child: CinevaMovieCard(
                item: item,
                width: itemWidth,
                onTap: () =>
                    context.push('/content/${Uri.encodeComponent(item.id)}'),
                onLongPress: () => _showItemActions(item),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _resumeSliver(
    BuildContext context,
    List<PlaybackProgressModel> resume,
    CinevaMetrics metrics,
  ) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(metrics.gutter, CinevaSpacing.lg, metrics.gutter, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          childCount: resume.length,
          (BuildContext context, int index) {
            final PlaybackProgressModel item = resume[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
              child: CinevaReveal(
                delay: CinevaMotion.listStagger * (index > 11 ? 11 : index),
                offsetY: 12,
                child: ResumeRow(
                  progress: item,
                  onPlay: () =>
                      context.push('/player/${Uri.encodeComponent(item.contentId)}'),
                  onTap: () => context
                      .push('/content/${Uri.encodeComponent(item.content.id)}'),
                  onLongPress: () => _showProgressActions(item),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _subtitle(LibraryState library, int count) {
    final String label = switch (count) {
      0 => 'Rien de sauvegardé pour l’instant',
      1 => '1 titre dans Ma liste',
      _ => '$count titres dans Ma liste',
    };
    final int resumeCount = _inProgress(library.continueWatching).length;
    return resumeCount == 0
        ? label
        : '$label · $resumeCount à reprendre';
  }

  /// Résout les favoris en tuiles réelles.
  ///
  /// [LibraryController] ne conserve que les identifiants synchronisés avec le
  /// dépôt (`favoriteIds`) : les tuiles sont reprises du catalogue déjà chargé
  /// (sections d'accueil), complété par les lectures en cours et les
  /// téléchargements, qui embarquent leur [ContentTileModel]. Aucune donnée
  /// n'est inventée — un favori absent du catalogue chargé n'est simplement pas
  /// affichable tant que sa tuile n'a pas été vue.
  List<ContentTileModel> _favoriteTiles(LibraryState library) {
    if (library.favoriteIds.isEmpty) return const <ContentTileModel>[];

    final Map<String, ContentTileModel> tiles = <String, ContentTileModel>{};
    final List<HomeSectionModel> sections =
        ref.watch(homeSectionsProvider).valueOrNull ?? const <HomeSectionModel>[];
    for (final HomeSectionModel section in sections) {
      for (final ContentTileModel item in section.items) {
        tiles[item.id] ??= item;
      }
    }
    for (final PlaybackProgressModel progress in library.continueWatching) {
      tiles[progress.content.id] ??= progress.content;
    }
    for (final DownloadItemModel download in library.downloads) {
      tiles[download.content.id] ??= download.content;
    }

    return library.favoriteIds
        .map((String id) => tiles[id])
        .whereType<ContentTileModel>()
        .toList();
  }

  List<ContentTileModel> _filtered(List<ContentTileModel> favorites) {
    return favorites.where((ContentTileModel item) {
      if (_moviesOnly) return item.contentType == 'movie';
      if (_seriesOnly) return item.contentType == 'series';
      return true;
    }).toList();
  }

  List<PlaybackProgressModel> _inProgress(List<PlaybackProgressModel> items) {
    return items.where((PlaybackProgressModel item) => !item.isCompleted).toList();
  }

  String get _emptyTitle {
    if (_moviesOnly) return 'Aucun film dans Ma liste';
    if (_seriesOnly) return 'Aucune série dans Ma liste';
    return 'Ma liste est vide';
  }

  String get _emptyMessage =>
      'Ajoutez des films et des séries depuis leur fiche : ils seront ici, sur tous vos appareils.';

  // ----------------------------------------------------------------- actions
  Future<void> _showItemActions(ContentTileModel item) async {
    final bool isFavorite = ref.read(libraryControllerProvider).isFavorite(item.id);

    await showCinevaSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) => CinevaSheetContainer(
        title: item.title,
        subtitle: CinevaContentLabels.type(item.contentType),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CinevaSheetAction(
                icon: Icons.play_arrow_rounded,
                label: 'Regarder',
                tone: CinevaButtonTone.gold,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/player/${Uri.encodeComponent(item.id)}');
                },
              ),
              CinevaSheetAction(
                icon: Icons.info_outline_rounded,
                label: 'Voir la fiche',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/content/${Uri.encodeComponent(item.id)}');
                },
              ),
              CinevaSheetAction(
                icon: isFavorite ? Icons.check_rounded : Icons.add_rounded,
                label: isFavorite ? 'Retirer de Ma liste' : 'Ajouter à Ma liste',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await ref
                      .read(libraryControllerProvider.notifier)
                      .toggleFavorite(item);
                  _notify(isFavorite ? 'Retiré de Ma liste' : 'Ajouté à Ma liste');
                },
              ),
              const SizedBox(height: CinevaSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showProgressActions(PlaybackProgressModel item) async {
    await showCinevaSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) => CinevaSheetContainer(
        title: item.content.title,
        subtitle: CinevaContentLabels.type(item.contentType),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CinevaSheetAction(
                icon: Icons.play_arrow_rounded,
                label: 'Reprendre la lecture',
                tone: CinevaButtonTone.gold,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/player/${Uri.encodeComponent(item.contentId)}');
                },
              ),
              CinevaSheetAction(
                icon: Icons.info_outline_rounded,
                label: 'Voir la fiche',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/content/${Uri.encodeComponent(item.content.id)}');
                },
              ),
              CinevaSheetAction(
                icon: Icons.done_all_rounded,
                label: 'Marquer comme terminé',
                subtitle: 'Retire le titre de la liste « Reprendre »',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  if (item.durationSeconds <= 0) return;
                  await ref.read(libraryControllerProvider.notifier).saveProgress(
                        content: item.content,
                        positionSeconds: item.durationSeconds,
                        durationSeconds: item.durationSeconds,
                      );
                  _notify('Marqué comme terminé');
                },
              ),
              const SizedBox(height: CinevaSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1800),
          content: Text(message),
        ),
      );
  }
}
