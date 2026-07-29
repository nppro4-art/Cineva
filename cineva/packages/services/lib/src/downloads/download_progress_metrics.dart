class DownloadProgressMetrics {
  const DownloadProgressMetrics({
    required this.progressPercent,
    required this.transferSpeedMbps,
    required this.estimatedRemainingSeconds,
  });

  final double progressPercent;
  final double? transferSpeedMbps;
  final int? estimatedRemainingSeconds;

  static DownloadProgressMetrics calculate({
    required int downloadedBytes,
    required int totalBytes,
    required int initialBytes,
    required Duration elapsed,
  }) {
    final elapsedSeconds = elapsed.inMilliseconds / 1000;
    final speedBytesPerSecond = elapsedSeconds <= 0 ? 0.0 : (downloadedBytes - initialBytes) / elapsedSeconds;
    final remainingBytes = totalBytes > 0 ? totalBytes - downloadedBytes : 0;
    final remainingSeconds = speedBytesPerSecond > 0 ? (remainingBytes / speedBytesPerSecond).round() : null;

    return DownloadProgressMetrics(
      progressPercent: totalBytes == 0 ? 0 : downloadedBytes / totalBytes,
      transferSpeedMbps: speedBytesPerSecond <= 0 ? null : (speedBytesPerSecond * 8) / 1000000,
      estimatedRemainingSeconds: remainingSeconds,
    );
  }
}
