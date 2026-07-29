import 'package:cineva_models/cineva_models.dart';

abstract final class CatalogSimilaritySupport {
  static List<ContentTileModel> findSimilar({
    required String baseId,
    required List<ContentTileModel> contents,
  }) {
    ContentTileModel? current;
    for (final item in contents) {
      if (item.id == baseId) {
        current = item;
        break;
      }
    }
    if (current == null) return const <ContentTileModel>[];
    final ContentTileModel resolvedCurrent = current;

    return contents
        .where((item) => item.id != resolvedCurrent.id)
        .where((item) {
          final sameType = item.contentType == resolvedCurrent.contentType;
          final overlap = item.genres.toSet().intersection(resolvedCurrent.genres.toSet()).isNotEmpty;
          return sameType || overlap;
        })
        .take(8)
        .toList();
  }
}
