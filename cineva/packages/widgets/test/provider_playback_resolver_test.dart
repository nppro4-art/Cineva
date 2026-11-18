import 'package:flutter_test/flutter_test.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:cineva_widgets/src/player/media_source_resolver.dart';
import 'package:cineva_widgets/src/player/media_source_ranking.dart';
import 'package:cineva_widgets/src/player/provider_playback_resolver.dart';

class SourceProvider implements CinevaMediaProvider {
  @override
  String get id => 'addon';
  @override
  String get displayName => 'Addon';

  @override
  Future<List<CinevaProviderItem>> search(String query) async => [];

  @override
  Future<List<CinevaProviderItem>> catalog({
    String? catalogId,
    String? genre,
    int page = 1,
  }) async => [];

  @override
  Future<List<CinevaProviderSource>> resolve(String contentId) async => [
        const CinevaProviderSource(
          id: 'hd',
          providerId: 'addon',
          url: 'https://cdn.example.com/hd',
          mimeType: 'application/vnd.apple.mpegurl',
          qualityLabel: '1080p',
          bitrateKbps: 5000,
        ),
        const CinevaProviderSource(
          id: 'sd',
          providerId: 'addon',
          url: 'https://cdn.example.com/sd.mp4',
          qualityLabel: '480p',
          bitrateKbps: 1200,
        ),
      ];
}

void main() {
  test('maps provider streams into ranked playback candidates', () async {
    final resolver = CinevaProviderPlaybackResolver(
      registry: CinevaMediaProviderRegistry([SourceProvider()]),
    );
    final candidates = await resolver.resolve('content');
    expect(candidates, hasLength(2));
    expect(candidates.first.id, 'addon:hd');
    expect(candidates.first.source.type, MediaSourceType.hls);
    expect(candidates.first.origin, MediaSourceOrigin.addon);
    expect(candidates.first.qualityRank, 1080);
  });

  test('applies bandwidth constraints before returning candidates', () async {
    final resolver = CinevaProviderPlaybackResolver(
      registry: CinevaMediaProviderRegistry([SourceProvider()]),
      ranking: const MediaSourceRanking(),
    );
    final candidates = await resolver.resolve(
      'content',
      availableBandwidthKbps: 2000,
    );
    expect(candidates.map((candidate) => candidate.id), ['addon:sd']);
  });
}
