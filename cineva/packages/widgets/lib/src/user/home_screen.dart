import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../library/library_controller.dart';
import 'content_detail_helpers.dart';
import 'home_section_resolver.dart';
import 'home_skeleton.dart';

part 'home_screen_sections.dart';

/// Accueil Cineva — l'écran le plus important de l'application.
///
/// Structure mobile portrait :
/// * header de marque transparent posé sur le hero, qui devient une surface
///   sombre au fil du scroll ;
/// * hero animé pleine largeur (rotation automatique des suggestions,
///   crossfade + zoom + parallaxe, texte en cascade) ;
/// * rails horizontaux qui laissent dépasser la carte suivante.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<HomeSectionModel>> sectionsAsync = ref.watch(homeSectionsProvider);

    return sectionsAsync.when(
      loading: () => const HomeSkeleton(),
      error: (Object error, StackTrace stackTrace) =>
          _HomeError(error: error, onRetry: () => ref.refresh(homeSectionsProvider.future)),
      data: (List<HomeSectionModel> sections) => _HomeFeed(
        sections: sections,
        scrollController: _scrollController,
      ),
    );
  }
}

class _HomeFeed extends ConsumerStatefulWidget {
  const _HomeFeed({required this.sections, required this.scrollController});

  final List<HomeSectionModel> sections;
  final ScrollController scrollController;

  @override
  ConsumerState<_HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends ConsumerState<_HomeFeed> {
  @override
  Widget build(BuildContext context) {
    final CinevaMetrics metrics = CinevaMetrics.of(context);
    final LibraryState library = ref.watch(libraryControllerProvider);
    final AppUser? user = ref.watch(sessionControllerProvider).valueOrNull?.user;

    final HomeSectionPresentation presentation = HomeSectionResolver.resolve(
      sections: widget.sections,
      favoriteIds: library.favoriteIds,
      continueWatching: library.continueWatching,
    );

    final HomeSectionModel? heroSection = presentation.heroSection;
    final List<HomeSectionModel> rails = presentation.orderedSections
        .where((HomeSectionModel section) => section.items.isNotEmpty)
        .toList();

    final bool hasContinueSection =
        rails.any((HomeSectionModel section) => section.isContinueWatching);
    final bool showContinue =
        library.continueWatching.isNotEmpty && !hasContinueSection;

    return Stack(
      children: <Widget>[
        RefreshIndicator(
          color: CinevaColors.gold,
          backgroundColor: CinevaColors.surface,
          strokeWidth: 2.2,
          edgeOffset: metrics.topInset + 8,
          onRefresh: () async {
            await Future.wait<void>(<Future<void>>[
              ref.refresh(homeSectionsProvider.future),
              ref.read(libraryControllerProvider.notifier).load(),
            ]);
          },
          child: CustomScrollView(
            controller: widget.scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
              decelerationRate: ScrollDecelerationRate.fast,
            ),
            slivers: <Widget>[
              if (heroSection != null && heroSection.items.isNotEmpty)
                SliverToBoxAdapter(
                  child: _HomeHero(
                    section: heroSection,
                    scrollController: widget.scrollController,
                    myListIds: library.favoriteIds,
                  ),
                )
              else
                SliverToBoxAdapter(child: SizedBox(height: metrics.topInset + 64)),
              if (showContinue)
                SliverToBoxAdapter(
                  child: HomeContinueRail(progress: library.continueWatching),
                ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) => HomeRail(
                    section: rails[index],
                    myListIds: library.favoriteIds,
                  ),
                  childCount: rails.length,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: CinevaBottomNavigation.clearance(context, extra: CinevaSpacing.lg),
                ),
              ),
            ],
          ),
        ),
        if (rails.isEmpty && heroSection == null)
          const Positioned.fill(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(CinevaSpacing.xl),
                child: _EmptyCatalogue(),
              ),
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _HomeHeader(scrollController: widget.scrollController, user: user),
        ),
      ],
    );
  }
}

/// Header CINEVA : transparent sur le hero, surface sombre après ~90 px de
/// scroll. La transition est pilotée par le contrôleur de scroll
/// (aucun `setState`, donc aucune reconstruction de la page).
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.scrollController, required this.user});

  final ScrollController scrollController;
  final AppUser? user;

  static const double _fadeDistance = 90;

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.paddingOf(context).top;

    return AnimatedBuilder(
      animation: scrollController,
      builder: (BuildContext context, Widget? child) {
        final double offset =
            scrollController.hasClients && scrollController.offset > 0
                ? scrollController.offset
                : 0;
        final double opacity = (offset / _fadeDistance).clamp(0.0, 1.0);

        return CinevaBrandHeader(
          opacity: opacity,
          topInset: topInset,
          avatar: CinevaAvatar(
            imagePath: user?.avatarPath,
            initials: CinevaContentLabels.initials(user?.fullName ?? ''),
            size: 30,
            ring: true,
          ),
          onSearch: () => context.go('/search'),
          onProfile: () => context.push('/profile'),
        );
      },
    );
  }
}

class _EmptyCatalogue extends StatelessWidget {
  const _EmptyCatalogue();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.movie_creation_outlined,
          size: 30,
          color: CinevaColors.textFaint,
        ),
        const SizedBox(height: CinevaSpacing.md),
        Text(
          'Aucun contenu pour le moment',
          textAlign: TextAlign.center,
          style: CinevaTypography.sectionTitle.copyWith(fontSize: 16),
        ),
        const SizedBox(height: CinevaSpacing.xs),
        Text(
          'Le catalogue s’affiche dès qu’il est publié depuis la console d’administration.',
          textAlign: TextAlign.center,
          style: CinevaTypography.bodyCompact,
        ),
      ],
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final CinevaMetrics metrics = CinevaMetrics.of(context);

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(
        metrics.gutter,
        metrics.topInset + CinevaSpacing.huge,
        metrics.gutter,
        CinevaSpacing.xxl,
      ),
      children: <Widget>[
        const Icon(Icons.wifi_off_rounded, size: 28, color: CinevaColors.textFaint),
        const SizedBox(height: CinevaSpacing.md),
        Text('Accueil indisponible', style: CinevaTypography.screenTitle.copyWith(fontSize: 22)),
        const SizedBox(height: CinevaSpacing.xs),
        Text(
          '$error',
          style: CinevaTypography.body,
        ),
        const SizedBox(height: CinevaSpacing.xl),
        CinevaSecondaryButton(
          label: 'Réessayer',
          icon: Icons.refresh_rounded,
          expanded: false,
          onPressed: () => onRetry(),
        ),
      ],
    );
  }
}
