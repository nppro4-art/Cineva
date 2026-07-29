import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_services/src/downloads/download_runtime_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeLocalAvailability marks missing offline file as failed', () {
    final item = DownloadItemModel(
      contentId: 'movie_1',
      contentType: 'movie',
      progressPercent: 1,
      sizeMb: 1500,
      status: DownloadStatus.completed,
      content: const ContentTileModel(
        id: 'movie_1',
        title: 'Radiant City',
        subtitle: 'Film',
        badge: '4K',
        contentType: 'movie',
      ),
      localFilePath: '/tmp/radiant.mp4',
    );

    final normalized = DownloadRuntimePolicy.normalizeLocalAvailability(item, fileExists: false);

    expect(normalized.status, DownloadStatus.failed);
    expect(normalized.localFilePath, isNull);
  });

  test('shouldResumeOnStartup only for queued and downloading items', () {
    final base = const ContentTileModel(
      id: 'movie_1',
      title: 'Radiant City',
      subtitle: 'Film',
      badge: '4K',
      contentType: 'movie',
    );

    expect(
      DownloadRuntimePolicy.shouldResumeOnStartup(
        DownloadItemModel(contentId: '1', contentType: 'movie', progressPercent: 0, sizeMb: 1, status: DownloadStatus.queued, content: base),
      ),
      isTrue,
    );
    expect(
      DownloadRuntimePolicy.shouldResumeOnStartup(
        DownloadItemModel(contentId: '1', contentType: 'movie', progressPercent: .5, sizeMb: 1, status: DownloadStatus.downloading, content: base),
      ),
      isTrue,
    );
    expect(
      DownloadRuntimePolicy.shouldResumeOnStartup(
        DownloadItemModel(contentId: '1', contentType: 'movie', progressPercent: 1, sizeMb: 1, status: DownloadStatus.completed, content: base),
      ),
      isFalse,
    );
  });
}
