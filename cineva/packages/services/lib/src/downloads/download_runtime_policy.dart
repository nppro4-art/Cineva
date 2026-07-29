import 'package:cineva_models/cineva_models.dart';

abstract final class DownloadRuntimePolicy {
  static DownloadItemModel normalizeLocalAvailability(
    DownloadItemModel item, {
    required bool fileExists,
  }) {
    if (item.canPlayOffline && !fileExists) {
      return item.copyWith(
        status: DownloadStatus.failed,
        errorMessage: 'Fichier local introuvable. Relancez le téléchargement.',
        localFilePath: null,
        updatedAt: DateTime.now(),
      );
    }
    return item;
  }

  static bool shouldResumeOnStartup(DownloadItemModel item) {
    return item.status == DownloadStatus.downloading || item.status == DownloadStatus.queued;
  }

  static bool treatCancelAsDeletion(String reason) {
    return reason.toLowerCase().contains('deleted');
  }

  static VideoQualityPreset preferredQuality(
    ContentDetailModel detail, {
    VideoQualityPreset? preferred,
  }) {
    final resolved = detail.resolveDownloadQuality(preferred)?.preset;
    if (resolved != null) return resolved;
    if (preferred != null) return preferred;

    final candidates = detail.availableQualities
        .where((option) => option.available)
        .where((option) => option.preset != VideoQualityPreset.auto)
        .toList();

    if (candidates.isEmpty) return VideoQualityPreset.auto;
    candidates.sort((a, b) => a.bitrateMbps.compareTo(b.bitrateMbps));
    return candidates.last.preset;
  }
}
