import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:cineva_widgets/src/library/library_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LibraryController toggles favorite state', () async {
    final repository = _FakeUserLibraryRepository();
    final controller = LibraryController(repository);

    await Future<void>.delayed(Duration.zero);
    await controller.toggleFavorite(
      const ContentTileModel(
        id: 'movie_1',
        title: 'Radiant City',
        subtitle: 'Film',
        badge: '4K',
        contentType: 'movie',
      ),
    );

    expect(controller.state.favoriteIds.contains('movie_1'), isTrue);
  });

  test('LibraryController saves progress into continue watching', () async {
    final repository = _FakeUserLibraryRepository();
    final controller = LibraryController(repository);

    await Future<void>.delayed(Duration.zero);
    await controller.saveProgress(
      content: const ContentTileModel(
        id: 'movie_1',
        title: 'Radiant City',
        subtitle: 'Film',
        badge: '4K',
        contentType: 'movie',
      ),
      positionSeconds: 120,
      durationSeconds: 600,
    );

    expect(controller.state.continueWatching, isNotEmpty);
    expect(controller.state.continueWatching.first.positionSeconds, 120);
  });
}

class _FakeUserLibraryRepository implements UserLibraryRepository {
  final Set<String> favorites = <String>{};
  final List<PlaybackProgressModel> progress = <PlaybackProgressModel>[];
  final List<DownloadItemModel> downloads = <DownloadItemModel>[];

  @override
  Future<DownloadItemModel> enqueueDownload(ContentDetailModel detail) async {
    final item = DownloadItemModel(
      contentId: detail.id,
      contentType: detail.contentType,
      progressPercent: 0,
      sizeMb: detail.downloadSizeMb,
      status: DownloadStatus.queued,
      content: detail.toTile(),
    );
    downloads.add(item);
    return item;
  }

  @override
  Future<List<PlaybackProgressModel>> fetchContinueWatching() async => progress;

  @override
  Future<List<DownloadItemModel>> fetchDownloads() async => downloads;

  @override
  Future<Set<String>> fetchFavoriteIds() async => favorites;

  @override
  Future<PlaybackProgressModel?> fetchProgress({required String contentId, required String contentType}) async => null;

  @override
  Future<void> removeDownload(String contentId) async {
    downloads.removeWhere((item) => item.contentId == contentId);
  }

  @override
  Future<void> savePlaybackProgress({required ContentTileModel content, required int positionSeconds, required int durationSeconds}) async {
    progress.removeWhere((item) => item.contentId == content.id);
    progress.add(
      PlaybackProgressModel(
        contentId: content.id,
        contentType: content.contentType,
        positionSeconds: positionSeconds,
        durationSeconds: durationSeconds,
        updatedAt: DateTime.now(),
        content: content,
      ),
    );
  }

  @override
  Future<bool> toggleFavorite({required String contentId, required String contentType}) async {
    if (favorites.contains(contentId)) {
      favorites.remove(contentId);
      return false;
    }
    favorites.add(contentId);
    return true;
  }

  @override
  Future<void> updateDownload(DownloadItemModel item) async {}
}
