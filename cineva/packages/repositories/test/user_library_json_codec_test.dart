import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/src/user_library_json_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes and hydrates playback progress consistently', () {
    final model = PlaybackProgressModel(
      contentId: 'movie_1',
      contentType: 'movie',
      positionSeconds: 320,
      durationSeconds: 1200,
      updatedAt: DateTime(2026, 1, 1),
      content: const ContentTileModel(
        id: 'movie_1',
        title: 'Movie',
        subtitle: 'Film',
        badge: '4K',
        contentType: 'movie',
      ),
    );

    final json = UserLibraryJsonCodec.progressToJson(model);
    final hydrated = UserLibraryJsonCodec.progressFromJson(json);

    expect(hydrated, model);
  });

  test('serializes and hydrates download state consistently', () {
    final item = DownloadItemModel(
      contentId: 'movie_1',
      contentType: 'movie',
      progressPercent: 0.5,
      sizeMb: 800,
      status: DownloadStatus.paused,
      content: const ContentTileModel(
        id: 'movie_1',
        title: 'Movie',
        subtitle: 'Film',
        badge: '4K',
        contentType: 'movie',
      ),
      downloadedBytes: 500,
      totalBytes: 1000,
      localFilePath: '/tmp/movie.mp4',
    );

    final json = UserLibraryJsonCodec.downloadToJson(item);
    final hydrated = UserLibraryJsonCodec.downloadFromJson(json);

    expect(hydrated.content.id, item.content.id);
    expect(hydrated.status, DownloadStatus.paused);
    expect(hydrated.localFilePath, '/tmp/movie.mp4');
  });
}
