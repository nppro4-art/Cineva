import 'package:cineva_models/cineva_models.dart';

class HomeSectionPresentation {
  const HomeSectionPresentation({
    required this.heroSection,
    required this.orderedSections,
  });

  final HomeSectionModel? heroSection;
  final List<HomeSectionModel> orderedSections;
}

abstract final class HomeSectionResolver {
  static HomeSectionPresentation resolve({
    required List<HomeSectionModel> sections,
    required Set<String> favoriteIds,
    required List<PlaybackProgressModel> continueWatching,
  }) {
    HomeSectionModel? heroSection;
    for (final section in sections) {
      if (section.isHero) {
        heroSection = section;
        break;
      }
    }

    final allUniqueItems = <String, ContentTileModel>{
      for (final item in sections.expand((section) => section.items)) item.id: item,
    };

    final orderedSections = sections
        .where((section) => !section.isHero)
        .map((section) {
          if (section.isContinueWatching && continueWatching.isNotEmpty) {
            return HomeSectionModel(
              key: section.key,
              title: section.title,
              description: section.description,
              layoutType: section.layoutType,
              items: continueWatching.map((progress) => progress.content).toList(),
            );
          }

          if (section.key == 'my_list' && favoriteIds.isNotEmpty) {
            final favorites = favoriteIds
                .map((id) => allUniqueItems[id])
                .whereType<ContentTileModel>()
                .toList();
            return HomeSectionModel(
              key: section.key,
              title: section.title,
              description: section.description,
              layoutType: section.layoutType,
              items: favorites.isEmpty ? section.items : favorites,
            );
          }

          return section;
        })
        .toList();

    return HomeSectionPresentation(
      heroSection: heroSection,
      orderedSections: orderedSections,
    );
  }
}

abstract final class HomeScreenLayout {
  static double heroHeight(double maxWidth) {
    if (maxWidth >= 1200) return 520;
    if (maxWidth >= 900) return 460;
    return 380;
  }

  static bool showHeroPoster(double maxWidth) => maxWidth >= 850;

  static double continueWatchingCardWidth(double screenWidth) {
    if (screenWidth < 420) return screenWidth * 0.84;
    if (screenWidth < 720) return 300;
    return 330;
  }
}
