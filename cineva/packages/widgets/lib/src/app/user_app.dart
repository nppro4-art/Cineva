import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/login_screen.dart';
import '../player/player_screen.dart';
import '../user/account_screen.dart';
import '../user/adaptive_user_shell.dart';
import '../user/content_detail_screen.dart';
import '../user/device_limit_screen.dart';
import '../user/downloads_screen.dart';
import '../user/home_screen.dart';
import '../user/search_screen.dart';
import '../user/subscription_expired_screen.dart';
import '../settings/language_settings_screen.dart';
import '../settings/notifications_settings_screen.dart';
import '../settings/privacy_settings_screen.dart';
import '../settings/settings_hub_screen.dart';
import '../settings/theme_settings_screen.dart';
import '../settings/video_preferences_screen.dart';
import '../vision/cineva_vision_settings_screen.dart';
import 'providers.dart';
import 'splash_screen.dart';

class CinevaUserApp extends StatelessWidget {
  const CinevaUserApp({super.key, required this.target});

  final AppTarget target;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: <Override>[
        appTargetProvider.overrideWithValue(target),
        appSurfaceProvider.overrideWithValue(AppSurface.user),
      ],
      child: const _UserAppHost(),
    );
  }
}

final _userRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(routerRefreshNotifierProvider);
  final target = ref.watch(appTargetProvider);

  return GoRouter(
    initialLocation: SessionRouteResolver.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final phase = session.maybeWhen(
        data: (snapshot) => snapshot.phase,
        orElse: () => SessionPhase.booting,
      );
      return SessionRouteResolver.resolve(
        SessionRouteInput(surface: AppSurface.user, phase: phase, location: state.uri.path),
      );
    },
    routes: <RouteBase>[
      GoRoute(
        path: SessionRouteResolver.splash,
        builder: (context, state) => const SplashScreen(title: 'Cineva'),
      ),
      GoRoute(
        path: SessionRouteResolver.login,
        builder: (context, state) => const LoginScreen(title: 'Connexion Cineva', surface: AppSurface.user),
      ),
      GoRoute(
        path: SessionRouteResolver.deviceLimit,
        builder: (context, state) => const DeviceLimitScreen(),
      ),
      GoRoute(
        path: SessionRouteResolver.subscriptionExpired,
        builder: (context, state) => const SubscriptionExpiredScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AdaptiveUserShell(
          navigationShell: navigationShell,
          target: target,
        ),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(routes: <RouteBase>[GoRoute(path: '/home', builder: (context, state) => const HomeScreen())]),
          StatefulShellBranch(routes: <RouteBase>[GoRoute(path: '/search', builder: (context, state) => const SearchScreen())]),
          StatefulShellBranch(routes: <RouteBase>[GoRoute(path: '/downloads', builder: (context, state) => const DownloadsScreen())]),
          StatefulShellBranch(routes: <RouteBase>[GoRoute(path: '/account', builder: (context, state) => const AccountScreen())]),
        ],
      ),
      GoRoute(
        path: '/content/:id',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: ContentDetailScreen(contentId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/player/:id',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: PlayerScreen(contentId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const SettingsHubScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/language',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const LanguageSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/theme',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const ThemeSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/video',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const VideoPreferencesScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/notifications',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const NotificationsSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/privacy',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const PrivacySettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/cineva-vision',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const CinevaVisionSettingsScreen(),
        ),
      ),
    ],
  );
});

CustomTransitionPage<void> _fadePage({required GoRouterState state, required Widget child}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _UserAppHost extends ConsumerStatefulWidget {
  const _UserAppHost();

  @override
  ConsumerState<_UserAppHost> createState() => _UserAppHostState();
}

class _UserAppHostState extends ConsumerState<_UserAppHost> {
  ProviderSubscription<AsyncValue<NotificationRouteIntent>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _notificationSubscription = ref.listenManual<AsyncValue<NotificationRouteIntent>>(
      notificationRouteProvider,
      (previous, next) {
        final route = next.valueOrNull?.route;
        if (route != null && route.isNotEmpty && mounted) {
          ref.read(_userRouterProvider).go(route);
        }
      },
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(_userRouterProvider);
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final themeMode = switch (settings?.themeMode ?? AppThemeMode.dark) {
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.system => ThemeMode.system,
    };

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Cineva',
      theme: CinevaTheme.light(),
      darkTheme: CinevaTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
