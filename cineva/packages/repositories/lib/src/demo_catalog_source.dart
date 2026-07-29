import 'dart:convert';

import 'package:cineva_models/cineva_models.dart';
import 'package:flutter/services.dart';

class DemoCatalogPayload {
  const DemoCatalogPayload({
    required this.contents,
    required this.sections,
    required this.details,
  });

  final List<ContentTileModel> contents;
  final List<HomeSectionModel> sections;
  final Map<String, ContentDetailModel> details;
}

class DemoCatalogSource {
  DemoCatalogSource({this.assetPath = 'packages/cineva_repositories/assets/demo_catalog.json'});

  final String assetPath;
  DemoCatalogPayload? _cache;

  Future<DemoCatalogPayload> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString(assetPath);
    _cache = parse(raw);
    return _cache!;
  }

  static DemoCatalogPayload parse(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final details = <String, ContentDetailModel>{};

    for (final entry in (decoded['contents'] as List<dynamic>? ?? const <dynamic>[])) {
      final map = Map<String, dynamic>.from(entry as Map);
      final detail = _detailFromMap(map);
      details[detail.id] = detail;
      for (final season in detail.seasons) {
        for (final episode in season.episodes) {
          details[episode.id] = _episodeToDetail(parent: detail, episode: episode);
        }
      }
    }

    final contents = details.values.where((detail) => detail.contentType != 'episode').map((detail) => detail.toTile()).toList();
    final contentById = <String, ContentTileModel>{
      for (final content in contents) content.id: content,
    };

    final sections = (decoded['sections'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (entry) => _sectionFromMap(
            Map<String, dynamic>.from(entry as Map),
            contentById,
          ),
        )
        .where((section) => section.items.isNotEmpty)
        .toList();

    return DemoCatalogPayload(contents: contents, sections: sections, details: details);
  }

  static HomeSectionModel _sectionFromMap(
    Map<String, dynamic> map,
    Map<String, ContentTileModel> contentById,
  ) {
    final rawItems = map['itemIds'] as List<dynamic>? ?? const <dynamic>[];
    final items = <ContentTileModel>[];

    for (final raw in rawItems) {
      if (raw is String) {
        final base = contentById[raw];
        if (base != null) items.add(base);
        continue;
      }

      if (raw is Map<String, dynamic>) {
        final id = raw['id'] as String?;
        final base = id == null ? null : contentById[id];
        if (base != null) {
          items.add(base.copyWith(progressPercent: (raw['progressPercent'] as num?)?.toDouble()));
        }
      }
    }

    return HomeSectionModel(
      key: map['key'] as String? ?? 'section',
      title: map['title'] as String? ?? 'Section',
      description: map['description'] as String?,
      layoutType: map['layoutType'] as String? ?? 'rail',
      items: items,
    );
  }

  static ContentDetailModel _detailFromMap(Map<String, dynamic> map) {
    final seasons = (map['seasons'] as List<dynamic>? ?? const <dynamic>[])
        .map((entry) => _seasonFromMap(Map<String, dynamic>.from(entry as Map)))
        .toList();

    return ContentDetailModel(
      id: map['id'] as String? ?? '',
      contentType: map['contentType'] as String? ?? 'movie',
      title: map['title'] as String? ?? 'Sans titre',
      subtitle: map['subtitle'] as String? ?? '',
      synopsis: map['description'] as String? ?? '',
      badge: map['badge'] as String? ?? 'Cineva',
      posterPath: map['posterPath'] as String?,
      backdropPath: map['backdropPath'] as String?,
      directorName: map['directorName'] as String? ?? 'Inconnu',
      genres: (map['genres'] as List<dynamic>? ?? const <dynamic>[]).map((genre) => '$genre').toList(),
      castNames: (map['castNames'] as List<dynamic>? ?? const <dynamic>[]).map((actor) => '$actor').toList(),
      audioLanguages: (map['audioLanguages'] as List<dynamic>? ?? const <dynamic>['Français']).map((e) => '$e').toList(),
      subtitleLanguages: (map['subtitleLanguages'] as List<dynamic>? ?? const <dynamic>['Français']).map((e) => '$e').toList(),
      year: map['year'] as int?,
      durationMinutes: map['durationMinutes'] as int?,
      ageRating: map['ageRating'] as String?,
      videoUrl: map['videoUrl'] as String?,
      trailerUrl: map['trailerUrl'] as String?,
      rating: (map['rating'] as num?)?.toDouble(),
      downloadSizeMb: (map['downloadSizeMb'] as num?)?.toDouble() ?? 820,
      availableQualities: _qualitiesFromMap(map['availableQualities'] as List<dynamic>?),
      seasons: seasons,
      defaultPlaybackId: map['defaultPlaybackId'] as String?,
    );
  }

  static SeasonModel _seasonFromMap(Map<String, dynamic> map) {
    return SeasonModel(
      id: map['id'] as String,
      seriesId: map['seriesId'] as String,
      seasonNumber: map['seasonNumber'] as int? ?? 1,
      title: map['title'] as String? ?? 'Saison',
      synopsis: map['synopsis'] as String?,
      posterPath: map['posterPath'] as String?,
      episodes: (map['episodes'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => _episodeFromMap(Map<String, dynamic>.from(entry as Map)))
          .toList(),
    );
  }

  static EpisodeModel _episodeFromMap(Map<String, dynamic> map) {
    return EpisodeModel(
      id: map['id'] as String,
      seriesId: map['seriesId'] as String,
      seasonId: map['seasonId'] as String? ?? '',
      seasonNumber: map['seasonNumber'] as int? ?? 1,
      episodeNumber: map['episodeNumber'] as int? ?? 1,
      title: map['title'] as String? ?? 'Épisode',
      synopsis: map['synopsis'] as String? ?? '',
      durationMinutes: map['durationMinutes'] as int? ?? 48,
      videoUrl: map['videoUrl'] as String? ?? '',
      thumbnailPath: map['thumbnailPath'] as String?,
      audioLanguages: (map['audioLanguages'] as List<dynamic>? ?? const <dynamic>['Français']).map((e) => '$e').toList(),
      subtitleLanguages: (map['subtitleLanguages'] as List<dynamic>? ?? const <dynamic>['Français']).map((e) => '$e').toList(),
      rating: (map['rating'] as num?)?.toDouble(),
      introEndSeconds: map['introEndSeconds'] as int?,
      creditsStartSeconds: map['creditsStartSeconds'] as int?,
      nextEpisodeId: map['nextEpisodeId'] as String?,
    );
  }

  static ContentDetailModel _episodeToDetail({
    required ContentDetailModel parent,
    required EpisodeModel episode,
  }) {
    return ContentDetailModel(
      id: episode.id,
      seriesId: parent.id,
      contentType: 'episode',
      title: episode.title,
      subtitle: '${parent.title} • ${episode.label}',
      synopsis: episode.synopsis,
      badge: parent.badge,
      posterPath: episode.thumbnailPath ?? parent.posterPath,
      backdropPath: parent.backdropPath,
      directorName: parent.directorName,
      genres: parent.genres,
      castNames: parent.castNames,
      audioLanguages: episode.audioLanguages,
      subtitleLanguages: episode.subtitleLanguages,
      year: parent.year,
      durationMinutes: episode.durationMinutes,
      ageRating: parent.ageRating,
      videoUrl: episode.videoUrl,
      trailerUrl: parent.trailerUrl,
      rating: episode.rating ?? parent.rating,
      downloadSizeMb: parent.downloadSizeMb,
      availableQualities: parent.availableQualities,
      defaultPlaybackId: episode.id,
      nextContentId: episode.nextEpisodeId,
      introEndSeconds: episode.introEndSeconds,
      creditsStartSeconds: episode.creditsStartSeconds,
    );
  }

  static List<VideoQualityOption> _qualitiesFromMap(List<dynamic>? values) {
    return (values ?? const <dynamic>[])
        .map((entry) {
          final map = Map<String, dynamic>.from(entry as Map);
          var preset = VideoQualityPreset.auto;
          for (final value in VideoQualityPreset.values) {
            if (value.name == map['preset']) {
              preset = value;
              break;
            }
          }
          return VideoQualityOption(
            preset: preset,
            bitrateMbps: (map['bitrateMbps'] as num?)?.toDouble() ?? 0,
            resolutionLabel: map['resolutionLabel'] as String? ?? 'Adaptatif',
            hdr: map['hdr'] as bool? ?? false,
            dolbyVision: map['dolbyVision'] as bool? ?? false,
            dolbyAtmos: map['dolbyAtmos'] as bool? ?? false,
            available: map['available'] as bool? ?? true,
            streamUrl: map['streamUrl'] as String? ?? map['url'] as String?,
            mimeType: map['mimeType'] as String?,
          );
        })
        .toList();
  }
}
