import 'package:flutter_test/flutter_test.dart';
import 'package:cineva_widgets/src/player/media_source_resolver.dart';
import 'package:cineva_widgets/src/player/media_source_ranking.dart';

void main() {
  MediaSourceCandidate candidate(
    String id, {
    int quality = 0,
    int? bitrate,
    int? latency,
    int failures = 0,
    bool available = true,
    bool supported = true,
  }) {
    return MediaSourceCandidate(
      id: id,
      source: MediaSourceResolver.resolve('https://cdn.example.com/$id.m3u8'),
      qualityRank: quality,
      bitrateKbps: bitrate,
      startupLatencyMs: latency,
      failureCount: failures,
      isAvailable: available,
      supportedOnPlatform: supported,
    );
  }

  group('MediaSourceRanking', () {
    const ranking = MediaSourceRanking();

    test('filters unavailable, unsupported and repeatedly failing sources', () {
      final result = ranking.rank([
        candidate('good'),
        candidate('offline', available: false),
        candidate('unsupported', supported: false),
        candidate('broken', failures: 4),
      ]);

      expect(result.map((item) => item.id), ['good']);
    });

    test('respects the safe bandwidth budget', () {
      final result = ranking.rank([
        candidate('1080p', quality: 3, bitrate: 6000),
        candidate('720p', quality: 2, bitrate: 3000),
        candidate('480p', quality: 1, bitrate: 1200),
      ], availableBandwidthKbps: 4000);

      expect(result.map((item) => item.id), ['720p', '480p']);
    });

    test('prefers reliability, then startup latency, then quality', () {
      final result = ranking.rank([
        candidate('high-quality', quality: 3, latency: 900),
        candidate('fast', quality: 1, latency: 100),
        candidate('unreliable', quality: 4, latency: 50, failures: 1),
      ]);

      expect(result.map((item) => item.id),
          ['fast', 'high-quality', 'unreliable']);
    });

    test('returns null when no candidate fits the bandwidth budget', () {
      expect(
        ranking.selectBest(
          [candidate('4k', bitrate: 12000)],
          availableBandwidthKbps: 3000,
        ),
        isNull,
      );
    });
  });
}
