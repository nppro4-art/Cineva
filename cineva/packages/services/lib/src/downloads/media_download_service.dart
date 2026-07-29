import 'dart:async';

import 'package:cineva_models/cineva_models.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

import 'download_file_support.dart';
import 'download_progress_metrics.dart';
import 'download_runtime_policy.dart';

class MediaDownloadService {
  MediaDownloadService({Dio? dio, this.maxConcurrentDownloads = 2}) : _dio = dio ?? Dio();

  final Dio _dio;
  final int maxConcurrentDownloads;
  final StreamController<DownloadItemModel> _updatesController = StreamController<DownloadItemModel>.broadcast();
  final List<_DownloadRequest> _queue = <_DownloadRequest>[];
  final Map<String, _ActiveDownload> _active = <String, _ActiveDownload>{};
  final Map<String, _DownloadRequest> _knownRequests = <String, _DownloadRequest>{};

  Stream<DownloadItemModel> get updates => _updatesController.stream;

  Future<DownloadItemModel> enqueue({
    required ContentDetailModel detail,
    VideoQualityPreset? quality,
    DownloadItemModel? existing,
  }) async {
    final request = await _buildRequest(detail, quality: quality, existing: existing);
    _knownRequests[request.item.contentId] = request;

    if (_active.containsKey(request.item.contentId) || _queue.any((q) => q.item.contentId == request.item.contentId)) {
      return request.item;
    }

    _queue.add(request);
    final queued = request.item.copyWith(
      status: DownloadStatus.queued,
      updatedAt: DateTime.now(),
      clearError: true,
    );
    _emit(queued);
    unawaited(_pumpQueue());
    return queued;
  }

  Future<void> pause(String contentId) async {
    final active = _active[contentId];
    if (active != null) {
      active.cancelToken.cancel('paused');
      return;
    }

    final index = _queue.indexWhere((item) => item.item.contentId == contentId);
    if (index != -1) {
      final request = _queue.removeAt(index);
      _emit(request.item.copyWith(status: DownloadStatus.paused, updatedAt: DateTime.now()));
    }
  }

  Future<void> resume({
    required ContentDetailModel detail,
    DownloadItemModel? existing,
  }) async {
    await enqueue(detail: detail, existing: existing);
  }

  Future<void> remove(DownloadItemModel item) async {
    final contentId = item.contentId;
    final active = _active.remove(contentId);
    active?.cancelToken.cancel('deleted');
    _queue.removeWhere((entry) => entry.item.contentId == contentId);
    _knownRequests.remove(contentId);

    await _deleteIfExists(item.localFilePath);
    await _deleteIfExists(DownloadFileSupport.partialPath(item.localFilePath));
    _emit(item.copyWith(status: DownloadStatus.deleted, updatedAt: DateTime.now(), clearError: true));
    unawaited(_pumpQueue());
  }

  Future<bool> fileExists(String? path) async {
    if (path == null || path.isEmpty) return false;
    return File(path).exists();
  }

  Future<void> cleanupExpired(Iterable<DownloadItemModel> items) async {
    for (final item in items.where((item) => item.status == DownloadStatus.deleted)) {
      await _deleteIfExists(item.localFilePath);
      await _deleteIfExists(DownloadFileSupport.partialPath(item.localFilePath));
    }
  }

  Future<void> dispose() async {
    for (final active in _active.values) {
      active.cancelToken.cancel('dispose');
    }
    _active.clear();
    await _updatesController.close();
  }

  Future<_DownloadRequest> _buildRequest(
    ContentDetailModel detail, {
    VideoQualityPreset? quality,
    DownloadItemModel? existing,
  }) async {
    final chosenQuality = DownloadRuntimePolicy.preferredQuality(
      detail,
      preferred: quality,
    );
    final url = detail.resolveDownloadUrl(chosenQuality);
    if (url == null || url.isEmpty) {
      throw Exception('Aucun fichier téléchargeable hors ligne n’est disponible pour ${detail.title}.');
    }

    final downloadsDir = await _downloadsDirectory();
    final fileName = DownloadFileSupport.buildFileName(
      contentId: detail.id,
      quality: chosenQuality,
      url: url,
    );
    final localPath = p.join(downloadsDir.path, fileName);

    final item = (existing ??
            DownloadItemModel(
              contentId: detail.id,
              contentType: detail.contentType,
              progressPercent: 0,
              sizeMb: detail.downloadSizeMb,
              status: DownloadStatus.queued,
              content: detail.toTile(),
              localFilePath: localPath,
            ))
        .copyWith(
          localFilePath: localPath,
          status: DownloadStatus.queued,
          updatedAt: DateTime.now(),
          clearError: true,
        );

    return _DownloadRequest(
      detail: detail,
      quality: chosenQuality,
      url: url,
      item: item,
    );
  }

  Future<void> _pumpQueue() async {
    while (_active.length < maxConcurrentDownloads && _queue.isNotEmpty) {
      final request = _queue.removeAt(0);
      unawaited(_startDownload(request));
    }
  }

  Future<void> _startDownload(_DownloadRequest request) async {
    final contentId = request.item.contentId;
    final localPath = request.item.localFilePath!;
    final partPath = DownloadFileSupport.partialPath(localPath);
    final tempFile = File(partPath);
    final directory = tempFile.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    var existingBytes = await tempFile.exists() ? await tempFile.length() : 0;
    final cancelToken = CancelToken();
    final active = _ActiveDownload(cancelToken: cancelToken, request: request, startedAt: DateTime.now(), initialBytes: existingBytes);
    _active[contentId] = active;

    try {
      Response<ResponseBody> response = await _dio.get<ResponseBody>(
        request.url,
        options: Options(
          responseType: ResponseType.stream,
          headers: existingBytes > 0 ? <String, dynamic>{'range': 'bytes=$existingBytes-'} : null,
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 30),
          sendTimeout: const Duration(minutes: 5),
        ),
        cancelToken: cancelToken,
      );

      if (existingBytes > 0 && response.statusCode != 206) {
        await tempFile.delete().catchError((_) {});
        existingBytes = 0;
        response = await _dio.get<ResponseBody>(
          request.url,
          options: Options(
            responseType: ResponseType.stream,
            followRedirects: true,
            receiveTimeout: const Duration(minutes: 30),
            sendTimeout: const Duration(minutes: 5),
          ),
          cancelToken: cancelToken,
        );
      }

      final reportedLength = int.tryParse(response.headers.value(Headers.contentLengthHeader) ?? '0') ?? 0;
      final totalBytes = (response.statusCode == 206 ? existingBytes : 0) + reportedLength;
      var downloadedBytes = existingBytes;
      var lastEmit = DateTime.now();

      final sink = tempFile.openWrite(mode: existingBytes > 0 ? FileMode.append : FileMode.write);
      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        final now = DateTime.now();
        if (now.difference(lastEmit).inMilliseconds >= 240 || downloadedBytes == totalBytes) {
          lastEmit = now;
          final metrics = DownloadProgressMetrics.calculate(
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
            initialBytes: active.initialBytes,
            elapsed: now.difference(active.startedAt),
          );

          _emit(request.item.copyWith(
            status: DownloadStatus.downloading,
            progressPercent: metrics.progressPercent,
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
            transferSpeedMbps: metrics.transferSpeedMbps,
            estimatedRemainingSeconds: metrics.estimatedRemainingSeconds,
            updatedAt: now,
            localFilePath: localPath,
            clearError: true,
          ));
        }
      }
      await sink.close();

      final finalFile = File(localPath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(localPath);

      _emit(request.item.copyWith(
        status: DownloadStatus.completed,
        progressPercent: 1,
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
        transferSpeedMbps: null,
        estimatedRemainingSeconds: 0,
        updatedAt: DateTime.now(),
        localFilePath: localPath,
        clearError: true,
      ));
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        final reason = '${error.error ?? error.message ?? ''}'.toLowerCase();
        final status = DownloadRuntimePolicy.treatCancelAsDeletion(reason) ? DownloadStatus.deleted : DownloadStatus.paused;
        _emit(request.item.copyWith(
          status: status,
          updatedAt: DateTime.now(),
          localFilePath: localPath,
        ));
      } else {
        _emit(request.item.copyWith(
          status: DownloadStatus.failed,
          errorMessage: error.message,
          updatedAt: DateTime.now(),
          localFilePath: localPath,
        ));
      }
    } catch (error) {
      _emit(request.item.copyWith(
        status: DownloadStatus.failed,
        errorMessage: error.toString(),
        updatedAt: DateTime.now(),
        localFilePath: localPath,
      ));
    } finally {
      _active.remove(contentId);
      unawaited(_pumpQueue());
    }
  }

  void _emit(DownloadItemModel item) {
    if (!_updatesController.isClosed) {
      _updatesController.add(item);
    }
  }

  Future<Directory> _downloadsDirectory() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'cineva_downloads'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _deleteIfExists(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class _DownloadRequest {
  const _DownloadRequest({
    required this.detail,
    required this.quality,
    required this.url,
    required this.item,
  });

  final ContentDetailModel detail;
  final VideoQualityPreset quality;
  final String url;
  final DownloadItemModel item;
}

class _ActiveDownload {
  _ActiveDownload({
    required this.cancelToken,
    required this.request,
    required this.startedAt,
    required this.initialBytes,
  });

  final CancelToken cancelToken;
  final _DownloadRequest request;
  final DateTime startedAt;
  final int initialBytes;
}
