import 'package:cineva_repositories/src/demo_catalog_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DemoCatalogSource.parse builds home sections and contents', () {
    const raw = '''
    {
      "contents": [
        {
          "id": "movie_1",
          "title": "Demo Movie",
          "subtitle": "Film • 2026",
          "contentType": "movie",
          "badge": "4K",
          "description": "Description",
          "genres": ["Thriller"],
          "year": 2026,
          "availableQualities": [{"preset": "auto", "bitrateMbps": 3.5, "resolutionLabel": "Auto", "hdr": false, "dolbyVision": false, "dolbyAtmos": false, "available": true}]
        },
        {
          "id": "series_1",
          "title": "Demo Series",
          "subtitle": "Série • 2026",
          "contentType": "series",
          "badge": "Hit",
          "description": "Description série",
          "genres": ["Science-fiction"],
          "year": 2026,
          "availableQualities": [{"preset": "auto", "bitrateMbps": 3.5, "resolutionLabel": "Auto", "hdr": false, "dolbyVision": false, "dolbyAtmos": false, "available": true}],
          "seasons": [
            {
              "id": "season_1",
              "seriesId": "series_1",
              "seasonNumber": 1,
              "title": "Saison 1",
              "episodes": [
                {
                  "id": "episode_1",
                  "seriesId": "series_1",
                  "seasonNumber": 1,
                  "episodeNumber": 1,
                  "title": "Episode 1",
                  "synopsis": "Synopsis",
                  "durationMinutes": 48,
                  "videoUrl": "https://example.com/video.mp4"
                }
              ]
            }
          ]
        }
      ],
      "sections": [
        {
          "key": "featured",
          "title": "À la une",
          "layoutType": "hero",
          "itemIds": ["movie_1"]
        },
        {
          "key": "continue_watching",
          "title": "Continuer",
          "layoutType": "continue_watching",
          "itemIds": [{"id": "movie_1", "progressPercent": 0.42}]
        }
      ]
    }
    ''';

    final payload = DemoCatalogSource.parse(raw);

    expect(payload.contents, hasLength(2));
    expect(payload.sections, hasLength(2));
    expect(payload.sections.first.isHero, isTrue);
    expect(payload.sections.last.items.first.progressPercent, 0.42);
    expect(payload.details['movie_1']?.title, 'Demo Movie');
    expect(payload.details['series_1']?.seasons, isNotEmpty);
    expect(payload.details['episode_1']?.contentType, 'episode');
  });
}
