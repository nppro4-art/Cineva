import 'dart:async';

import 'package:cineva_animations/cineva_animations.dart';
import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../cineva_empty_state_card.dart';
import '../cineva_poster_card.dart';
import '../library/library_controller.dart';
import 'cineva_artwork.dart';
import 'home_section_resolver.dart';
import 'home_skeleton.dart';

part 'home_screen_sections.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(homeSectionsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(homeSectionsProvider.future),
      child: sectionsAsync.when(
        loading: () => const HomeSkeleton(),
        error: (error, _) => ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.all(CinevaSpacing.lg),
          children: <Widget>[
            const CinevaPageHeader(
              title: 'Accueil',
              subtitle: 'Catalogue premium, recommandations dynamiques et reprise instantanée.',
            ),
            const SizedBox(height: CinevaSpacing.xl),
            CinevaStatusBanner(
              title: 'Impossible de charger l’accueil',
              message: error.toString(),
              tone: CinevaBannerTone.error,
            ),
          ],
        ),
        data: (sections) => _HomeContent(
          sections: sections,
          library: ref.watch(libraryControllerProvider),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.sections, required this.library});

  final List<HomeSectionModel> sections;
  final LibraryState library;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.all(CinevaSpacing.lg),
        children: const <Widget>[
          CinevaPageHeader(
            title: 'Accueil',
            subtitle: 'Catalogue premium, recommandations dynamiques et reprise instantanée.',
          ),
          SizedBox(height: CinevaSpacing.xl),
          CinevaEmptyStateCard(
            title: 'Aucun contenu disponible',
            subtitle: 'Importez votre catalogue plus tard via Supabase ou l’admin. Les écrans sont déjà prêts pour des données dynamiques.',
            icon: Icons.movie_filter_outlined,
          ),
        ],
      );
    }

    final presentation = HomeSectionResolver.resolve(
      sections: sections,
      favoriteIds: library.favoriteIds,
      continueWatching: library.continueWatching,
    );

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(CinevaSpacing.lg, CinevaSpacing.lg, CinevaSpacing.lg, 96),
      children: <Widget>[
        const CinevaFadeSlide(
          child: CinevaPageHeader(
            title: 'Accueil',
            subtitle: 'Hero banner, recommandations, reprises et rails premium alimentés dynamiquement.',
          ),
        ),
        const SizedBox(height: CinevaSpacing.xl),
        if (presentation.heroSection != null) ...<Widget>[
          CinevaFadeSlide(
            delay: const Duration(milliseconds: 80),
            child: _HeroCarouselSection(section: presentation.heroSection!),
          ),
          const SizedBox(height: CinevaSpacing.xxl),
        ],
        for (var index = 0; index < presentation.orderedSections.length; index++) ...<Widget>[
          CinevaFadeSlide(
            delay: Duration(milliseconds: 120 + (index * 45)),
            child: presentation.orderedSections[index].isContinueWatching
                ? _ContinueWatchingSection(section: presentation.orderedSections[index])
                : _RailSection(section: presentation.orderedSections[index]),
          ),
          const SizedBox(height: CinevaSpacing.xxl),
        ],
      ],
    );
  }
}
