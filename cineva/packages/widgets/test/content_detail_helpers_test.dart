import 'dart:math';

import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_widgets/src/user/content_detail_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final episodeOne = const EpisodeModel(
    id: 'ep_1',
    seriesId: 'series_1',
    seasonId: 'season_1',
    seasonNumber: 1,
    episodeNumber: 1,
    title: 'Episode 1',
    synopsis: 'Start',
    durationMinutes: 50,
    videoUrl: 'https://example.com/1.mp4',
  );
  final episodeTwo = const EpisodeModel(
    id: 'ep_2',
    seriesId: 'series_1',
    seasonId: 'season_1',
    seasonNumber: 1,
    episodeNumber: 2,
    title: 'Episode 2',
    synopsis: 'Continue',
    durationMinutes: 50,
    videoUrl: 'https://example.com/2.mp4',
  );
  final detail = ContentDetailModel(
    id: 'series_1',
    contentType: 'series',
    title: 'Series',
    subtitle: 'Drama',
    synopsis: 'Synopsis',
    badge: 'Series',
    genres: const <String>['Drama'],
    castNames: const <String>['Lead'],
    audioLanguages: const <String>['Français'],
    subtitleLanguages: const <String>['Français'],
    directorName: 'Director',
    downloadSizeMb: 900,
    availableQualities: const <VideoQualityOption>[],
    seasons: <SeasonModel>[
      SeasonModel(
        id: 'season_1',
        seriesId: 'series_1',
        seasonNumber: 1,
        title: 'Saison 1',
        episodes: <EpisodeModel>[episodeOne, episodeTwo],
      ),
    ],
  );

  test('finds latest series progress among all continue watching items', () {
    final progress = ContentDetailHelpers.latestSeriesProgress(
      detail,
      <PlaybackProgressModel>[
        PlaybackProgressModel(
          contentId: episodeOne.id,
          contentType: 'episode',
          positionSeconds: 40,
          durationSeconds: 100,
          updatedAt: DateTime(2026, 1, 1),
          content: const ContentTileModel(
            id: 'ep_1',
            title: 'Episode 1',
            subtitle: 'Série',
            badge: 'Episode',
            contentType: 'episode',
          ),
        ),
        PlaybackProgressModel(
          contentId: episodeTwo.id,
          contentType: 'episode',
          positionSeconds: 50,
          durationSeconds: 100,
          updatedAt: DateTime(2026, 1, 2),
          content: const ContentTileModel(
            id: 'ep_2',
            title: 'Episode 2',
            subtitle: 'Série',
            badge: 'Episode',
            contentType: 'episode',
          ),
        ),
      ],
    );

    expect(progress?.content.id, episodeTwo.id);
  });

  test('returns a random episode when series contains episodes', () {
    final episode = ContentDetailHelpers.pickRandomEpisode(detail, random: _FakeRandom(1));
    expect(episode?.id, episodeTwo.id);
  });

  test('maps download labels and icons from status', () {
    final item = DownloadItemModel(
      contentId: 'movie_1',
      contentType: 'movie',
      progressPercent: 0.42,
      sizeMb: 10,
      status: DownloadStatus.downloading,
      content: const ContentTileModel(
        id: 'movie_1',
        title: 'Movie',
        subtitle: 'Film',
        badge: '4K',
        contentType: 'movie',
      ),
    );

    expect(ContentDetailHelpers.downloadLabel(item), 'Pause (42%)');
    expect(ContentDetailLayout.isWide(1200), isTrue);
    expect(ContentDetailLayout.posterWidth(400), 190);
  });
}

class _FakeRandom implements Random {
  const _FakeRandom(this._value);

  final int _value;

  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => _value.clamp(0, max - 1) as int;
}
