import 'dart:async';

import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LibraryState extends Equatable {
  const LibraryState({
    this.favoriteIds = const <String>{},
    this.continueWatching = const <PlaybackProgressModel>[],
    this.downloads = const <DownloadItemModel>[],
    this.isLoading = false,
    this.errorMessage,
  });

  final Set<String> favoriteIds;
  final List<PlaybackProgressModel> continueWatching;
  final List<DownloadItemModel> downloads;
  final bool isLoading;
  final String? errorMessage;

  bool isFavorite(String contentId) => favoriteIds.contains(contentId);

  PlaybackProgressModel? progressFor(String contentId, String contentType) {
    for (final item in continueWatching) {
      if (item.contentId == contentId && item.contentType == contentType) {
        return item;
      }
    }
    return null;
  }

  DownloadItemModel? downloadFor(String contentId) {
    for (final item in downloads) {
      if (item.contentId == contentId) {
        return item;
      }
    }
    return null;
  }

  LibraryState copyWith({
    Set<String>? favoriteIds,
    List<PlaybackProgressModel>? continueWatching,
    List<DownloadItemModel>? downloads,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LibraryState(
      favoriteIds: favoriteIds ?? this.favoriteIds,
      continueWatching: continueWatching ?? this.continueWatching,
      downloads: downloads ?? this.downloads,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        favoriteIds,
        continueWatching,
        downloads,
        isLoading,
        errorMessage,
      ];
}

class LibraryController extends StateNotifier<LibraryState> {
  LibraryController({
    required UserLibraryRepository repository,
    required CatalogRepository catalogRepository,
    required MediaDownloadService mediaDownloadService,
  })  : _repository = repository,
        _catalogRepository = catalogRepository,
        _mediaDownloadService = mediaDownloadService,
        super(const LibraryState()) {
    _downloadSubscription = _mediaDownloadService.updates.listen(_handleDownloadUpdate);
    load();
  }

  final UserLibraryRepository _repository;
  final CatalogRepository _catalogRepository;
  final MediaDownloadService _mediaDownloadService;
  late final StreamSubscription<DownloadItemModel> _downloadSubscription;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final favoriteIds = await _repository.fetchFavoriteIds();
      final continueWatching = await _repository.fetchContinueWatching();
      final downloads = await _repository.fetchDownloads();
      final normalizedDownloads = <DownloadItemModel>[];

      for (final item in downloads) {
        if (item.canPlayOffline) {
          final exists = await _mediaDownloadService.fileExists(item.localFilePath);
          final normalized = DownloadRuntimePolicy.normalizeLocalAvailability(
            item,
            fileExists: exists,
          );
          normalizedDownloads.add(normalized);
          if (normalized != item) {
            await _repository.updateDownload(normalized);
          }
          continue;
        }
        normalizedDownloads.add(item);
      }

      state = state.copyWith(
        favoriteIds: favoriteIds,
        continueWatching: continueWatching,
        downloads: normalizedDownloads,
        isLoading: false,
        clearError: true,
      );

      for (final item in normalizedDownloads.where(DownloadRuntimePolicy.shouldResumeOnStartup)) {
        await resumeDownload(
          item.contentId,
          detail: await _catalogRepository.fetchContentDetail(item.contentId),
          silentIfMissing: true,
        );
      }
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> toggleFavorite(ContentTileModel content) async {
    try {
      final nowFavorite = await _repository.toggleFavorite(contentId: content.id, contentType: content.contentType);
      final next = Set<String>.from(state.favoriteIds);
      if (nowFavorite) {
        next.add(content.id);
      } else {
        next.remove(content.id);
      }
      state = state.copyWith(favoriteIds: next, clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> saveProgress({
    required ContentTileModel content,
    required int positionSeconds,
    required int durationSeconds,
  }) async {
    try {
      await _repository.savePlaybackProgress(
        content: content,
        positionSeconds: positionSeconds,
        durationSeconds: durationSeconds,
      );
      final model = PlaybackProgressModel(
        contentId: content.id,
        contentType: content.contentType,
        positionSeconds: positionSeconds,
        durationSeconds: durationSeconds,
        updatedAt: DateTime.now(),
        content: content.copyWith(progressPercent: durationSeconds <= 0 ? 0 : positionSeconds / durationSeconds),
      );
      final items = List<PlaybackProgressModel>.from(state.continueWatching)
        ..removeWhere((item) => item.contentId == content.id && item.contentType == content.contentType);
      if (!model.isCompleted) {
        items.insert(0, model);
      }
      state = state.copyWith(continueWatching: items, clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> enqueueDownload(ContentDetailModel detail, {VideoQualityPreset? quality}) async {
    try {
      final current = downloadFor(detail.id);
      if (current != null) {
        if (current.status == DownloadStatus.paused || current.status == DownloadStatus.failed) {
          await resumeDownload(detail.id, detail: detail);
        }
        return;
      }

      final queued = await _repository.enqueueDownload(detail);
      _upsertDownloadInState(queued.copyWith(status: DownloadStatus.queued, updatedAt: DateTime.now()));
      await _mediaDownloadService.enqueue(detail: detail, quality: quality, existing: queued);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> pauseDownload(String contentId) async {
    await _mediaDownloadService.pause(contentId);
  }

  Future<void> resumeDownload(String contentId, {ContentDetailModel? detail, bool silentIfMissing = false}) async {
    try {
      final resolved = detail ?? await _catalogRepository.fetchContentDetail(contentId);
      if (resolved == null) {
        if (!silentIfMissing) {
          state = state.copyWith(errorMessage: 'Contenu introuvable pour reprendre le téléchargement.');
        }
        return;
      }
      final existing = downloadFor(contentId);
      await _mediaDownloadService.resume(detail: resolved, existing: existing);
    } catch (error) {
      if (!silentIfMissing) {
        state = state.copyWith(errorMessage: error.toString());
      }
    }
  }

  Future<void> removeDownload(String contentId) async {
    final item = downloadFor(contentId);
    if (item == null) return;
    try {
      await _mediaDownloadService.remove(item);
      await _repository.removeDownload(contentId);
      final next = List<DownloadItemModel>.from(state.downloads)..removeWhere((entry) => entry.contentId == contentId);
      state = state.copyWith(downloads: next, clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  PlaybackProgressModel? progressFor(String contentId, String contentType) {
    return state.progressFor(contentId, contentType);
  }

  DownloadItemModel? downloadFor(String contentId) {
    return state.downloadFor(contentId);
  }

  void _handleDownloadUpdate(DownloadItemModel item) {
    _upsertDownloadInState(item);
    unawaited(_repository.updateDownload(item));
  }

  void _upsertDownloadInState(DownloadItemModel item) {
    final next = List<DownloadItemModel>.from(state.downloads);
    final index = next.indexWhere((entry) => entry.contentId == item.contentId);
    if (index == -1) {
      next.insert(0, item);
    } else {
      next[index] = item;
    }
    state = state.copyWith(downloads: next, clearError: true);
  }

  @override
  void dispose() {
    _downloadSubscription.cancel();
    super.dispose();
  }
}
