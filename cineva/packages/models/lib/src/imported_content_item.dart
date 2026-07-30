import 'package:equatable/equatable.dart';

import 'admin_catalog_item_model.dart';

/// Élément extrait d'un site web par la Edge Function `import-from-url`.
class ImportedContentItem extends Equatable {
  const ImportedContentItem({
    required this.contentType,
    required this.title,
    this.originalTitle,
    this.synopsis,
    this.posterPath,
    this.backdropPath,
    this.releaseYear,
    this.durationMinutes,
    this.ageRating,
    this.directorName,
    this.genres = const <String>[],
    this.castNames = const <String>[],
    this.countries = const <String>[],
    this.audioLanguages = const <String>[],
    this.subtitleLanguages = const <String>[],
    this.quality,
    this.sourceUrl,
    this.rating,
  });

  final String contentType; // 'movie' | 'series'
  final String title;
  final String? originalTitle;
  final String? synopsis;
  final String? posterPath;
  final String? backdropPath;
  final int? releaseYear;
  final int? durationMinutes;
  final String? ageRating;
  final String? directorName;
  final List<String> genres;
  final List<String> castNames;
  final List<String> countries;
  final List<String> audioLanguages;
  final List<String> subtitleLanguages;
  final String? quality;
  final String? sourceUrl;
  final double? rating;

  /// Convertit en [AdminCatalogItemModel] prêt à être sauvegardé.
  /// L'id est volontairement vide : le repository `saveMovie`/`saveSeries`
  /// omet l'id, laissant Postgres générer le uuid.
  AdminCatalogItemModel toAdminCatalogItemModel() => AdminCatalogItemModel(
        id: '',
        contentType: contentType,
        title: title,
        synopsis: synopsis ?? '',
        genres: genres,
        audioLanguages: audioLanguages,
        subtitleLanguages: subtitleLanguages,
        castNames: castNames,
        categoryIds: const <String>[],
        isFeatured: false,
        isPublished: true,
        originalTitle: originalTitle,
        posterPath: posterPath,
        backdropPath: backdropPath,
        releaseYear: releaseYear,
        durationMinutes: durationMinutes,
        ageRating: ageRating,
        directorName: directorName,
        countries: countries,
        rating: rating,
        metadata: <String, dynamic>{
          if (quality != null) 'quality': quality,
          if (sourceUrl != null) 'sourceUrl': sourceUrl,
        },
      );

  @override
  List<Object?> get props => <Object?>[
        contentType,
        title,
        originalTitle,
        synopsis,
        posterPath,
        backdropPath,
        releaseYear,
        durationMinutes,
        ageRating,
        directorName,
        genres,
        castNames,
        countries,
        audioLanguages,
        subtitleLanguages,
        quality,
        sourceUrl,
        rating,
      ];
}
