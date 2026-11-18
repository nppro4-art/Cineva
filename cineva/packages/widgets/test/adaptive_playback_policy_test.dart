import 'package:flutter_test/flutter_test.dart';
import 'package:cineva_widgets/src/player/adaptive_playback_policy.dart';
import 'package:cineva_widgets/src/player/media_source_resolver.dart';
import 'package:cineva_widgets/src/player/media_source_ranking.dart';

MediaSourceCandidate rendition(String id, int bitrate, int quality) =>
    MediaSourceCandidate(
      id: id,
      source: MediaSourceResolver.resolve('https://cdn.example.com/$id.m3u8'),
      bitrateKbps: bitrate,
      qualityRank: quality,
    );

void main() {
  group('AdaptivePlaybackPolicy', () {
    test('uses an EWMA throughput estimate', () {
      final policy = AdaptivePlaybackPolicy(smoothingFactor: 0.5);
      policy.addThroughputSample(
        bytesDownloaded: 500000,
        elapsed: const Duration(seconds: 1),
      );
      policy.addThroughputSample(
        bytesDownloaded: 250000,
        elapsed: const Duration(seconds: 1),
      );
      expect(policy.estimatedThroughputKbps, 3000);
    });

    test('requires stable samples before an upshift', () {
      final policy = AdaptivePlaybackPolicy(
        smoothingFactor: 1,
        upshiftConfirmationSamples: 2,
      );
      final options = [
        rendition('low', 200, 1),
        rendition('high', 900, 2),
      ];
      policy.addThroughputSample(
        bytesDownloaded: 50000,
        elapsed: const Duration(seconds: 1),
      );
      expect(policy.choose(candidates: options)?.id, 'low');

      policy.addThroughputSample(
        bytesDownloaded: 1000000,
        elapsed: const Duration(seconds: 1),
      );
      expect(policy.choose(candidates: options), isNull);
      expect(policy.choose(candidates: options)?.id, 'high');
    });

    test('does not produce a decision without throughput samples', () {
      final policy = AdaptivePlaybackPolicy();
      expect(policy.choose(candidates: [rendition('low', 300, 1)]), isNull);
    });

    test('ignores invalid throughput samples', () {
      final policy = AdaptivePlaybackPolicy();
      policy.addThroughputSample(
        bytesDownloaded: 0,
        elapsed: const Duration(seconds: 1),
      );
      expect(policy.estimatedThroughputKbps, isNull);
    });
  });
}
