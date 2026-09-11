import 'package:equatable/equatable.dart';

import 'content_tile_model.dart';
import 'season_model.dart';
import 'skip_segment_model.dart';
import 'video_quality_option.dart';

class ContentDetailModel extends Equatable {
  const ContentDetailModel({
    required this.id,
    required this.contentType,
    required this.title,
    required this.subtitle,
    required this.synopsis,
    required this.badge,
    required this.genres,
    required this.castNames,
    required this.audioLanguages,
    required this.subtitleLanguages,
    required this.directorName,
    required this.downloadSizeMb,
    required this.availableQualities,
    this.posterPath,
    this.backdropPath,
    this.year,
    this.durationMinutes,
    this.ageRating,
    this.videoUrl,
    this.trailerUrl,
    this.rating,
    this.seriesId,
    this.seasons = const <SeasonModel>[],
    this.defaultPlaybackId,
    this.nextContentId,
    this.introEndSeconds,
    this.creditsStartSeconds,
    this.skipSegments = const <SkipSegment>[],
  });

  final String id;
  final String contentType;
  final String title;
  final String subtitle;
  final String synopsis;
  final String badge;
  final List<String> genres;
  final List<String> castNames;
  final List<String> audioLanguages;
  final List<String> subtitleLanguages;
  final String directorName;
  final double downloadSizeMb;
  final List<VideoQualityOption> availableQualities;
  final String? posterPath;
  final String? backdropPath;
  final int? year;
  final int? durationMinutes;
  final String? ageRating;
  final String? videoUrl;
  final String? trailerUrl;
  final double? rating;
  final String? seriesId;
  final List<SeasonModel> seasons;
  final String? defaultPlaybackId;
  final String? nextContentId;
  final int? introEndSeconds;
  final int? creditsStartSeconds;

  /// Segments à passer pendant la lecture (génériques, pubs…).
  final List<SkipSegment> skipSegments;

  bool get isSeries => contentType == 'series';
  bool get isEpisode => contentType == 'episode';
  bool get isMovie => contentType == 'movie';

  String? resolvePlaybackUrl(VideoQualityPreset preset) {
    final dedicated = availableQualities
        .where((option) => option.preset == preset)
        .where((option) => option.hasDedicatedStream)
        .map((option) => option.streamUrl)
        .firstWhere((value) => value != null && value.isNotEmpty, orElse: () => null);
    return dedicated ?? videoUrl;
  }

  VideoQualityOption? resolveDownloadQuality([VideoQualityPreset? preferred]) {
    final directFileOptions = availableQualities.where((option) {
      final url = option.streamUrl?.toLowerCase() ?? '';
      final mime = option.mimeType?.toLowerCase() ?? '';
      final isManifest = url.endsWith('.m3u8') || url.endsWith('.mpd') || mime.contains('mpegurl') || mime.contains('dash');
      return option.hasDedicatedStream && option.available && !isManifest;
    }).toList();

    if (directFileOptions.isEmpty) return null;

    if (preferred != null) {
      final preferredMatch = directFileOptions.where((option) => option.preset == preferred).firstWhere((_) => true, orElse: () => directFileOptions.first);
      return preferredMatch;
    }

    directFileOptions.sort((a, b) => a.bitrateMbps.compareTo(b.bitrateMbps));
    return directFileOptions.last;
  }

  String? resolveDownloadUrl([VideoQualityPreset? preferred]) {
    return resolveDownloadQuality(preferred)?.streamUrl;
  }

  ContentTileModel toTile({double? progressPercent}) {
    return ContentTileModel(
      id: id,
      title: title,
      subtitle: subtitle,
      badge: badge,
      contentType: contentType,
      imagePath: posterPath,
      backdropPath: backdropPath,
      description: synopsis,
      directorName: directorName,
      year: year,
      durationMinutes: durationMinutes,
      ageRating: ageRating,
      progressPercent: progressPercent,
      genres: genres,
      castNames: castNames,
      isFeatured: false,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        contentType,
        title,
        subtitle,
        synopsis,
        badge,
        genres,
        castNames,
        audioLanguages,
        subtitleLanguages,
        directorName,
        downloadSizeMb,
        availableQualities,
        posterPath,
        backdropPath,
        year,
        durationMinutes,
        ageRating,
        videoUrl,
        trailerUrl,
        rating,
        seriesId,
        seasons,
        defaultPlaybackId,
        nextContentId,
        introEndSeconds,
        creditsStartSeconds,
        skipSegments,
      ];
}
