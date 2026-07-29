import 'package:cineva_models/cineva_models.dart';

abstract interface class UserLibraryRepository {
  Future<Set<String>> fetchFavoriteIds();

  Future<bool> toggleFavorite({
    required String contentId,
    required String contentType,
  });

  Future<void> savePlaybackProgress({
    required ContentTileModel content,
    required int positionSeconds,
    required int durationSeconds,
  });

  Future<List<PlaybackProgressModel>> fetchContinueWatching();

  Future<PlaybackProgressModel?> fetchProgress({
    required String contentId,
    required String contentType,
  });

  Future<List<DownloadItemModel>> fetchDownloads();

  Future<DownloadItemModel> enqueueDownload(ContentDetailModel detail);

  Future<void> updateDownload(DownloadItemModel item);

  Future<void> removeDownload(String contentId);
}
