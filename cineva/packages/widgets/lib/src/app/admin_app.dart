import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin/admin_shell.dart';
import '../admin/catalog_screen.dart';
import '../admin/dashboard_screen.dart';
import '../admin/notifications_screen.dart';
import '../admin/stats_screen.dart';
import '../admin/users_screen.dart';
import '../auth/login_screen.dart';
import 'providers.dart';
import 'splash_screen.dart';
import 'unauthorized_screen.dart';

class CinevaAdminApp extends StatelessWidget {
  const CinevaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: <Override>[
        appTargetProvider.overrideWithValue(AppTarget.admin),
        appSurfaceProvider.overrideWithValue(AppSurface.admin),
      ],
      child: const _AdminAppHost(),
    );
  }
}

final _adminRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(routerRefreshNotifierProvider);

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
        SessionRouteInput(surface: AppSurface.admin, phase: phase, location: state.uri.path),
      );
    },
    routes: <RouteBase>[
      GoRoute(
        path: SessionRouteResolver.splash,
        builder: (context, state) => const SplashScreen(title: 'Cineva Admin'),
      ),
      GoRoute(
        path: SessionRouteResolver.login,
        builder: (context, state) => const LoginScreen(title: 'Connexion Admin', surface: AppSurface.admin),
      ),
      GoRoute(
        path: SessionRouteResolver.unauthorized,
        builder: (context, state) => const UnauthorizedScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AdminShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(routes: <RouteBase>[GoRoute(path: '/dashboard', builder: (context, state) => const AdminDashboardScreen())]),
          StatefulShellBranch(routes: <RouteBase>[GoRoute(path: '/users', builder: (context, state) => const AdminUsersScreen())]),
          StatefulShellBranch(routes: <RouteBase>[GoRoute(path: '/catalog', builder: (context, state) => const AdminCatalogScreen())]),
          StatefulShellBranch(routes: <RouteBase>[GoRoute(path: '/notifications', builder: (context, state) => const AdminNotificationsScreen())]),
          StatefulShellBranch(routes: <RouteBase>[GoRoute(path: '/stats', builder: (context, state) => const AdminStatsScreen())]),
        ],
      ),
    ],
  );
});

class _AdminAppHost extends ConsumerWidget {
  const _AdminAppHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_adminRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Cineva Admin',
      theme: CinevaTheme.dark(),
      routerConfig: router,
    );
  }
}
