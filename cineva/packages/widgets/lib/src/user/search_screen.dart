import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../cineva_empty_state_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final controller = ref.read(searchControllerProvider.notifier);

    if (_controller.text != state.query) {
      _controller.value = _controller.value.copyWith(
        text: state.query,
        selection: TextSelection.collapsed(offset: state.query.length),
        composing: TextRange.empty,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(CinevaSpacing.lg),
      children: <Widget>[
        const CinevaPageHeader(
          title: 'Recherche',
          subtitle: 'Recherche instantanée dynamique sur titres, genres, acteurs et réalisateurs.',
        ),
        const SizedBox(height: CinevaSpacing.xl),
        CinevaTextField(
          controller: _controller,
          label: 'Rechercher',
          hint: 'Film, série, acteur, réalisateur ou genre',
          prefixIcon: Icons.search_rounded,
          textInputAction: TextInputAction.search,
          onChanged: controller.onQueryChanged,
          onSubmitted: (_) => controller.submitCurrentQuery(),
        ),
        const SizedBox(height: CinevaSpacing.md),
        _FilterBar(
          selected: state.filter,
          onSelected: controller.setFilter,
        ),
        const SizedBox(height: CinevaSpacing.xl),
        if (state.errorMessage != null) ...<Widget>[
          CinevaStatusBanner(
            title: 'Recherche indisponible',
            message: state.errorMessage!,
            tone: CinevaBannerTone.error,
          ),
          const SizedBox(height: CinevaSpacing.lg),
        ],
        if (state.isLoading) const SizedBox(height: 180, child: CinevaLoadingView(label: 'Analyse des contenus...')),
        if (!state.isLoading && state.isIdle) ...<Widget>[
          if (state.history.isNotEmpty) ...<Widget>[
            Row(
              children: <Widget>[
                const Expanded(child: CinevaSectionTitle(title: 'Historique récent')),
                TextButton(
                  onPressed: controller.clearHistory,
                  child: const Text('Effacer'),
                ),
              ],
            ),
            const SizedBox(height: CinevaSpacing.md),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: state.history
                  .map(
                    (item) => _HistoryChip(
                      label: item,
                      onTap: () => controller.useSuggestion(
                        SearchSuggestionModel(label: item, type: SearchSuggestionType.recent),
                      ),
                      onDelete: () => controller.removeHistoryItem(item),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: CinevaSpacing.xl),
          ],
          const CinevaSectionTitle(title: 'Suggestions intelligentes'),
          const SizedBox(height: CinevaSpacing.md),
          if (state.suggestions.isEmpty)
            const CinevaEmptyStateCard(
              title: 'Aucune suggestion disponible',
              subtitle: 'Le catalogue de démonstration ou Supabase alimentera automatiquement cette zone.',
              icon: Icons.lightbulb_outline_rounded,
            )
          else
            ...state.suggestions.map(
              (suggestion) => Padding(
                padding: const EdgeInsets.only(bottom: CinevaSpacing.sm),
                child: _SuggestionTile(
                  suggestion: suggestion,
                  onTap: () => controller.useSuggestion(suggestion),
                ),
              ),
            ),
        ],
        if (!state.isLoading && !state.isIdle) ...<Widget>[
          if (state.suggestions.isNotEmpty) ...<Widget>[
            const CinevaSectionTitle(title: 'Suggestions'),
            const SizedBox(height: CinevaSpacing.md),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: state.suggestions
                  .take(8)
                  .map(
                    (suggestion) => ActionChip(
                      label: Text(suggestion.label),
                      onPressed: () => controller.useSuggestion(suggestion),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: CinevaSpacing.xl),
          ],
          CinevaSectionTitle(
            title: 'Résultats',
            actionLabel: '${state.results.length} trouvé${state.results.length > 1 ? 's' : ''}',
          ),
          const SizedBox(height: CinevaSpacing.md),
          if (state.results.isEmpty)
            const CinevaEmptyStateCard(
              title: 'Aucun résultat',
              subtitle: 'Essayez un autre mot-clé, un autre genre ou retirez un filtre.',
              icon: Icons.search_off_rounded,
            )
          else
            ...state.results.map(
              (result) => Padding(
                padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
                child: _ResultTile(result: result),
              ),
            ),
        ],
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.onSelected,
  });

  final SearchFilter selected;
  final ValueChanged<SearchFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: SearchFilter.values
          .map(
            (filter) => ChoiceChip(
              label: Text(filter.label),
              selected: filter == selected,
              onSelected: (_) => onSelected(filter),
            ),
          )
          .toList(),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({
    required this.label,
    required this.onTap,
    required this.onDelete,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      avatar: const Icon(Icons.history_rounded, size: 18),
      onPressed: onTap,
      onDeleted: onDelete,
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.onTap,
  });

  final SearchSuggestionModel suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CinevaGlassCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CinevaRadii.medium),
        child: Padding(
          padding: EdgeInsets.zero,
          child: Row(
            children: <Widget>[
              Icon(_iconFor(suggestion.type), color: CinevaColors.accentSoft),
              const SizedBox(width: CinevaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(suggestion.label, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      _labelFor(suggestion.type),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.north_west_rounded),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(SearchSuggestionType type) {
    return switch (type) {
      SearchSuggestionType.title => Icons.movie_creation_outlined,
      SearchSuggestionType.actor => Icons.person_search_rounded,
      SearchSuggestionType.director => Icons.video_camera_back_outlined,
      SearchSuggestionType.genre => Icons.category_outlined,
      SearchSuggestionType.recent => Icons.history_rounded,
    };
  }

  String _labelFor(SearchSuggestionType type) {
    return switch (type) {
      SearchSuggestionType.title => 'Titre recommandé',
      SearchSuggestionType.actor => 'Acteur',
      SearchSuggestionType.director => 'Réalisateur',
      SearchSuggestionType.genre => 'Genre',
      SearchSuggestionType.recent => 'Historique récent',
    };
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final SearchResultModel result;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(CinevaRadii.medium),
      onTap: () => context.push('/content/${Uri.encodeComponent(result.id)}'),
      child: CinevaGlassCard(
        child: Row(
          children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CinevaRadii.small),
              gradient: const LinearGradient(
                colors: <Color>[CinevaColors.accent, CinevaColors.accentSoft],
              ),
            ),
            child: Icon(result.contentType == 'movie' ? Icons.local_movies_rounded : Icons.live_tv_rounded),
          ),
          const SizedBox(width: CinevaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(result.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  result.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted),
                ),
                if (result.matchLabel != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    result.matchLabel!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: CinevaColors.accentSoft),
                  ),
                ],
                if (result.description != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    result.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
            const SizedBox(width: CinevaSpacing.sm),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
