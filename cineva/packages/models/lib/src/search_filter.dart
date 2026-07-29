import 'package:equatable/equatable.dart';

enum SearchFilter {
  all,
  movies,
  series,
  actors,
  directors,
  genres,
}

extension SearchFilterX on SearchFilter {
  String get label => switch (this) {
        SearchFilter.all => 'Tout',
        SearchFilter.movies => 'Films',
        SearchFilter.series => 'Séries',
        SearchFilter.actors => 'Acteurs',
        SearchFilter.directors => 'Réalisateurs',
        SearchFilter.genres => 'Genres',
      };
}

class SearchQuery extends Equatable {
  const SearchQuery({
    required this.text,
    this.filter = SearchFilter.all,
  });

  final String text;
  final SearchFilter filter;

  SearchQuery copyWith({
    String? text,
    SearchFilter? filter,
  }) {
    return SearchQuery(
      text: text ?? this.text,
      filter: filter ?? this.filter,
    );
  }

  @override
  List<Object?> get props => <Object?>[text, filter];
}
