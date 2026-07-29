import 'package:cineva_models/cineva_models.dart';

abstract interface class CatalogRepository {
  Future<List<HomeSectionModel>> fetchHomeSections();

  Future<ContentDetailModel?> fetchContentDetail(String contentId);

  Future<List<ContentTileModel>> fetchSimilarContent(String contentId);

  Future<List<SearchResultModel>> search(
    String query, {
    SearchFilter filter = SearchFilter.all,
  });

  Future<List<SearchSuggestionModel>> fetchSearchSuggestions({
    String query = '',
    SearchFilter filter = SearchFilter.all,
  });
}
