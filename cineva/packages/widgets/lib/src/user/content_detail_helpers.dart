import 'dart:math';

import 'package:cineva_models/cineva_models.dart';
import 'package:flutter/material.dart';

abstract final class ContentDetailHelpers {
  static PlaybackProgressModel? latestSeriesProgress(
    ContentDetailModel detail,
    Iterable<PlaybackProgressModel> continueWatching,
  ) {
    final episodeIds = detail.seasons.expand((season) => season.episodes).map((episode) => episode.id).toSet();
    final seriesProgress = continueWatching.where((item) => episodeIds.contains(item.content.id)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return seriesProgress.isEmpty ? null : seriesProgress.first;
  }

  static EpisodeModel? pickRandomEpisode(ContentDetailModel detail, {Random? random}) {
    final episodes = detail.seasons.expand((season) => season.episodes).toList();
    if (episodes.isEmpty) return null;
    final picker = random ?? Random();
    return episodes[picker.nextInt(episodes.length)];
  }

  static String downloadLabel(DownloadItemModel? item) {
    if (item == null) return 'Télécharger';
    return switch (item.status) {
      DownloadStatus.queued => 'Préparation...',
      DownloadStatus.downloading => 'Pause (${(item.progressPercent * 100).round()}%)',
      DownloadStatus.paused => 'Reprendre (${(item.progressPercent * 100).round()}%)',
      DownloadStatus.completed => 'Supprimer le téléchargement',
      DownloadStatus.failed => 'Relancer le téléchargement',
      DownloadStatus.deleted => 'Télécharger',
    };
  }

  static IconData downloadIcon(DownloadItemModel? item) {
    if (item == null) return Icons.download_rounded;
    return switch (item.status) {
      DownloadStatus.queued => Icons.downloading_rounded,
      DownloadStatus.downloading => Icons.pause_rounded,
      DownloadStatus.paused => Icons.play_arrow_rounded,
      DownloadStatus.completed => Icons.delete_outline_rounded,
      DownloadStatus.failed => Icons.refresh_rounded,
      DownloadStatus.deleted => Icons.download_rounded,
    };
  }
}

abstract final class ContentDetailLayout {
  static bool isWide(double maxWidth) => maxWidth >= 920;

  static double posterWidth(double maxWidth) => isWide(maxWidth) ? 260 : 190;
}
