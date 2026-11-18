/// Provider contract for Cineva's optional catalogue and playback-source
/// integrations. Implementations can wrap first-party APIs or third-party
/// add-ons; the player and existing repositories remain independent.
abstract interface class CinevaMediaProvider {
  String get id;
  String get displayName;

  Future<List<CinevaProviderItem>> search(String query);

  Future<List<CinevaProviderItem>> catalog({
    String? catalogId,
    String? genre,
    int page = 1,
  });

  Future<List<CinevaProviderSource>> resolve(String contentId);
}

class CinevaProviderItem {
  const CinevaProviderItem({
    required this.id,
    required this.title,
    required this.providerId,
    this.description,
    this.posterUrl,
    this.backdropUrl,
    this.releaseYear,
    this.genres = const <String>[],
    this.rating,
    this.externalIds = const <String, String>{},
  });

  /// Stable provider-qualified identity (for example providerId:itemId).
  final String id;
  final String title;
  final String providerId;
  final String? description;
  final String? posterUrl;
  final String? backdropUrl;
  final int? releaseYear;
  final List<String> genres;
  final double? rating;
  final Map<String, String> externalIds;
}

class CinevaProviderSource {
  const CinevaProviderSource({
    required this.id,
    required this.providerId,
    required this.url,
    this.mimeType,
    this.qualityLabel,
    this.bitrateKbps,
    this.headers = const <String, String>{},
    this.isDefault = false,
  });

  final String id;
  final String providerId;
  final Uri url;
  final String? mimeType;
  final String? qualityLabel;
  final int? bitrateKbps;
  final Map<String, String> headers;
  final bool isDefault;
}

/// Aggregates providers without allowing a single faulty add-on to break
/// Cineva's first-party catalogue or search experience.
class CinevaMediaProviderRegistry {
  CinevaMediaProviderRegistry(Iterable<CinevaMediaProvider> providers)
      : _providers = List<CinevaMediaProvider>.unmodifiable(providers);

  final List<CinevaMediaProvider> _providers;

  List<CinevaMediaProvider> get providers => _providers;

  Future<List<CinevaProviderItem>> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const <CinevaProviderItem>[];
    final batches = await Future.wait(
      _providers.map((provider) async {
        try {
          return await provider.search(normalized);
        } catch (_) {
          return const <CinevaProviderItem>[];
        }
      }),
    );
    return _deduplicate(batches.expand((items) => items));
  }

  Future<List<CinevaProviderItem>> catalog({
    String? catalogId,
    String? genre,
    int page = 1,
  }) async {
    if (page < 1) throw ArgumentError.value(page, 'page', 'Must be >= 1');
    final batches = await Future.wait(
      _providers.map((provider) async {
        try {
          return await provider.catalog(
            catalogId: catalogId,
            genre: genre,
            page: page,
          );
        } catch (_) {
          return const <CinevaProviderItem>[];
        }
      }),
    );
    return _deduplicate(batches.expand((items) => items));
  }

  Future<List<CinevaProviderSource>> resolve(String contentId) async {
    final normalized = contentId.trim();
    if (normalized.isEmpty) return const <CinevaProviderSource>[];
    final batches = await Future.wait(
      _providers.map((provider) async {
        try {
          return await provider.resolve(normalized);
        } catch (_) {
          return const <CinevaProviderSource>[];
        }
      }),
    );
    final seen = <String>{};
    return List<CinevaProviderSource>.unmodifiable(
      batches.expand((items) => items).where((source) {
        if (source.url.scheme != 'https' && source.url.scheme != 'http') {
          return false;
        }
        return seen.add('${source.providerId}:${source.id}');
      }),
    );
  }

  List<CinevaProviderItem> _deduplicate(
    Iterable<CinevaProviderItem> items,
  ) {
    final byIdentity = <String, CinevaProviderItem>{};
    for (final item in items) {
      final key = item.id.trim().isNotEmpty
          ? item.id.trim()
          : '${item.providerId}:${item.title.trim().toLowerCase()}';
      if (key.isNotEmpty) byIdentity.putIfAbsent(key, () => item);
    }
    return List<CinevaProviderItem>.unmodifiable(byIdentity.values);
  }
}
