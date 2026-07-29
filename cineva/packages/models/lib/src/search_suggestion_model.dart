import 'package:equatable/equatable.dart';

enum SearchSuggestionType {
  title,
  actor,
  director,
  genre,
  recent,
}

class SearchSuggestionModel extends Equatable {
  const SearchSuggestionModel({
    required this.label,
    required this.type,
  });

  final String label;
  final SearchSuggestionType type;

  @override
  List<Object?> get props => <Object?>[label, type];
}
