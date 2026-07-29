import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/login_controller.dart';
import '../library/library_controller.dart';
import '../search/search_controller.dart';
import '../settings/settings_controller.dart';
import '../vision/vision_controller.dart';
import 'router_refresh_notifier.dart';
import 'session_controller.dart';

final appTargetProvider = Provider<AppTarget>((ref) => throw UnimplementedError('Override appTargetProvider'));
final appSurfaceProvider = Provider<AppSurface>((ref) => throw UnimplementedError('Override appSurfaceProvider'));

final backendServiceProvider = Provider<BackendService>((ref) => BackendService());
final localPreferencesServiceProvider = Provider<LocalPreferencesService>((ref) => const LocalPreferencesService());
final networkStatusServiceProvider = Provider<NetworkStatusService>((ref) {
  final service = NetworkStatusService();
  ref.onDispose(() => service.dispose());
  return service;
});
final deviceFingerprintServiceProvider = Provider<DeviceFingerprintService>(
  (ref) => DeviceFingerprintService(ref.watch(localPreferencesServiceProvider)),
);
final mediaDownloadServiceProvider = Provider<MediaDownloadService>((ref) {
  final service = MediaDownloadService();
  ref.onDispose(() => service.dispose());
  return service;
});
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final service = PushNotificationService();
  ref.onDispose(service.dispose);
  return service;
});
final cinevaVisionServiceProvider = Provider<CinevaVisionService>((ref) => CinevaVisionService());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(backendServiceProvider)),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SupabaseSessionRepository(
    backendService: ref.watch(backendServiceProvider),
    deviceFingerprintService: ref.watch(deviceFingerprintServiceProvider),
    pushNotificationService: ref.watch(pushNotificationServiceProvider),
  ),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => SupabaseCatalogRepository(ref.watch(backendServiceProvider)),
);

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => SupabaseAdminRepository(ref.watch(backendServiceProvider)),
);

final userLibraryRepositoryProvider = Provider<UserLibraryRepository>(
  (ref) => SupabaseUserLibraryRepository(
    backendService: ref.watch(backendServiceProvider),
    localPreferencesService: ref.watch(localPreferencesServiceProvider),
    deviceFingerprintService: ref.watch(deviceFingerprintServiceProvider),
    catalogRepository: ref.watch(catalogRepositoryProvider),
  ),
);

final visionSettingsRepositoryProvider = Provider<VisionSettingsRepository>(
  (ref) => SupabaseVisionSettingsRepository(
    backendService: ref.watch(backendServiceProvider),
    localPreferencesService: ref.watch(localPreferencesServiceProvider),
  ),
);

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>(
  (ref) => SupabaseAppSettingsRepository(
    backendService: ref.watch(backendServiceProvider),
    localPreferencesService: ref.watch(localPreferencesServiceProvider),
  ),
);

final sessionControllerProvider = StateNotifierProvider<SessionController, AsyncValue<SessionSnapshot>>((ref) {
  final controller = SessionController(
    sessionRepository: ref.watch(sessionRepositoryProvider),
    authRepository: ref.watch(authRepositoryProvider),
    appTarget: ref.watch(appTargetProvider),
    appSurface: ref.watch(appSurfaceProvider),
  );

  final subscription = ref.watch(authRepositoryProvider).authStateChanges().listen((_) {
    controller.refresh(showLoader: false);
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.dispose();
  });

  return controller;
});

final routerRefreshNotifierProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier();
  ref.listen<AsyncValue<SessionSnapshot>>(sessionControllerProvider, (_, __) => notifier.trigger());
  ref.onDispose(notifier.dispose);
  return notifier;
});

final notificationRouteProvider = StreamProvider<NotificationRouteIntent>((ref) {
  return ref.watch(pushNotificationServiceProvider).routeStream;
});

final networkConnectedProvider = StreamProvider<bool>((ref) {
  return ref.watch(networkStatusServiceProvider).statusStream;
});

final homeSectionsProvider = FutureProvider<List<HomeSectionModel>>((ref) {
  return ref.watch(catalogRepositoryProvider).fetchHomeSections();
});

final contentDetailProvider = FutureProvider.family<ContentDetailModel?, String>((ref, contentId) {
  return ref.watch(catalogRepositoryProvider).fetchContentDetail(contentId);
});

final similarContentProvider = FutureProvider.family<List<ContentTileModel>, String>((ref, contentId) {
  return ref.watch(catalogRepositoryProvider).fetchSimilarContent(contentId);
});

final libraryControllerProvider = StateNotifierProvider<LibraryController, LibraryState>(
  (ref) => LibraryController(
    repository: ref.watch(userLibraryRepositoryProvider),
    catalogRepository: ref.watch(catalogRepositoryProvider),
    mediaDownloadService: ref.watch(mediaDownloadServiceProvider),
  ),
);

final visionControllerProvider = StateNotifierProvider<VisionController, VisionState>(
  (ref) => VisionController(
    visionService: ref.watch(cinevaVisionServiceProvider),
    repository: ref.watch(visionSettingsRepositoryProvider),
  ),
);

final settingsControllerProvider = StateNotifierProvider<SettingsController, AsyncValue<AppSettingsModel>>(
  (ref) => SettingsController(ref.watch(appSettingsRepositoryProvider)),
);

final searchControllerProvider = StateNotifierProvider.autoDispose<SearchController, SearchState>(
  (ref) => SearchController(
    catalogRepository: ref.watch(catalogRepositoryProvider),
    localPreferencesService: ref.watch(localPreferencesServiceProvider),
  ),
);

final adminUserSearchQueryProvider = StateProvider<String>((ref) => '');
final adminUserFilterProvider = StateProvider<AdminUserFilter>((ref) => AdminUserFilter.all);

final dashboardSummaryProvider = FutureProvider<AdminDashboardSummary>((ref) {
  return ref.watch(adminRepositoryProvider).fetchDashboardSummary();
});

final adminUsersProvider = FutureProvider<List<AppUser>>((ref) {
  final query = ref.watch(adminUserSearchQueryProvider);
  final filter = ref.watch(adminUserFilterProvider);
  return ref.watch(adminRepositoryProvider).fetchUsers(query: query, filter: filter);
});

final adminAllUsersProvider = FutureProvider<List<AppUser>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchUsers();
});

final adminMovieSearchQueryProvider = StateProvider<String>((ref) => '');
final adminSeriesSearchQueryProvider = StateProvider<String>((ref) => '');

final adminMoviesProvider = FutureProvider<List<AdminCatalogItemModel>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchMovies(query: ref.watch(adminMovieSearchQueryProvider));
});

final adminSeriesProvider = FutureProvider<List<AdminCatalogItemModel>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchSeries(query: ref.watch(adminSeriesSearchQueryProvider));
});

final adminCategoriesProvider = FutureProvider<List<AdminCategoryModel>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchCategories();
});

final adminHomeSectionsProvider = FutureProvider<List<AdminHomeSectionModel>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchHomeSections();
});

final adminNotificationsProvider = FutureProvider<List<AdminNotificationModel>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchNotifications();
});

final adminWatchStatsProvider = FutureProvider<List<AdminWatchStatModel>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchTopWatchStats();
});

final loginControllerProvider = StateNotifierProvider<LoginController, AsyncValue<void>?>(
  (ref) => LoginController(
    authRepository: ref.watch(authRepositoryProvider),
    localPreferencesService: ref.watch(localPreferencesServiceProvider),
    sessionController: ref.read(sessionControllerProvider.notifier),
  ),
);
