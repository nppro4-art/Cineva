part of 'catalog_screen.dart';

Future<void> _showMovieEditor(
  BuildContext context,
  WidgetRef ref,
  List<AdminCategoryModel> categories, {
  AdminCatalogItemModel? movie,
}) async {
  await _showCatalogEditor(
    context,
    ref,
    categories,
    contentType: 'movie',
    existing: movie,
  );
}

Future<void> _showSeriesEditor(
  BuildContext context,
  WidgetRef ref,
  List<AdminCategoryModel> categories, {
  AdminCatalogItemModel? series,
}) async {
  await _showCatalogEditor(
    context,
    ref,
    categories,
    contentType: 'series',
    existing: series,
  );
}
