import 'package:cineva_models/cineva_models.dart';

abstract final class CatalogSearchSupport {
  static List<SearchSuggestionModel> defaultSuggestions(List<ContentTileModel> contents) {
    final suggestions = <SearchSuggestionModel>[];
    final seen = <String>{};

    void push(String value, SearchSuggestionType type) {
      final key = '${type.name}:$value';
      if (value.isEmpty || seen.contains(key)) return;
      seen.add(key);
      suggestions.add(SearchSuggestionModel(label: value, type: type));
    }

    for (final content in contents.where((content) => content.isFeatured).take(5)) {
      push(content.title, SearchSuggestionType.title);
    }
    for (final content in contents.take(12)) {
      if (content.directorName != null) push(content.directorName!, SearchSuggestionType.director);
      for (final genre in content.genres.take(1)) {
        push(genre, SearchSuggestionType.genre);
      }
      for (final actor in content.castNames.take(1)) {
        push(actor, SearchSuggestionType.actor);
      }
      if (suggestions.length >= 10) break;
    }
    return suggestions;
  }

  static List<SearchSuggestionModel> buildSuggestions({
    required List<ContentTileModel> contents,
    required String query,
    required SearchFilter filter,
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return defaultSuggestions(contents);

    final seen = <String>{};
    final suggestions = <SearchSuggestionModel>[];

    void push(String value, SearchSuggestionType type) {
      final key = '${type.name}:$value';
      if (value.isEmpty || seen.contains(key)) return;
      seen.add(key);
      suggestions.add(SearchSuggestionModel(label: value, type: type));
    }

    for (final content in contents) {
      if ((filter == SearchFilter.all || filter == SearchFilter.movies || filter == SearchFilter.series) &&
          matchesByText(content.title, normalized) &&
          filterAllowsContentType(content, filter)) {
        push(content.title, SearchSuggestionType.title);
      }
      if ((filter == SearchFilter.all || filter == SearchFilter.directors) &&
          matchesByText(content.directorName ?? '', normalized)) {
        push(content.directorName!, SearchSuggestionType.director);
      }
      if (filter == SearchFilter.all || filter == SearchFilter.actors) {
        for (final actor in content.castNames) {
          if (matchesByText(actor, normalized)) push(actor, SearchSuggestionType.actor);
        }
      }
      if (filter == SearchFilter.all || filter == SearchFilter.genres) {
        for (final genre in content.genres) {
          if (matchesByText(genre, normalized)) push(genre, SearchSuggestionType.genre);
        }
      }
      if (suggestions.length >= 12) break;
    }

    return suggestions;
  }

  static SearchResultModel toSearchResult(ContentTileModel content, String query, SearchFilter filter) {
    return SearchResultModel(
      id: content.id,
      title: content.title,
      contentType: content.contentType,
      subtitle: '${content.contentType == 'movie' ? 'Film' : 'Série'} • ${content.year ?? '—'}',
      description: content.description,
      directorName: content.directorName,
      year: content.year,
      genres: content.genres,
      matchLabel: matchLabel(content, query, filter),
    );
  }

  static String? matchLabel(ContentTileModel content, String query, SearchFilter filter) {
    if (filter == SearchFilter.directors && content.directorName != null) {
      return 'Réalisateur • ${content.directorName}';
    }
    if (filter == SearchFilter.actors) {
      final actor = _firstMatching(content.castNames, query);
      if (actor != null) return 'Acteur • $actor';
    }
    if (filter == SearchFilter.genres) {
      final genre = _firstMatching(content.genres, query);
      if (genre != null) return 'Genre • $genre';
    }
    if (content.directorName != null && matchesByText(content.directorName!, query)) {
      return 'Réalisateur • ${content.directorName}';
    }
    final actor = _firstMatching(content.castNames, query);
    if (actor != null) return 'Acteur • $actor';
    final genre = _firstMatching(content.genres, query);
    if (genre != null) return 'Genre • $genre';
    return content.badge;
  }

  static bool matchesContent(ContentTileModel content, String query, SearchFilter filter) {
    final titleMatch = matchesByText(content.title, query);
    final descriptionMatch = matchesByText(content.description ?? '', query);
    final directorMatch = matchesByText(content.directorName ?? '', query);
    final actorMatch = content.castNames.any((actor) => matchesByText(actor, query));
    final genreMatch = content.genres.any((genre) => matchesByText(genre, query));
    return switch (filter) {
      SearchFilter.all => titleMatch || descriptionMatch || directorMatch || actorMatch || genreMatch,
      SearchFilter.movies => content.contentType == 'movie' && (titleMatch || descriptionMatch || directorMatch || actorMatch || genreMatch),
      SearchFilter.series => content.contentType == 'series' && (titleMatch || descriptionMatch || directorMatch || actorMatch || genreMatch),
      SearchFilter.actors => actorMatch,
      SearchFilter.directors => directorMatch,
      SearchFilter.genres => genreMatch,
    };
  }

  static bool filterAllowsContentType(ContentTileModel content, SearchFilter filter) {
    return switch (filter) {
      SearchFilter.movies => content.contentType == 'movie',
      SearchFilter.series => content.contentType == 'series',
      _ => true,
    };
  }

  static bool matchesByText(String value, String query) => value.toLowerCase().contains(query);

  static String? _firstMatching(Iterable<String> values, String query) {
    for (final value in values) {
      if (matchesByText(value, query)) {
        return value;
      }
    }
    return null;
  }
}
