import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchState extends Equatable {
  const SearchState({
    this.query = '',
    this.filter = SearchFilter.all,
    this.history = const <String>[],
    this.suggestions = const <SearchSuggestionModel>[],
    this.results = const <SearchResultModel>[],
    this.isLoading = false,
    this.errorMessage,
  });

  final String query;
  final SearchFilter filter;
  final List<String> history;
  final List<SearchSuggestionModel> suggestions;
  final List<SearchResultModel> results;
  final bool isLoading;
  final String? errorMessage;

  bool get isIdle => query.trim().isEmpty;

  SearchState copyWith({
    String? query,
    SearchFilter? filter,
    List<String>? history,
    List<SearchSuggestionModel>? suggestions,
    List<SearchResultModel>? results,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      filter: filter ?? this.filter,
      history: history ?? this.history,
      suggestions: suggestions ?? this.suggestions,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        query,
        filter,
        history,
        suggestions,
        results,
        isLoading,
        errorMessage,
      ];
}

class SearchController extends StateNotifier<SearchState> {
  SearchController({
    required CatalogRepository catalogRepository,
    required LocalPreferencesService localPreferencesService,
  })  : _catalogRepository = catalogRepository,
        _localPreferencesService = localPreferencesService,
        super(const SearchState()) {
    initialize();
  }

  final CatalogRepository _catalogRepository;
  final LocalPreferencesService _localPreferencesService;

  Future<void> initialize() async {
    try {
      final history = await _localPreferencesService.readSearchHistory();
      final suggestions = await _catalogRepository.fetchSearchSuggestions();
      state = state.copyWith(
        history: history,
        suggestions: suggestions,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> onQueryChanged(String value) async {
    final trimmed = value.trimLeft();
    state = state.copyWith(query: trimmed, isLoading: true, clearError: true);

    if (trimmed.trim().isEmpty) {
      final suggestions = await _catalogRepository.fetchSearchSuggestions();
      final history = await _localPreferencesService.readSearchHistory();
      state = state.copyWith(
        query: '',
        isLoading: false,
        results: const <SearchResultModel>[],
        suggestions: suggestions,
        history: history,
        clearError: true,
      );
      return;
    }

    await _performSearch(trimmed);
  }

  Future<void> setFilter(SearchFilter filter) async {
    state = state.copyWith(filter: filter, isLoading: true, clearError: true);
    if (state.query.trim().isEmpty) {
      final suggestions = await _catalogRepository.fetchSearchSuggestions(filter: filter);
      state = state.copyWith(isLoading: false, suggestions: suggestions, results: const <SearchResultModel>[]);
      return;
    }
    await _performSearch(state.query);
  }

  Future<void> useSuggestion(SearchSuggestionModel suggestion) async {
    state = state.copyWith(query: suggestion.label, isLoading: true, clearError: true);
    await _saveHistoryEntry(suggestion.label);
    await _performSearch(suggestion.label);
  }

  Future<void> submitCurrentQuery() async {
    final query = state.query.trim();
    if (query.isEmpty) return;
    await _saveHistoryEntry(query);
    await _performSearch(query);
  }

  Future<void> removeHistoryItem(String value) async {
    final history = List<String>.from(state.history)..remove(value);
    await _localPreferencesService.saveSearchHistory(history);
    state = state.copyWith(history: history);
  }

  Future<void> clearHistory() async {
    await _localPreferencesService.clearSearchHistory();
    state = state.copyWith(history: const <String>[]);
  }

  Future<void> _performSearch(String query) async {
    try {
      final results = await _catalogRepository.search(query, filter: state.filter);
      final suggestions = await _catalogRepository.fetchSearchSuggestions(query: query, filter: state.filter);
      state = state.copyWith(
        query: query,
        results: results,
        suggestions: suggestions,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
        results: const <SearchResultModel>[],
      );
    }
  }

  Future<void> _saveHistoryEntry(String value) async {
    final history = List<String>.from(state.history);
    history.remove(value);
    history.insert(0, value);
    final next = history.take(8).toList();
    await _localPreferencesService.saveSearchHistory(next);
    state = state.copyWith(history: next);
  }
}
