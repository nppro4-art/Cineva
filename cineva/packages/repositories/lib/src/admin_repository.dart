import 'dart:typed_data';

import 'package:cineva_models/cineva_models.dart';

import 'tmdb/tmdb_client.dart';

abstract interface class AdminRepository {
  Future<AdminDashboardSummary> fetchDashboardSummary();

  Future<List<AppUser>> fetchUsers({
    String query = '',
    AdminUserFilter filter = AdminUserFilter.all,
  });

  Future<void> createUser({
    required String email,
    required String password,
    required String fullName,
    String role = 'user',
    DateTime? expiresAt,
  });

  Future<void> updateUserProfile({
    required String userId,
    required String email,
    required String fullName,
    required String role,
    required String status,
    DateTime? expiresAt,
  });

  Future<void> deleteUser(String userId);

  Future<void> resetPassword({required String email});

  Future<void> addMonths({
    required String userId,
    required int months,
    String? note,
  });

  Future<void> setExpiration({
    required String userId,
    required DateTime expiresAt,
    String? note,
  });

  Future<void> suspendUser({required String userId, String? note});

  Future<void> reactivateUser({required String userId, String? note});

  Future<List<DeviceModel>> fetchUserDevices(String userId);

  Future<void> removeUserDevice(String deviceId);

  Future<void> disconnectAllDevices(String userId);

  Future<List<AdminNotificationModel>> fetchNotifications();

  Future<void> createNotification({
    required String title,
    required String body,
    String? userId,
    DateTime? scheduledAt,
    String channel = 'general',
    String? contentId,
    String? screen,
  });

  Future<List<AdminWatchStatModel>> fetchTopWatchStats();

  Future<List<AdminCategoryModel>> fetchCategories();

  Future<AdminCategoryModel> upsertCategory({
    String? id,
    required String name,
    required String slug,
    required String categoryType,
  });

  Future<void> deleteCategory(String id);

  Future<List<AdminCatalogItemModel>> fetchMovies({String query = ''});

  Future<List<AdminCatalogItemModel>> fetchSeries({String query = ''});

  Future<AdminCatalogItemModel> saveMovie(AdminCatalogItemModel movie);

  Future<AdminCatalogItemModel> saveSeries(AdminCatalogItemModel series);

  Future<void> deleteMovie(String id);

  Future<void> deleteSeries(String id);

  Future<List<SeasonModel>> fetchSeasons(String seriesId);

  Future<SeasonModel> saveSeason({
    String? id,
    required String seriesId,
    required int seasonNumber,
    required String title,
    String? synopsis,
    String? posterPath,
  });

  Future<void> deleteSeason(String seasonId);

  Future<List<EpisodeModel>> fetchEpisodes(String seasonId, {String? seriesId, int? seasonNumber});

  Future<EpisodeModel> saveEpisode(EpisodeModel episode);

  Future<void> deleteEpisode(String episodeId);

  Future<String> uploadMedia({
    required String bucket,
    required String filename,
    required Uint8List bytes,
    required String contentType,
  });

  Future<List<AdminHomeSectionModel>> fetchHomeSections();

  Future<AdminHomeSectionModel> saveHomeSection(AdminHomeSectionModel section);

  Future<void> deleteHomeSection(String id);

  Future<void> replaceHomeSectionItems({
    required String homeSectionId,
    required List<AdminHomeSectionItemModel> items,
  });

  /// Récupère la fiche TMDB (métadonnées publiques) pour pré-remplir
  /// l'éditeur de catalogue. Ne crée aucun enregistrement : l'administrateur
  /// valide ensuite l'enregistrement dans l'éditeur.
  Future<TmdbContentDraft> fetchTmdbDraft(TmdbReference reference);

  /// Cherche des titres TMDB correspondant à [query] (films par défaut).
  ///
  /// Sert à l'import par URL vidéo : le nom du fichier donne la piste de
  /// recherche, l'administrateur choisit la fiche parmi les candidats.
  Future<List<TmdbSearchHit>> searchTmdbTitles({
    required String query,
    TmdbMediaType mediaType = TmdbMediaType.movie,
    int? year,
    int limit = 12,
  });
}
