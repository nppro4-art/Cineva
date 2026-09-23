import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../audio/advanced_audio_screen.dart';
import '../auth/login_screen.dart';
import '../player/player_screen.dart';
import '../settings/audio_video_screen.dart';
import '../settings/help_screen.dart';
import '../settings/language_settings_screen.dart';
import '../settings/notifications_settings_screen.dart';
import '../settings/privacy_settings_screen.dart';
import '../settings/settings_hub_screen.dart';
import '../settings/theme_settings_screen.dart';
import '../user/adaptive_user_shell.dart';
import '../user/content_detail_screen.dart';
import '../user/device_limit_screen.dart';
import '../user/devices_screen.dart';
import '../user/downloads_screen.dart';
import '../user/home_screen.dart';
import '../user/library_screen.dart';
import '../user/profile_gate_screen.dart';
import '../user/profile_screen.dart';
import '../user/profiles_screen.dart';
import '../user/search_screen.dart';
import '../user/subscription_expired_screen.dart';
import '../user/subscription_screen.dart';
import '../vision/cineva_vision_settings_screen.dart';
import 'cineva_page_transitions.dart';
import 'providers.dart';
import 'splash_screen.dart';

/// Application utilisateur Cineva.
///
/// Mobile d'abord : portrait verrouillé, barre de navigation basse à quatre
/// branches (Accueil, Recherche, Téléchargements, Bibliothèque). Le lecteur
/// est la seule page paysage — il reprend la main sur l'orientation à
/// l'ouverture et la rend en se fermant.
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
      child: _UserAppHost(target: target),
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
      final profileState = ref.read(activeProfileControllerProvider);
      return SessionRouteResolver.resolve(
        SessionRouteInput(
          surface: AppSurface.user,
          phase: phase,
          location: state.uri.path,
          needsProfileSelection: profileState.needsSelection,
        ),
      );
    },
    routes: <RouteBase>[
      GoRoute(
        path: SessionRouteResolver.splash,
        pageBuilder: (context, state) => CinevaPageTransitions.modal(
          state: state,
          child: const SplashScreen(title: 'Cineva'),
        ),
      ),
      GoRoute(
        path: SessionRouteResolver.login,
        pageBuilder: (context, state) => CinevaPageTransitions.modal(
          state: state,
          child: const LoginScreen(title: 'Connexion Cineva', surface: AppSurface.user),
        ),
      ),
      GoRoute(
        path: SessionRouteResolver.deviceLimit,
        pageBuilder: (context, state) => CinevaPageTransitions.modal(
          state: state,
          child: const DeviceLimitScreen(),
        ),
      ),
      GoRoute(
        path: SessionRouteResolver.subscriptionExpired,
        pageBuilder: (context, state) => CinevaPageTransitions.modal(
          state: state,
          child: const SubscriptionExpiredScreen(),
        ),
      ),

      // ---------------------------------------------------- quatre branches
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AdaptiveUserShell(
          navigationShell: navigationShell,
          target: target,
        ),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/downloads',
                builder: (context, state) => const DownloadsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/library',
                builder: (context, state) => LibraryScreen(
                  initialTab: state.uri.queryParameters['tab'] == 'resume'
                      ? LibraryTab.resume
                      : LibraryTab.list,
                ),
              ),
            ],
          ),
        ],
      ),

      // ---------------------------------------------------------- contenu
      GoRoute(
        path: '/content/:id',
        pageBuilder: (context, state) => CinevaPageTransitions.push(
          state: state,
          child: ContentDetailScreen(contentId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/player/:id',
        pageBuilder: (context, state) => CinevaPageTransitions.player(
          state: state,
          child: PlayerScreen(
            contentId: state.pathParameters['id']!,
            playTrailer: state.uri.queryParameters['trailer'] == 'true',
          ),
        ),
      ),

      // ------------------------------------------------------------ compte
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => CinevaPageTransitions.push(
          state: state,
          child: const ProfileScreen(),
        ),
      ),
      // Compatibilité : les anciens liens « /account » ouvrent le profil.
      GoRoute(
        path: '/account',
        redirect: (context, state) => '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/account/devices',
        pageBuilder: (context, state) => CinevaPageTransitions.push(
          state: state,
          child: const DevicesScreen(),
        ),
      ),
      // Offre, prix et coordonnées de paiement (Revolut / téléphone).
      GoRoute(
        path: '/account/subscription',
        pageBuilder: (context, state) => CinevaPageTransitions.push(
          state: state,
          child: const SubscriptionScreen(),
        ),
      ),
      // Sas « Qui regarder ? » : choisi au premier lancement sur cet appareil.
      GoRoute(
        path: SessionRouteResolver.profileSelect,
        pageBuilder: (context, state) => CinevaPageTransitions.modal(
          state: state,
          child: const ProfileGateScreen(),
        ),
      ),
      // Profils membres du foyer : un abonnement, jusqu'à 5 profils.
      GoRoute(
        path: SessionRouteResolver.profileManage,
        pageBuilder: (context, state) => CinevaPageTransitions.push(
          state: state,
          child: const ProfilesScreen(),
        ),
      ),

      // --------------------------------------------------------- réglages
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => CinevaPageTransitions.push(
          state: state,
          child: const SettingsHubScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/audio-video',
        pageBuilder: (context, state) => CinevaPageTransitions.push(
          state: state,
          child: const AudioVideoScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/help',
        pageBuilder: (context, state) => CinevaPageTransitions.push(
          state: state,
          child: const HelpScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/language',
        pageBuilder: (context, state) => CinevaPageTransitions.push(
          state: state,
          child: const LanguageSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/theme',
        pageBuilder: (context, state) => CinevaPageTransitions.push(
          state: state,
          child: const ThemeSettingsScreen(),
        ),
      ),
      // Les anciennes « Préférences vidéo » vivent désormais dans Audio & Vidéo.
      GoRoute(
        path: '/settings/video',
        redirect: (context, state) => '/settings/audio-video',
        builder: (context, state) => const AudioVideoScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        pageBuilder: (context, state) => CinevaPageTransitions.push(
          state: state,
          child: const NotificationsSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/privacy',
        pageBuilder: (context, state) => CinevaPageTransitions.push(
          state: state,
          child: const PrivacySettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/cineva-vision',
        pageBuilder: (context, state) => CinevaPageTransitions.push(
          state: state,
          child: const CinevaVisionSettingsScreen(),
        ),
      ),
      // L'écran « Cineva Audio » historique est fusionné dans Audio & Vidéo.
      GoRoute(
        path: '/settings/audio',
        redirect: (context, state) => '/settings/audio-video',
        builder: (context, state) => const AudioVideoScreen(),
      ),
      GoRoute(
        path: '/settings/audio/advanced',
        pageBuilder: (context, state) => CinevaPageTransitions.push(
          state: state,
          child: const AdvancedAudioScreen(),
        ),
      ),
    ],
  );
});

class _UserAppHost extends ConsumerStatefulWidget {
  const _UserAppHost({required this.target});

  final AppTarget target;

  @override
  ConsumerState<_UserAppHost> createState() => _UserAppHostState();
}

class _UserAppHostState extends ConsumerState<_UserAppHost> {
  ProviderSubscription<AsyncValue<NotificationRouteIntent>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.target.isMobileLike) {
      // Portrait verrouillé partout sauf dans le lecteur (voir PlayerScreen).
      _lockPortrait();
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: CinevaColors.ink,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );
    }
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

  void _lockPortrait() {
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
      darkTheme: CinevaTheme.premiumDark(),
      themeMode: themeMode,
      routerConfig: router,
      scrollBehavior: const _CinevaScrollBehavior(),
    );
  }
}

/// Comportement de scroll : aucune barre de défilement ni halo Android sur
/// mobile (le scroll se lit sur le contenu). Les cibles desktop conservent
/// leur barre, utile à la souris.
class _CinevaScrollBehavior extends MaterialScrollBehavior {
  const _CinevaScrollBehavior();

  static const Set<TargetPlatform> _desktopPlatforms = <TargetPlatform>{
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return _desktopPlatforms.contains(getPlatform(context))
        ? super.buildScrollbar(context, child, details)
        : child;
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
