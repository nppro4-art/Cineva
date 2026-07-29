import 'package:cineva_models/cineva_models.dart';

import 'supabase_support.dart';

class SupabaseCatalogMapper {
  const SupabaseCatalogMapper({required this.defaultVideoUrl});

  final String defaultVideoUrl;

  ContentTileModel movieToTile(Map<String, dynamic> row) => movieToDetail(row).toTile();

  ContentTileModel seriesToTile(Map<String, dynamic> row) => seriesToDetail(row).toTile();

  ContentDetailModel movieToDetail(Map<String, dynamic> row) {
    final metadata = asJsonMap(row['metadata']) ?? <String, dynamic>{};
    return ContentDetailModel(
      id: row['id'] as String,
      contentType: 'movie',
      title: row['title'] as String? ?? 'Film',
      subtitle: row['director_name'] as String? ?? 'Film',
      synopsis: row['synopsis'] as String? ?? '',
      badge: metadata['badge'] as String? ?? 'Film',
      posterPath: row['poster_path'] as String?,
      backdropPath: row['backdrop_path'] as String?,
      directorName: row['director_name'] as String? ?? 'Inconnu',
      genres: asStringList(row['genres']),
      castNames: asStringList(row['cast_names']),
      audioLanguages: asStringList(row['audio_languages']).isNotEmpty
          ? asStringList(row['audio_languages'])
          : asStringList(metadata['audio_languages'], fallback: const <String>['Français']),
      subtitleLanguages: asSubtitleLanguages(row['subtitles'] ?? metadata['subtitles']).isNotEmpty
          ? asSubtitleLanguages(row['subtitles'] ?? metadata['subtitles'])
          : const <String>['Français'],
      year: row['release_year'] as int?,
      durationMinutes: row['duration_minutes'] as int?,
      ageRating: row['age_rating'] as String?,
      videoUrl: metadata['video_url'] as String? ?? row['video_path'] as String? ?? defaultVideoUrl,
      trailerUrl: row['trailer_path'] as String?,
      rating: (metadata['rating'] as num?)?.toDouble(),
      downloadSizeMb: (metadata['download_size_mb'] as num?)?.toDouble() ?? ((row['duration_minutes'] as int? ?? 100) * 11.2),
      availableQualities: qualitiesFromMetadata(metadata),
      defaultPlaybackId: row['id'] as String,
    );
  }

  ContentDetailModel seriesToDetail(Map<String, dynamic> row, {List<SeasonModel> seasons = const <SeasonModel>[]}) {
    final metadata = asJsonMap(row['metadata']) ?? <String, dynamic>{};
    String? defaultPlaybackId;
    if (seasons.isNotEmpty) {
      defaultPlaybackId = seasons.first.firstEpisode?.id;
    }

    return ContentDetailModel(
      id: row['id'] as String,
      contentType: 'series',
      title: row['title'] as String? ?? 'Série',
      subtitle: row['director_name'] as String? ?? 'Série',
      synopsis: row['synopsis'] as String? ?? '',
      badge: metadata['badge'] as String? ?? 'Série',
      posterPath: row['poster_path'] as String?,
      backdropPath: row['backdrop_path'] as String?,
      directorName: row['director_name'] as String? ?? 'Inconnu',
      genres: asStringList(row['genres']),
      castNames: asStringList(row['cast_names']),
      audioLanguages: asStringList(metadata['audio_languages'], fallback: const <String>['Français']),
      subtitleLanguages: asSubtitleLanguages(metadata['subtitles']).isNotEmpty ? asSubtitleLanguages(metadata['subtitles']) : const <String>['Français'],
      year: row['release_year'] as int?,
      durationMinutes: (metadata['episode_runtime'] as int?) ?? 48,
      ageRating: row['age_rating'] as String?,
      videoUrl: metadata['video_url'] as String? ?? defaultVideoUrl,
      trailerUrl: row['trailer_path'] as String?,
      rating: (metadata['rating'] as num?)?.toDouble(),
      downloadSizeMb: (metadata['download_size_mb'] as num?)?.toDouble() ?? 980,
      availableQualities: qualitiesFromMetadata(metadata),
      seasons: seasons,
      defaultPlaybackId: defaultPlaybackId,
    );
  }

  EpisodeModel episodeFromRow(Map<String, dynamic> row, {int seasonNumber = 1}) {
    final metadata = asJsonMap(row['metadata']) ?? <String, dynamic>{};
    return EpisodeModel(
      id: row['id'] as String,
      seriesId: row['series_id'] as String,
      seasonId: row['season_id'] as String? ?? '',
      seasonNumber: row['season_number'] as int? ?? seasonNumber,
      episodeNumber: row['episode_number'] as int? ?? 1,
      title: row['title'] as String? ?? 'Épisode',
      synopsis: row['synopsis'] as String? ?? '',
      durationMinutes: row['duration_minutes'] as int? ?? 48,
      videoUrl: metadata['video_url'] as String? ?? row['video_path'] as String? ?? defaultVideoUrl,
      thumbnailPath: row['thumbnail_path'] as String?,
      audioLanguages: asStringList(row['audio_languages']).isNotEmpty
          ? asStringList(row['audio_languages'])
          : asStringList(metadata['audio_languages'], fallback: const <String>['Français']),
      subtitleLanguages: asSubtitleLanguages(row['subtitles'] ?? metadata['subtitles']).isNotEmpty
          ? asSubtitleLanguages(row['subtitles'] ?? metadata['subtitles'])
          : const <String>['Français'],
      rating: (metadata['rating'] as num?)?.toDouble(),
      introEndSeconds: metadata['intro_end_seconds'] as int?,
      creditsStartSeconds: metadata['credits_start_seconds'] as int?,
      nextEpisodeId: metadata['next_episode_id'] as String?,
    );
  }

  ContentDetailModel episodeToDetail({required ContentDetailModel parent, required EpisodeModel episode}) {
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

  List<VideoQualityOption> qualitiesFromMetadata(Map<String, dynamic> metadata) {
    final list = metadata['available_qualities'] ?? metadata['qualities'];
    if (list is List) {
      return list.map((entry) {
        final map = Map<String, dynamic>.from(entry as Map);
        final preset = _videoQualityPresetFromName(map['preset'] as String?) ?? VideoQualityPreset.auto;
        return VideoQualityOption(
          preset: preset,
          bitrateMbps: (map['bitrateMbps'] as num?)?.toDouble() ?? 0,
          resolutionLabel: map['resolutionLabel'] as String? ?? preset.label,
          hdr: map['hdr'] as bool? ?? false,
          dolbyVision: map['dolbyVision'] as bool? ?? false,
          dolbyAtmos: map['dolbyAtmos'] as bool? ?? false,
          available: map['available'] as bool? ?? true,
          streamUrl: map['streamUrl'] as String? ?? map['url'] as String?,
          mimeType: map['mimeType'] as String?,
        );
      }).toList();
    }
    return const <VideoQualityOption>[
      VideoQualityOption(preset: VideoQualityPreset.auto, bitrateMbps: 6.5, resolutionLabel: 'Adaptatif', hdr: false, dolbyVision: false, dolbyAtmos: false),
      VideoQualityOption(preset: VideoQualityPreset.p720, bitrateMbps: 3.2, resolutionLabel: '1280×720', hdr: false, dolbyVision: false, dolbyAtmos: false),
      VideoQualityOption(preset: VideoQualityPreset.p1080, bitrateMbps: 6.2, resolutionLabel: '1920×1080', hdr: false, dolbyVision: false, dolbyAtmos: false),
      VideoQualityOption(preset: VideoQualityPreset.p4k, bitrateMbps: 18.5, resolutionLabel: '3840×2160', hdr: true, dolbyVision: true, dolbyAtmos: true),
    ];
  }

  VideoQualityPreset? _videoQualityPresetFromName(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in VideoQualityPreset.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return null;
  }
}
