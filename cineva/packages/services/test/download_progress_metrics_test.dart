import 'package:cineva_services/src/downloads/download_progress_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates progress, speed and eta from transfer snapshot', () {
    final metrics = DownloadProgressMetrics.calculate(
      downloadedBytes: 600,
      totalBytes: 1000,
      initialBytes: 100,
      elapsed: const Duration(seconds: 5),
    );

    expect(metrics.progressPercent, 0.6);
    expect(metrics.transferSpeedMbps, closeTo(0.0008, 0.00001));
    expect(metrics.estimatedRemainingSeconds, 2);
  });

  test('keeps eta null when speed cannot be estimated yet', () {
    final metrics = DownloadProgressMetrics.calculate(
      downloadedBytes: 0,
      totalBytes: 1000,
      initialBytes: 0,
      elapsed: Duration.zero,
    );

    expect(metrics.progressPercent, 0);
    expect(metrics.transferSpeedMbps, isNull);
    expect(metrics.estimatedRemainingSeconds, isNull);
  });
}
