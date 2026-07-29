import 'package:equatable/equatable.dart';

import 'content_tile_model.dart';

class PlaybackProgressModel extends Equatable {
  const PlaybackProgressModel({
    required this.contentId,
    required this.contentType,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.updatedAt,
    required this.content,
  });

  final String contentId;
  final String contentType;
  final int positionSeconds;
  final int durationSeconds;
  final DateTime updatedAt;
  final ContentTileModel content;

  double get progressPercent {
    if (durationSeconds <= 0) return 0;
    final ratio = positionSeconds / durationSeconds;
    if (ratio < 0) return 0;
    if (ratio > 1) return 1;
    return ratio;
  }

  bool get isCompleted => progressPercent >= 0.97;

  PlaybackProgressModel copyWith({
    int? positionSeconds,
    int? durationSeconds,
    DateTime? updatedAt,
    ContentTileModel? content,
  }) {
    return PlaybackProgressModel(
      contentId: contentId,
      contentType: contentType,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
      content: content ?? this.content,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        contentId,
        contentType,
        positionSeconds,
        durationSeconds,
        updatedAt,
        content,
      ];
}
