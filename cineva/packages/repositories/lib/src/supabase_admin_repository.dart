import 'dart:typed_data';

import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_services/cineva_services.dart';

import 'admin_catalog_repository.dart';
import 'admin_dashboard_repository.dart';
import 'admin_home_repository.dart';
import 'admin_notifications_repository.dart';
import 'admin_repository.dart';
import 'admin_supabase_gateway.dart';
import 'admin_users_repository.dart';

class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(BackendService backendService)
      : this._(AdminSupabaseGateway(backendService));

  SupabaseAdminRepository._(AdminSupabaseGateway gateway)
      : _dashboardRepository = SupabaseAdminDashboardRepository(gateway),
        _usersRepository = SupabaseAdminUsersRepository(gateway),
        _notificationsRepository = SupabaseAdminNotificationsRepository(gateway),
        _catalogRepository = SupabaseAdminCatalogRepository(gateway),
        _homeRepository = SupabaseAdminHomeRepository(gateway);

  final SupabaseAdminDashboardRepository _dashboardRepository;
  final SupabaseAdminUsersRepository _usersRepository;
  final SupabaseAdminNotificationsRepository _notificationsRepository;
  final SupabaseAdminCatalogRepository _catalogRepository;
  final SupabaseAdminHomeRepository _homeRepository;

  @override
  Future<void> addMonths({required String userId, required int months, String? note}) {
    return _usersRepository.addMonths(userId: userId, months: months, note: note);
  }

  @override
  Future<void> createNotification({required String title, required String body, String? userId, DateTime? scheduledAt, String channel = 'general', String? contentId, String? screen}) {
    return _notificationsRepository.createNotification(
      title: title,
      body: body,
      userId: userId,
      scheduledAt: scheduledAt,
      channel: channel,
      contentId: contentId,
      screen: screen,
    );
  }

  @override
  Future<void> createUser({required String email, required String password, required String fullName, String role = 'user', DateTime? expiresAt}) {
    return _usersRepository.createUser(
      email: email,
      password: password,
      fullName: fullName,
      role: role,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> deleteCategory(String id) => _catalogRepository.deleteCategory(id);

  @override
  Future<void> deleteEpisode(String episodeId) => _catalogRepository.deleteEpisode(episodeId);

  @override
  Future<void> deleteHomeSection(String id) => _homeRepository.deleteHomeSection(id);

  @override
  Future<void> deleteMovie(String id) => _catalogRepository.deleteMovie(id);

  @override
  Future<void> deleteSeason(String seasonId) => _catalogRepository.deleteSeason(seasonId);

  @override
  Future<void> deleteSeries(String id) => _catalogRepository.deleteSeries(id);

  @override
  Future<void> deleteUser(String userId) => _usersRepository.deleteUser(userId);

  @override
  Future<void> disconnectAllDevices(String userId) => _usersRepository.disconnectAllDevices(userId);

  @override
  Future<AdminDashboardSummary> fetchDashboardSummary() => _dashboardRepository.fetchDashboardSummary();

  @override
  Future<List<AdminCategoryModel>> fetchCategories() => _catalogRepository.fetchCategories();

  @override
  Future<List<EpisodeModel>> fetchEpisodes(String seasonId, {String? seriesId, int? seasonNumber}) {
    return _catalogRepository.fetchEpisodes(seasonId, seriesId: seriesId, seasonNumber: seasonNumber);
  }

  @override
  Future<List<AdminHomeSectionModel>> fetchHomeSections() => _homeRepository.fetchHomeSections();

  @override
  Future<List<AdminCatalogItemModel>> fetchMovies({String query = ''}) => _catalogRepository.fetchMovies(query: query);

  @override
  Future<List<AdminNotificationModel>> fetchNotifications() => _notificationsRepository.fetchNotifications();

  @override
  Future<List<SeasonModel>> fetchSeasons(String seriesId) => _catalogRepository.fetchSeasons(seriesId);

  @override
  Future<List<AdminCatalogItemModel>> fetchSeries({String query = ''}) => _catalogRepository.fetchSeries(query: query);

  @override
  Future<List<AdminWatchStatModel>> fetchTopWatchStats() => _dashboardRepository.fetchTopWatchStats();

  @override
  Future<List<DeviceModel>> fetchUserDevices(String userId) => _usersRepository.fetchUserDevices(userId);

  @override
  Future<List<AppUser>> fetchUsers({String query = '', AdminUserFilter filter = AdminUserFilter.all}) {
    return _usersRepository.fetchUsers(query: query, filter: filter);
  }

  @override
  Future<void> reactivateUser({required String userId, String? note}) => _usersRepository.reactivateUser(userId: userId, note: note);

  @override
  Future<void> removeUserDevice(String deviceId) => _usersRepository.removeUserDevice(deviceId);

  @override
  Future<void> replaceHomeSectionItems({required String homeSectionId, required List<AdminHomeSectionItemModel> items}) {
    return _homeRepository.replaceHomeSectionItems(homeSectionId: homeSectionId, items: items);
  }

  @override
  Future<void> resetPassword({required String email}) => _usersRepository.resetPassword(email: email);

  @override
  Future<AdminHomeSectionModel> saveHomeSection(AdminHomeSectionModel section) => _homeRepository.saveHomeSection(section);

  @override
  Future<EpisodeModel> saveEpisode(EpisodeModel episode) => _catalogRepository.saveEpisode(episode);

  @override
  Future<AdminCatalogItemModel> saveMovie(AdminCatalogItemModel movie) => _catalogRepository.saveMovie(movie);

  @override
  Future<SeasonModel> saveSeason({String? id, required String seriesId, required int seasonNumber, required String title, String? synopsis, String? posterPath}) {
    return _catalogRepository.saveSeason(
      id: id,
      seriesId: seriesId,
      seasonNumber: seasonNumber,
      title: title,
      synopsis: synopsis,
      posterPath: posterPath,
    );
  }

  @override
  Future<AdminCatalogItemModel> saveSeries(AdminCatalogItemModel series) => _catalogRepository.saveSeries(series);

  @override
  Future<void> setExpiration({required String userId, required DateTime expiresAt, String? note}) {
    return _usersRepository.setExpiration(userId: userId, expiresAt: expiresAt, note: note);
  }

  @override
  Future<void> suspendUser({required String userId, String? note}) => _usersRepository.suspendUser(userId: userId, note: note);

  @override
  Future<void> updateUserProfile({required String userId, required String email, required String fullName, required String role, required String status, DateTime? expiresAt}) {
    return _usersRepository.updateUserProfile(
      userId: userId,
      email: email,
      fullName: fullName,
      role: role,
      status: status,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<String> uploadMedia({required String bucket, required String filename, required Uint8List bytes, required String contentType}) {
    return _catalogRepository.uploadMedia(
      bucket: bucket,
      filename: filename,
      bytes: bytes,
      contentType: contentType,
    );
  }

  @override
  Future<AdminCategoryModel> upsertCategory({String? id, required String name, required String slug, required String categoryType}) {
    return _catalogRepository.upsertCategory(
      id: id,
      name: name,
      slug: slug,
      categoryType: categoryType,
    );
  }
}
