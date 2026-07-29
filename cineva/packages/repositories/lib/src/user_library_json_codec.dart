import 'package:cineva_models/cineva_models.dart';

abstract final class UserLibraryJsonCodec {
  static PlaybackProgressModel progressFromJson(Map<String, dynamic> json) {
    return PlaybackProgressModel(
      contentId: json['contentId'] as String,
      contentType: json['contentType'] as String,
      positionSeconds: json['positionSeconds'] as int? ?? 0,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      content: tileFromJson(Map<String, dynamic>.from((json['content'] as Map?) ?? const <String, dynamic>{})),
    );
  }

  static Map<String, dynamic> progressToJson(PlaybackProgressModel model) {
    return <String, dynamic>{
      'contentId': model.contentId,
      'contentType': model.contentType,
      'positionSeconds': model.positionSeconds,
      'durationSeconds': model.durationSeconds,
      'updatedAt': model.updatedAt.toIso8601String(),
      'content': tileToJson(model.content),
    };
  }

  static DownloadItemModel downloadFromJson(Map<String, dynamic> json) {
    return DownloadItemModel(
      contentId: json['contentId'] as String,
      contentType: json['contentType'] as String,
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0,
      sizeMb: (json['sizeMb'] as num?)?.toDouble() ?? 0,
      status: statusFromString(json['status'] as String? ?? 'queued'),
      content: tileFromJson(Map<String, dynamic>.from((json['content'] as Map?) ?? const <String, dynamic>{})),
      errorMessage: json['errorMessage'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      transferSpeedMbps: (json['transferSpeedMbps'] as num?)?.toDouble(),
      estimatedRemainingSeconds: json['estimatedRemainingSeconds'] as int?,
      localFilePath: json['localFilePath'] as String?,
    );
  }

  static Map<String, dynamic> downloadToJson(DownloadItemModel item) {
    return <String, dynamic>{
      'contentId': item.contentId,
      'contentType': item.contentType,
      'progressPercent': item.progressPercent,
      'sizeMb': item.sizeMb,
      'status': item.status.name,
      'content': tileToJson(item.content),
      'errorMessage': item.errorMessage,
      'updatedAt': (item.updatedAt ?? DateTime.now()).toIso8601String(),
      'downloadedBytes': item.downloadedBytes,
      'totalBytes': item.totalBytes,
      'transferSpeedMbps': item.transferSpeedMbps,
      'estimatedRemainingSeconds': item.estimatedRemainingSeconds,
      'localFilePath': item.localFilePath,
    };
  }

  static ContentTileModel tileFromJson(Map<String, dynamic> json) {
    return ContentTileModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      badge: json['badge'] as String,
      contentType: json['contentType'] as String,
      imagePath: json['imagePath'] as String?,
      backdropPath: json['backdropPath'] as String?,
      description: json['description'] as String?,
      directorName: json['directorName'] as String?,
      year: json['year'] as int?,
      durationMinutes: json['durationMinutes'] as int?,
      ageRating: json['ageRating'] as String?,
      progressPercent: (json['progressPercent'] as num?)?.toDouble(),
      isFeatured: json['isFeatured'] as bool? ?? false,
      genres: (json['genres'] as List<dynamic>? ?? const <dynamic>[]).map((e) => '$e').toList(),
      castNames: (json['castNames'] as List<dynamic>? ?? const <dynamic>[]).map((e) => '$e').toList(),
    );
  }

  static Map<String, dynamic> tileToJson(ContentTileModel tile) {
    return <String, dynamic>{
      'id': tile.id,
      'title': tile.title,
      'subtitle': tile.subtitle,
      'badge': tile.badge,
      'contentType': tile.contentType,
      'imagePath': tile.imagePath,
      'backdropPath': tile.backdropPath,
      'description': tile.description,
      'directorName': tile.directorName,
      'year': tile.year,
      'durationMinutes': tile.durationMinutes,
      'ageRating': tile.ageRating,
      'progressPercent': tile.progressPercent,
      'isFeatured': tile.isFeatured,
      'genres': tile.genres,
      'castNames': tile.castNames,
    };
  }

  static DownloadStatus statusFromString(String raw) {
    for (final status in DownloadStatus.values) {
      if (status.name == raw) {
        return status;
      }
    }
    return DownloadStatus.queued;
  }
}
