import 'package:equatable/equatable.dart';

import 'skip_segment_model.dart';

class AdminCatalogItemModel extends Equatable {
  const AdminCatalogItemModel({
    required this.id,
    required this.contentType,
    required this.title,
    required this.synopsis,
    required this.genres,
    required this.audioLanguages,
    required this.subtitleLanguages,
    required this.castNames,
    required this.categoryIds,
    required this.isFeatured,
    required this.isPublished,
    this.originalTitle,
    this.posterPath,
    this.backdropPath,
    this.logoPath,
    this.trailerPath,
    this.videoPath,
    this.releaseYear,
    this.durationMinutes,
    this.ageRating,
    this.directorName,
    this.countries = const <String>[],
    this.rating,
    this.pilotEpisodeId,
    this.introEndSeconds,
    this.creditsStartSeconds,
    this.skipSegments = const <SkipSegment>[],
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String contentType;
  final String title;
  final String synopsis;
  final List<String> genres;
  final List<String> audioLanguages;
  final List<String> subtitleLanguages;
  final List<String> castNames;
  final List<String> categoryIds;
  final bool isFeatured;
  final bool isPublished;
  final String? originalTitle;
  final String? posterPath;
  final String? backdropPath;
  final String? logoPath;
  final String? trailerPath;
  final String? videoPath;
  final int? releaseYear;
  final int? durationMinutes;
  final String? ageRating;
  final String? directorName;
  final List<String> countries;
  final double? rating;
  final String? pilotEpisodeId;

  /// Fin de l'intro, en secondes (film).
  final int? introEndSeconds;

  /// Début du générique, en secondes (film).
  final int? creditsStartSeconds;

  /// Segments à passer pendant la lecture (film).
  final List<SkipSegment> skipSegments;

  final Map<String, dynamic> metadata;

  bool get isMovie => contentType == 'movie';
  bool get isSeries => contentType == 'series';

  AdminCatalogItemModel copyWith({
    String? id,
    String? contentType,
    String? title,
    String? synopsis,
    List<String>? genres,
    List<String>? audioLanguages,
    List<String>? subtitleLanguages,
    List<String>? castNames,
    List<String>? categoryIds,
    bool? isFeatured,
    bool? isPublished,
    String? originalTitle,
    String? posterPath,
    String? backdropPath,
    String? logoPath,
    String? trailerPath,
    String? videoPath,
    int? releaseYear,
    int? durationMinutes,
    String? ageRating,
    String? directorName,
    List<String>? countries,
    double? rating,
    String? pilotEpisodeId,
    int? introEndSeconds,
    int? creditsStartSeconds,
    List<SkipSegment>? skipSegments,
    Map<String, dynamic>? metadata,
  }) {
    return AdminCatalogItemModel(
      id: id ?? this.id,
      contentType: contentType ?? this.contentType,
      title: title ?? this.title,
      synopsis: synopsis ?? this.synopsis,
      genres: genres ?? this.genres,
      audioLanguages: audioLanguages ?? this.audioLanguages,
      subtitleLanguages: subtitleLanguages ?? this.subtitleLanguages,
      castNames: castNames ?? this.castNames,
      categoryIds: categoryIds ?? this.categoryIds,
      isFeatured: isFeatured ?? this.isFeatured,
      isPublished: isPublished ?? this.isPublished,
      originalTitle: originalTitle ?? this.originalTitle,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      logoPath: logoPath ?? this.logoPath,
      trailerPath: trailerPath ?? this.trailerPath,
      videoPath: videoPath ?? this.videoPath,
      releaseYear: releaseYear ?? this.releaseYear,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      ageRating: ageRating ?? this.ageRating,
      directorName: directorName ?? this.directorName,
      countries: countries ?? this.countries,
      rating: rating ?? this.rating,
      pilotEpisodeId: pilotEpisodeId ?? this.pilotEpisodeId,
      introEndSeconds: introEndSeconds ?? this.introEndSeconds,
      creditsStartSeconds: creditsStartSeconds ?? this.creditsStartSeconds,
      skipSegments: skipSegments ?? this.skipSegments,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        contentType,
        title,
        synopsis,
        genres,
        audioLanguages,
        subtitleLanguages,
        castNames,
        categoryIds,
        isFeatured,
        isPublished,
        originalTitle,
        posterPath,
        backdropPath,
        logoPath,
        trailerPath,
        videoPath,
        releaseYear,
        durationMinutes,
        ageRating,
        directorName,
        countries,
        rating,
        pilotEpisodeId,
        introEndSeconds,
        creditsStartSeconds,
        skipSegments,
        metadata,
      ];
}
