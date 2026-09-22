import 'dart:async';

import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../search/search_controller.dart';

/// Recherche Cineva.
///
/// * champ sombre légèrement élevé, accent doré au focus ;
/// * tendances issues du catalogue réel (section `trending`) ;
/// * filtres : types (`SearchFilter`, branchés sur le repository) puis
///   genres/acteurs/réalisateurs issus des suggestions du catalogue ;
/// * résultats en lignes poster + titre + année + genre, apparition en
///   cascade bornée à ~38 ms par élément.
///
/// Le bouton microphone n'est pas affiché : aucune dépendance de
/// reconnaissance vocale n'existe dans le projet et rien n'est simulé.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    final SearchController controller = ref.read(searchControllerProvider.notifier);
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      unawaited(controller.onQueryChanged(''));
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 240), () {
      unawaited(controller.onQueryChanged(value));
    });
  }

  void _syncController(SearchState state) {
    if (_controller.text == state.query) return;
    _controller.value = _controller.value.copyWith(
      text: state.query,
      selection: TextSelection.collapsed(offset: state.query.length),
      composing: TextRange.empty,
    );
  }

  /// Table identifiant → tuile construite une seule fois à partir des
  /// sections déjà chargées (permet d'afficher les vraies affiches dans les
  /// résultats de recherche).
  Map<String, ContentTileModel> _tilesById() {
    final List<HomeSectionModel> sections =
        ref.watch(homeSectionsProvider).valueOrNull ?? const <HomeSectionModel>[];
    final Map<String, ContentTileModel> tiles = <String, ContentTileModel>{};
    for (final HomeSectionModel section in sections) {
      for (final ContentTileModel item in section.items) {
        tiles[item.id] = item;
      }
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    final SearchState state = ref.watch(searchControllerProvider);
    final SearchController controller = ref.read(searchControllerProvider.notifier);
    _syncController(state);

    final CinevaMetrics metrics = CinevaMetrics.of(context);
    final double bottom = CinevaBottomNavigation.clearance(context);

    return Stack(
      children: <Widget>[
        CustomScrollView(
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
            decelerationRate: ScrollDecelerationRate.fast,
          ),
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                metrics.gutter,
                MediaQuery.paddingOf(context).top + CinevaSpacing.xs,
                metrics.gutter,
                CinevaSpacing.md,
              ),
              sliver: SliverToBoxAdapter(
                child: CinevaScreenTitle(
                  title: 'Recherche',
                  padding: EdgeInsets.zero,
                  subtitle: state.isLoading ? 'Recherche en cours…' : null,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: metrics.gutter),
              sliver: SliverToBoxAdapter(
                child: CinevaSearchField(
                  controller: _controller,
                  onChanged: _handleChanged,
                  onSubmitted: (String value) {
                    _debounce?.cancel();
                    unawaited(controller.onQueryChanged(value));
                    unawaited(controller.submitCurrentQuery());
                  },
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: CinevaSpacing.lg)),
            if (state.isIdle)
              ..._idleSlivers(context, state, controller, metrics)
            else
              ..._resultSlivers(context, state, controller, metrics, _tilesById()),
            SliverToBoxAdapter(child: SizedBox(height: bottom)),
          ],
        ),
        if (state.isLoading && !state.isIdle)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 2,
            left: 0,
            right: 0,
            child: const _TopProgress(),
          ),
      ],
    );
  }

  List<Widget> _idleSlivers(
    BuildContext context,
    SearchState state,
    SearchController controller,
    CinevaMetrics metrics,
  ) {
    return <Widget>[
      const SliverToBoxAdapter(child: _TrendingRail()),
      SliverToBoxAdapter(child: SizedBox(height: CinevaSpacing.xxl)),
      SliverToBoxAdapter(
        child: _FiltersBlock(state: state, controller: controller, metrics: metrics),
      ),
      if (state.history.isNotEmpty) ...<Widget>[
        SliverToBoxAdapter(child: SizedBox(height: CinevaSpacing.xxl)),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: metrics.gutter),
          sliver: SliverToBoxAdapter(
            child: CinevaSectionHeader(
              title: 'Recherches récentes',
              actionLabel: 'Effacer',
              onAction: controller.clearHistory,
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: metrics.gutter),
          sliver: SliverToBoxAdapter(
            child: Wrap(
              spacing: CinevaSpacing.xs,
              runSpacing: CinevaSpacing.xs,
              children: state.history
                  .map(
                    (String entry) => CinevaChip(
                      label: entry,
                      icon: Icons.history_rounded,
                      dense: true,
                      onSelected: (_) => controller.useSuggestion(
                        SearchSuggestionModel(label: entry, type: SearchSuggestionType.recent),
                      ),
                      onDeleted: () => controller.removeHistoryItem(entry),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
      if (state.suggestions.isNotEmpty) ...<Widget>[
        SliverToBoxAdapter(child: SizedBox(height: CinevaSpacing.xxl)),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: metrics.gutter),
          sliver: SliverToBoxAdapter(
            child: const CinevaSectionHeader(title: 'Suggestions'),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: metrics.gutter - CinevaSpacing.md),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) => _SuggestionRow(
                suggestion: state.suggestions[index],
                onTap: () => controller.useSuggestion(state.suggestions[index]),
              ),
              childCount: state.suggestions.length > 8 ? 8 : state.suggestions.length,
            ),
          ),
        ),
      ],
      if (state.errorMessage != null)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            metrics.gutter,
            CinevaSpacing.xl,
            metrics.gutter,
            0,
          ),
          sliver: SliverToBoxAdapter(child: _SearchError(message: state.errorMessage!)),
        ),
    ];
  }

  List<Widget> _resultSlivers(
    BuildContext context,
    SearchState state,
    SearchController controller,
    CinevaMetrics metrics,
    Map<String, ContentTileModel> tilesById,
  ) {
    final List<SearchResultModel> results = state.results;

    return <Widget>[
      SliverToBoxAdapter(
        child: _FiltersBlock(state: state, controller: controller, metrics: metrics),
      ),
      SliverToBoxAdapter(child: SizedBox(height: CinevaSpacing.xl)),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: metrics.gutter),
        sliver: SliverToBoxAdapter(
          child: CinevaSectionHeader(
            title: results.isEmpty ? 'Aucun résultat' : 'Résultats',
            actionLabel: results.isEmpty
                ? null
                : '${results.length} titre${results.length > 1 ? 's' : ''}',
          ),
        ),
      ),
      if (results.isEmpty && !state.isLoading)
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: metrics.gutter),
          sliver: SliverToBoxAdapter(
            child: _NoResult(query: state.query),
          ),
        )
      else
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: metrics.gutter - CinevaSpacing.md),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) => _ResultRow(
                key: ValueKey<String>(results[index].id),
                result: results[index],
                tile: tilesById[results[index].id],
                index: index,
              ),
              childCount: results.length,
            ),
          ),
        ),
      if (state.errorMessage != null)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            metrics.gutter,
            CinevaSpacing.xl,
            metrics.gutter,
            0,
          ),
          sliver: SliverToBoxAdapter(child: _SearchError(message: state.errorMessage!)),
        ),
    ];
  }
}

/// Liseré de progression discret en haut de l'écran pendant la recherche.
class _TopProgress extends StatefulWidget {
  const _TopProgress();

  @override
  State<_TopProgress> createState() => _TopProgressState();
}

class _TopProgressState extends State<_TopProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        return Align(
          alignment: Alignment(t * 2 - 1, 0),
          child: FractionallySizedBox(
            widthFactor: 0.28,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(CinevaRadii.chip),
                gradient: LinearGradient(
                  colors: <Color>[
                    CinevaColors.gold.withOpacity(0),
                    CinevaColors.gold,
                    CinevaColors.gold.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// « Tendances » : petites affiches horizontales issues du catalogue réel.
class _TrendingRail extends ConsumerWidget {
  const _TrendingRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<HomeSectionModel>> sections = ref.watch(homeSectionsProvider);
    final List<HomeSectionModel> data = sections.valueOrNull ?? const <HomeSectionModel>[];
    final CinevaMetrics metrics = CinevaMetrics.of(context);

    HomeSectionModel? trending;
    for (final HomeSectionModel section in data) {
      if (section.key == 'trending' || section.key == 'popular_movies') {
        trending = section;
        break;
      }
    }
    if (trending == null) {
      for (final HomeSectionModel section in data) {
        if (!section.isHero && section.items.isNotEmpty) {
          trending = section;
          break;
        }
      }
    }

    final List<ContentTileModel> items = trending?.items ?? const <ContentTileModel>[];
    if (items.isEmpty) return const SizedBox.shrink();

    final double posterWidth = metrics.posterWidth * 0.86;

    return CinevaRail(
      title: trending?.title ?? 'Tendances',
      itemHeight: (posterWidth * 1.5) + 46,
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final ContentTileModel item = items[index];
        return CinevaMovieCard(
          item: item,
          width: posterWidth,
          onTap: () => context.push('/content/${Uri.encodeComponent(item.id)}'),
        );
      },
    );
  }
}

/// Bloc « Filtres » : types réels + genres/acteurs issus du catalogue.
class _FiltersBlock extends ConsumerWidget {
  const _FiltersBlock({
    required this.state,
    required this.controller,
    required this.metrics,
  });

  final SearchState state;
  final SearchController controller;
  final CinevaMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> genres = _genreSuggestions(ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: metrics.gutter),
          child: const CinevaSectionHeader(title: 'Filtres'),
        ),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast),
            padding: EdgeInsets.symmetric(horizontal: metrics.gutter),
            itemCount: SearchFilter.values.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: CinevaSpacing.xs),
            itemBuilder: (BuildContext context, int index) {
              final SearchFilter filter = SearchFilter.values[index];
              return CinevaChip(
                label: filter.label,
                selected: state.filter == filter,
                onSelected: (_) => controller.setFilter(filter),
              );
            },
          ),
        ),
        if (genres.isNotEmpty) ...<Widget>[
          const SizedBox(height: CinevaSpacing.sm),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              physics: const BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast),
              padding: EdgeInsets.symmetric(horizontal: metrics.gutter),
              itemCount: genres.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(width: CinevaSpacing.xs),
              itemBuilder: (BuildContext context, int index) {
                final String genre = genres[index];
                return CinevaChip(
                  label: genre,
                  dense: true,
                  onSelected: (_) => controller.useSuggestion(
                    SearchSuggestionModel(label: genre, type: SearchSuggestionType.genre),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// Genres réellement présents dans le catalogue chargé.
  List<String> _genreSuggestions(WidgetRef ref) {
    final List<SearchSuggestionModel> suggestions = state.suggestions
        .where((SearchSuggestionModel suggestion) => suggestion.type == SearchSuggestionType.genre)
        .toList();
    if (suggestions.isNotEmpty) {
      return suggestions.map((SearchSuggestionModel suggestion) => suggestion.label).take(10).toList();
    }

    final List<HomeSectionModel> sections =
        ref.watch(homeSectionsProvider).valueOrNull ?? const <HomeSectionModel>[];
    final Set<String> genres = <String>{};
    for (final HomeSectionModel section in sections) {
      for (final ContentTileModel item in section.items) {
        genres.addAll(item.genres);
      }
    }
    final List<String> sorted = genres.toList()..sort();
    return sorted.take(10).toList();
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestion, required this.onTap});

  final SearchSuggestionModel suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (suggestion.type) {
      SearchSuggestionType.title => Icons.movie_outlined,
      SearchSuggestionType.actor => Icons.person_outline_rounded,
      SearchSuggestionType.director => Icons.videocam_outlined,
      SearchSuggestionType.genre => Icons.category_outlined,
      SearchSuggestionType.recent => Icons.history_rounded,
    };
    final String label = switch (suggestion.type) {
      SearchSuggestionType.title => 'Titre',
      SearchSuggestionType.actor => 'Acteur',
      SearchSuggestionType.director => 'Réalisateur',
      SearchSuggestionType.genre => 'Genre',
      SearchSuggestionType.recent => 'Recherche récente',
    };

    return CinevaListTile(
      title: suggestion.label,
      subtitle: label,
      icon: icon,
      onTap: onTap,
    );
  }
}

/// Ligne de résultat : poster, titre, année, genre.
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    super.key,
    required this.result,
    required this.index,
    this.tile,
  });

  final SearchResultModel result;
  final ContentTileModel? tile;
  final int index;

  @override
  Widget build(BuildContext context) {
    final List<String> genres = result.genres.take(2).toList();
    final String meta = <String>[
      if (result.year != null) '${result.year}',
      if (genres.isNotEmpty) genres.join(' · '),
      result.subtitle,
    ].where((String value) => value.trim().isNotEmpty).join(' · ');

    return CinevaReveal(
      delay: CinevaMotion.listStagger * (index > 10 ? 10 : index),
      offsetY: 10,
      child: CinevaPressable(
        pressedScale: 0.985,
        onTap: () => context.push('/content/${Uri.encodeComponent(result.id)}'),
        semanticLabel: '${CinevaContentLabels.type(result.contentType)} ${result.title}',
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CinevaSpacing.md,
            vertical: CinevaSpacing.xs + 2,
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 54,
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(CinevaRadii.small),
                    child: tile == null
                        ? CinevaArtworkImage(path: null, seed: result.id)
                        : CinevaArtworkImage.forTile(tile),
                  ),
                ),
              ),
              const SizedBox(width: CinevaSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      result.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CinevaTypography.cardTitle.copyWith(fontSize: 14.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CinevaTypography.meta.copyWith(fontSize: 11.5),
                    ),
                    if (result.matchLabel != null && result.matchLabel!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 5),
                      Text(
                        result.matchLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CinevaTypography.overline.copyWith(
                          fontSize: 9.5,
                          color: CinevaColors.gold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: CinevaColors.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _NoResult extends StatelessWidget {
  const _NoResult({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: CinevaSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Aucun titre ne correspond à « $query ».',
            style: CinevaTypography.body,
          ),
          const SizedBox(height: CinevaSpacing.sm),
          Text(
            'Essayez un autre mot-clé, un genre, ou retirez un filtre.',
            style: CinevaTypography.bodyCompact,
          ),
        ],
      ),
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CinevaSpacing.md),
      decoration: BoxDecoration(
        color: CinevaColors.danger.withOpacity(0.09),
        borderRadius: BorderRadius.circular(CinevaRadii.medium),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline_rounded, size: 18, color: CinevaColors.danger),
          const SizedBox(width: CinevaSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: CinevaTypography.bodyCompact.copyWith(color: CinevaColors.textHigh),
            ),
          ),
        ],
      ),
    );
  }
}
