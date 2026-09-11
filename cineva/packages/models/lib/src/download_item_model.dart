import 'package:equatable/equatable.dart';

import 'content_tile_model.dart';

enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  deleted,
}

class DownloadItemModel extends Equatable {
  const DownloadItemModel({
    required this.contentId,
    required this.contentType,
    required this.progressPercent,
    required this.sizeMb,
    required this.status,
    required this.content,
    this.errorMessage,
    this.updatedAt,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.transferSpeedMbps,
    this.estimatedRemainingSeconds,
    this.localFilePath,
  });

  final String contentId;
  final String contentType;
  final double progressPercent;
  final double sizeMb;
  final DownloadStatus status;
  final ContentTileModel content;
  final String? errorMessage;
  final DateTime? updatedAt;
  final int downloadedBytes;
  final int totalBytes;
  final double? transferSpeedMbps;
  final int? estimatedRemainingSeconds;
  final String? localFilePath;

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isPaused => status == DownloadStatus.paused;
  bool get canPlayOffline => isCompleted && localFilePath != null && localFilePath!.isNotEmpty;

  /// Sentinelle distinguant « paramètre absent » de « paramètre null explicite »
  /// dans [copyWith] (permet d'effacer [localFilePath] avec `localFilePath: null`).
  static const Object _unset = Object();

  DownloadItemModel copyWith({
    double? progressPercent,
    double? sizeMb,
    DownloadStatus? status,
    ContentTileModel? content,
    String? errorMessage,
    DateTime? updatedAt,
    int? downloadedBytes,
    int? totalBytes,
    double? transferSpeedMbps,
    int? estimatedRemainingSeconds,
    Object? localFilePath = _unset,
    bool clearError = false,
  }) {
    return DownloadItemModel(
      contentId: contentId,
      contentType: contentType,
      progressPercent: progressPercent ?? this.progressPercent,
      sizeMb: sizeMb ?? this.sizeMb,
      status: status ?? this.status,
      content: content ?? this.content,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      updatedAt: updatedAt ?? this.updatedAt,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      transferSpeedMbps: transferSpeedMbps ?? this.transferSpeedMbps,
      estimatedRemainingSeconds: estimatedRemainingSeconds ?? this.estimatedRemainingSeconds,
      localFilePath: identical(localFilePath, _unset)
          ? this.localFilePath
          : localFilePath as String?,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        contentId,
        contentType,
        progressPercent,
        sizeMb,
        status,
        content,
        errorMessage,
        updatedAt,
        downloadedBytes,
        totalBytes,
        transferSpeedMbps,
        estimatedRemainingSeconds,
        localFilePath,
      ];
}
