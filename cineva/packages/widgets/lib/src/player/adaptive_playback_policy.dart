import 'media_source_ranking.dart';

/// Estimates sustainable network throughput and applies conservative
/// adaptation rules. Feed completed segment throughput samples in Kbps.
class AdaptivePlaybackPolicy {
  AdaptivePlaybackPolicy({
    this.smoothingFactor = 0.25,
    this.safetyFactor = 0.75,
    this.upshiftConfirmationSamples = 3,
  })  : assert(smoothingFactor > 0 && smoothingFactor <= 1),
        assert(safetyFactor > 0 && safetyFactor <= 1),
        assert(upshiftConfirmationSamples >= 1);

  final double smoothingFactor;
  final double safetyFactor;
  final int upshiftConfirmationSamples;

  double? _estimatedThroughputKbps;
  String? _currentCandidateId;
  String? _pendingUpshiftId;
  int _pendingUpshiftSamples = 0;

  double? get estimatedThroughputKbps => _estimatedThroughputKbps;
  String? get currentCandidateId => _currentCandidateId;

  void addThroughputSample({
    required int bytesDownloaded,
    required Duration elapsed,
  }) {
    if (bytesDownloaded <= 0 || elapsed <= Duration.zero) return;
    final sampleKbps = bytesDownloaded * 8 / elapsed.inMilliseconds;
    if (!sampleKbps.isFinite || sampleKbps <= 0) return;
    _estimatedThroughputKbps = _estimatedThroughputKbps == null
        ? sampleKbps
        : smoothingFactor * sampleKbps +
            (1 - smoothingFactor) * _estimatedThroughputKbps!;
  }

  /// Returns a candidate only when a switch is justified. Downshifts are
  /// immediate to protect playback continuity; upshifts require repeated
  /// observations to prevent quality oscillation.
  MediaSourceCandidate? choose({
    required Iterable<MediaSourceCandidate> candidates,
  }) {
    final estimate = _estimatedThroughputKbps;
    if (estimate == null) return null;
    final safeBudget = (estimate * safetyFactor).floor();
    final eligible = MediaSourceRanking(
      bandwidthSafetyFactor: 1,
    ).rank(candidates, availableBandwidthKbps: safeBudget);
    if (eligible.isEmpty) return null;

    final current = eligible.where((item) => item.id == _currentCandidateId);
    final best = eligible.first;
    final currentCandidate = current.isEmpty ? null : current.first;

    if (currentCandidate == null) {
      _setCurrent(best);
      return best;
    }
    if (best.id == currentCandidate.id) {
      _pendingUpshiftId = null;
      _pendingUpshiftSamples = 0;
      return null;
    }

    final bestBitrate = best.bitrateKbps ?? 0;
    final currentBitrate = currentCandidate.bitrateKbps ?? 0;
    if (bestBitrate < currentBitrate) {
      _setCurrent(best);
      return best;
    }

    if (_pendingUpshiftId == best.id) {
      _pendingUpshiftSamples += 1;
    } else {
      _pendingUpshiftId = best.id;
      _pendingUpshiftSamples = 1;
    }
    if (_pendingUpshiftSamples < upshiftConfirmationSamples) return null;

    _setCurrent(best);
    return best;
  }

  void reset() {
    _estimatedThroughputKbps = null;
    _currentCandidateId = null;
    _pendingUpshiftId = null;
    _pendingUpshiftSamples = 0;
  }

  void _setCurrent(MediaSourceCandidate candidate) {
    _currentCandidateId = candidate.id;
    _pendingUpshiftId = null;
    _pendingUpshiftSamples = 0;
  }
}
