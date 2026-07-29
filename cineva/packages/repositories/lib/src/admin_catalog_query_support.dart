import 'package:cineva_models/cineva_models.dart';

abstract final class AdminCatalogQuerySupport {
  static bool matches(AdminCatalogItemModel item, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return '${item.title} ${item.directorName ?? ''}'.toLowerCase().contains(normalized);
  }
}
