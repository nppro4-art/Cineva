import 'package:equatable/equatable.dart';

class SearchResultModel extends Equatable {
  const SearchResultModel({
    required this.id,
    required this.title,
    required this.contentType,
    required this.subtitle,
    this.description,
    this.directorName,
    this.year,
    this.genres = const <String>[],
    this.matchLabel,
  });

  final String id;
  final String title;
  final String contentType;
  final String subtitle;
  final String? description;
  final String? directorName;
  final int? year;
  final List<String> genres;
  final String? matchLabel;

  @override
  List<Object?> get props => <Object?>[
        id,
        title,
        contentType,
        subtitle,
        description,
        directorName,
        year,
        genres,
        matchLabel,
      ];
}
