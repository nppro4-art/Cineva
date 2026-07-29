import 'package:cineva_models/cineva_models.dart';
import 'package:test/test.dart';

void main() {
  test('DownloadItemModel.canPlayOffline only when completed and local path exists', () {
    const item = DownloadItemModel(
      contentId: 'movie_1',
      contentType: 'movie',
      progressPercent: 1,
      sizeMb: 1200,
      status: DownloadStatus.completed,
      content: ContentTileModel(
        id: 'movie_1',
        title: 'Radiant City',
        subtitle: 'Film',
        badge: '4K',
        contentType: 'movie',
      ),
      localFilePath: '/tmp/radiant.mp4',
    );

    expect(item.canPlayOffline, isTrue);
  });

  test('ContentDetailModel.resolvePlaybackUrl prefers dedicated stream url', () {
    const detail = ContentDetailModel(
      id: 'movie_1',
      contentType: 'movie',
      title: 'Radiant City',
      subtitle: 'Film',
      synopsis: 'Synopsis',
      badge: '4K',
      genres: <String>['Thriller'],
      castNames: <String>['Ava'],
      audioLanguages: <String>['Français'],
      subtitleLanguages: <String>['Français'],
      directorName: 'Lina',
      downloadSizeMb: 1200,
      availableQualities: <VideoQualityOption>[
        VideoQualityOption(
          preset: VideoQualityPreset.p1080,
          bitrateMbps: 6.2,
          resolutionLabel: '1920x1080',
          hdr: false,
          dolbyVision: false,
          dolbyAtmos: false,
          streamUrl: 'https://example.com/1080.m3u8',
        ),
      ],
      videoUrl: 'https://example.com/default.m3u8',
    );

    expect(detail.resolvePlaybackUrl(VideoQualityPreset.p1080), 'https://example.com/1080.m3u8');
  });

  test('ContentDetailModel.resolveDownloadUrl ignores manifest-only streams', () {
    const detail = ContentDetailModel(
      id: 'movie_2',
      contentType: 'movie',
      title: 'Nova',
      subtitle: 'Film',
      synopsis: 'Synopsis',
      badge: '4K',
      genres: <String>['Sci-Fi'],
      castNames: <String>['Kira'],
      audioLanguages: <String>['Français'],
      subtitleLanguages: <String>['Français'],
      directorName: 'Lina',
      downloadSizeMb: 1200,
      availableQualities: <VideoQualityOption>[
        VideoQualityOption(
          preset: VideoQualityPreset.auto,
          bitrateMbps: 6.2,
          resolutionLabel: 'Auto',
          hdr: false,
          dolbyVision: false,
          dolbyAtmos: false,
          streamUrl: 'https://example.com/master.m3u8',
          mimeType: 'application/x-mpegURL',
        ),
        VideoQualityOption(
          preset: VideoQualityPreset.p1080,
          bitrateMbps: 6.2,
          resolutionLabel: '1920x1080',
          hdr: false,
          dolbyVision: false,
          dolbyAtmos: false,
          streamUrl: 'https://example.com/video.mp4',
          mimeType: 'video/mp4',
        ),
      ],
      videoUrl: 'https://example.com/master.m3u8',
    );

    expect(detail.resolveDownloadUrl(), 'https://example.com/video.mp4');
  });
}
