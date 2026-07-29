import 'package:equatable/equatable.dart';

class ContentTileModel extends Equatable {
  const ContentTileModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.contentType,
    this.imagePath,
    this.backdropPath,
    this.description,
    this.directorName,
    this.year,
    this.durationMinutes,
    this.ageRating,
    this.progressPercent,
    this.isFeatured = false,
    this.genres = const <String>[],
    this.castNames = const <String>[],
  });

  final String id;
  final String title;
  final String subtitle;
  final String badge;
  final String contentType;
  final String? imagePath;
  final String? backdropPath;
  final String? description;
  final String? directorName;
  final int? year;
  final int? durationMinutes;
  final String? ageRating;
  final double? progressPercent;
  final bool isFeatured;
  final List<String> genres;
  final List<String> castNames;

  ContentTileModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? badge,
    String? contentType,
    String? imagePath,
    String? backdropPath,
    String? description,
    String? directorName,
    int? year,
    int? durationMinutes,
    String? ageRating,
    double? progressPercent,
    bool? isFeatured,
    List<String>? genres,
    List<String>? castNames,
  }) {
    return ContentTileModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      badge: badge ?? this.badge,
      contentType: contentType ?? this.contentType,
      imagePath: imagePath ?? this.imagePath,
      backdropPath: backdropPath ?? this.backdropPath,
      description: description ?? this.description,
      directorName: directorName ?? this.directorName,
      year: year ?? this.year,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      ageRating: ageRating ?? this.ageRating,
      progressPercent: progressPercent ?? this.progressPercent,
      isFeatured: isFeatured ?? this.isFeatured,
      genres: genres ?? this.genres,
      castNames: castNames ?? this.castNames,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        title,
        subtitle,
        badge,
        contentType,
        imagePath,
        backdropPath,
        description,
        directorName,
        year,
        durationMinutes,
        ageRating,
        progressPercent,
        isFeatured,
        genres,
        castNames,
      ];
}
