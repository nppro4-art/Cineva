import 'package:equatable/equatable.dart';

class EpisodeModel extends Equatable {
  const EpisodeModel({
    required this.id,
    required this.seriesId,
    required this.seasonId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.title,
    required this.synopsis,
    required this.durationMinutes,
    required this.videoUrl,
    this.thumbnailPath,
    this.audioLanguages = const <String>[],
    this.subtitleLanguages = const <String>[],
    this.rating,
    this.introEndSeconds,
    this.creditsStartSeconds,
    this.nextEpisodeId,
  });

  final String id;
  final String seriesId;
  final String seasonId;
  final int seasonNumber;
  final int episodeNumber;
  final String title;
  final String synopsis;
  final int durationMinutes;
  final String videoUrl;
  final String? thumbnailPath;
  final List<String> audioLanguages;
  final List<String> subtitleLanguages;
  final double? rating;
  final int? introEndSeconds;
  final int? creditsStartSeconds;
  final String? nextEpisodeId;

  String get label => 'S$seasonNumber:E$episodeNumber';

  @override
  List<Object?> get props => <Object?>[
        id,
        seriesId,
        seasonId,
        seasonNumber,
        episodeNumber,
        title,
        synopsis,
        durationMinutes,
        videoUrl,
        thumbnailPath,
        audioLanguages,
        subtitleLanguages,
        rating,
        introEndSeconds,
        creditsStartSeconds,
        nextEpisodeId,
      ];
}

class SeasonModel extends Equatable {
  const SeasonModel({
    required this.id,
    required this.seriesId,
    required this.seasonNumber,
    required this.title,
    required this.episodes,
    this.synopsis,
    this.posterPath,
  });

  final String id;
  final String seriesId;
  final int seasonNumber;
  final String title;
  final List<EpisodeModel> episodes;
  final String? synopsis;
  final String? posterPath;

  EpisodeModel? get firstEpisode => episodes.isEmpty ? null : episodes.first;

  @override
  List<Object?> get props => <Object?>[
        id,
        seriesId,
        seasonNumber,
        title,
        episodes,
        synopsis,
        posterPath,
      ];
}
