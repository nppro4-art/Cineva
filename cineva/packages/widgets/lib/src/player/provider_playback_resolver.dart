import 'package:cineva_services/cineva_services.dart';

import 'media_source_resolver.dart';
import 'media_source_ranking.dart';

/// Bridges add-on/provider results into the playback engine's source model.
/// Provider-specific response formats stop at this boundary.
class CinevaProviderPlaybackResolver {
  const CinevaProviderPlaybackResolver({
    required this.registry,
    this.ranking = const MediaSourceRanking(),
  });

  final CinevaMediaProviderRegistry registry;
  final MediaSourceRanking ranking;

  Future<List<MediaSourceCandidate>> resolve(
    String contentId, {
    int? availableBandwidthKbps,
  }) async {
    final providerSources = await registry.resolve(contentId);
    final candidates = providerSources.map((source) {
      final mediaSource = MediaSourceResolver.resolve(
        source.url.toString(),
        mimeType: source.mimeType,
      );
      final bitrate = source.bitrateKbps;
      return MediaSourceCandidate(
        id: '${source.providerId}:${source.id}',
        source: mediaSource,
        origin: MediaSourceOrigin.addon,
        providerId: source.providerId,
        bitrateKbps: bitrate,
        qualityRank: _qualityRank(source.qualityLabel, bitrate),
      );
    });
    return ranking.rank(
      candidates,
      availableBandwidthKbps: availableBandwidthKbps,
    );
  }

  int _qualityRank(String? label, int? bitrateKbps) {
    final normalized = label?.toLowerCase() ?? '';
    final match = RegExp(r'(2160|1440|1080|720|480|360)').firstMatch(normalized);
    if (match != null) return int.parse(match.group(1)!);
    return bitrateKbps ?? 0;
  }
}
