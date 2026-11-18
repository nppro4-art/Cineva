import 'media_source_resolver.dart';

/// Describes where a playable source came from without coupling Cineva to a
/// particular add-on or provider implementation.
enum MediaSourceOrigin {
  firstParty,
  addon,
  catalogProvider,
  userProvided,
  offline,
}

/// Runtime facts used to rank sources. Unknown values are deliberately
/// represented as null rather than guessed.
class MediaSourceCandidate {
  const MediaSourceCandidate({
    required this.id,
    required this.source,
    this.origin = MediaSourceOrigin.firstParty,
    this.providerId,
    this.qualityRank = 0,
    this.bitrateKbps,
    this.measuredThroughputKbps,
    this.startupLatencyMs,
    this.failureCount = 0,
    this.isAvailable = true,
    this.isDrmProtected = false,
    this.supportedOnPlatform = true,
  });

  final String id;
  final MediaSource source;
  final MediaSourceOrigin origin;
  final String? providerId;
  /// Relative quality rank supplied by the provider (higher is better).
  final int qualityRank;
  final int? bitrateKbps;
  final int? measuredThroughputKbps;
  final int? startupLatencyMs;
  final int failureCount;
  final bool isAvailable;
  final bool isDrmProtected;
  final bool supportedOnPlatform;

  bool get isEligible =>
      isAvailable && supportedOnPlatform && source.value.trim().isNotEmpty;
}

/// A stable, deterministic source ordering policy. It favours playable,
/// reliable sources and avoids selecting a bitrate above measured capacity.
class MediaSourceRanking {
  const MediaSourceRanking({
    this.bandwidthSafetyFactor = 0.75,
    this.maximumFailureCount = 3,
  })  : assert(bandwidthSafetyFactor > 0 && bandwidthSafetyFactor <= 1),
        assert(maximumFailureCount >= 0);

  final double bandwidthSafetyFactor;
  final int maximumFailureCount;

  List<MediaSourceCandidate> rank(
    Iterable<MediaSourceCandidate> candidates, {
    int? availableBandwidthKbps,
  }) {
    final eligible = candidates.where((candidate) {
      if (!candidate.isEligible ||
          candidate.failureCount > maximumFailureCount) {
        return false;
      }
      if (availableBandwidthKbps != null &&
          candidate.bitrateKbps != null &&
          candidate.bitrateKbps! >
              availableBandwidthKbps * bandwidthSafetyFactor) {
        return false;
      }
      return true;
    }).toList();

    eligible.sort((a, b) {
      final reliability = a.failureCount.compareTo(b.failureCount);
      if (reliability != 0) return reliability;

      final latency = (a.startupLatencyMs ?? 1 << 30)
          .compareTo(b.startupLatencyMs ?? 1 << 30);
      if (latency != 0) return latency;

      final quality = b.qualityRank.compareTo(a.qualityRank);
      if (quality != 0) return quality;

      final bitrate = (b.bitrateKbps ?? 0).compareTo(a.bitrateKbps ?? 0);
      if (bitrate != 0) return bitrate;

      return a.id.compareTo(b.id);
    });
    return List<MediaSourceCandidate>.unmodifiable(eligible);
  }

  /// Picks the highest quality rendition that remains below the safe
  /// throughput budget. Returns null when no candidate is eligible.
  MediaSourceCandidate? selectBest(
    Iterable<MediaSourceCandidate> candidates, {
    required int availableBandwidthKbps,
  }) {
    final ranked = rank(
      candidates,
      availableBandwidthKbps: availableBandwidthKbps,
    );
    return ranked.isEmpty ? null : ranked.first;
  }
}
