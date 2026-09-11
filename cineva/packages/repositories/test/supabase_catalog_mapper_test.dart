import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/src/supabase_catalog_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = SupabaseCatalogMapper(defaultVideoUrl: 'https://example.com/default.mp4');

  test('maps movie metadata into detail with fallback defaults', () {
    final detail = mapper.movieToDetail(<String, dynamic>{
      'id': 'movie_1',
      'title': 'Radiant City',
      'synopsis': 'Synopsis',
      'director_name': 'Ava Stone',
      'genres': <String>['Sci-Fi'],
      'cast_names': <String>['Lena North'],
      'duration_minutes': 120,
      'metadata': <String, dynamic>{
        'rating': 4.8,
        'download_size_mb': 1500,
        'available_qualities': <Map<String, dynamic>>[
          <String, dynamic>{
            'preset': 'p1080',
            'bitrateMbps': 6.2,
            'resolutionLabel': '1920×1080',
            'hdr': false,
            'dolbyVision': false,
            'dolbyAtmos': false,
          },
        ],
      },
    });

    expect(detail.id, 'movie_1');
    expect(detail.rating, 4.8);
    expect(detail.downloadSizeMb, 1500);
    expect(detail.availableQualities.single.preset, VideoQualityPreset.p1080);
    expect(detail.videoUrl, 'https://example.com/default.mp4');
  });

  test('maps episode into standalone content detail preserving parent metadata', () {
    const parent = ContentDetailModel(
      id: 'series_1',
      contentType: 'series',
      title: 'Orbit',
      subtitle: 'Series',
      synopsis: 'Parent synopsis',
      badge: 'Series',
      genres: <String>['Sci-Fi'],
      castNames: <String>['Lead'],
      audioLanguages: <String>['Français'],
      subtitleLanguages: <String>['Français'],
      directorName: 'Ava Stone',
      downloadSizeMb: 900,
      availableQualities: <VideoQualityOption>[],
      year: 2026,
    );
    const episode = EpisodeModel(
      id: 'episode_1',
      seriesId: 'series_1',
      seasonId: 'season_1',
      seasonNumber: 1,
      episodeNumber: 1,
      title: 'Pilot',
      synopsis: 'Episode synopsis',
      durationMinutes: 52,
      videoUrl: 'https://example.com/pilot.mp4',
      nextEpisodeId: 'episode_2',
    );

    final detail = mapper.episodeToDetail(parent: parent, episode: episode);

    expect(detail.seriesId, 'series_1');
    expect(detail.nextContentId, 'episode_2');
    expect(detail.title, 'Pilot');
    expect(detail.genres, parent.genres);
  });
}
