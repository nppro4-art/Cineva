import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_widgets/src/user/home_section_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const heroTile = ContentTileModel(
    id: 'hero_1',
    title: 'Hero',
    subtitle: 'Film',
    badge: 'Top',
    contentType: 'movie',
  );
  const favoriteTile = ContentTileModel(
    id: 'fav_1',
    title: 'Favori',
    subtitle: 'Film',
    badge: '4K',
    contentType: 'movie',
  );
  const progressTile = ContentTileModel(
    id: 'ep_1',
    title: 'Episode 1',
    subtitle: 'Série',
    badge: 'Episode',
    contentType: 'episode',
  );

  test('resolves hero, continue watching and favorites from library state', () {
    final sections = <HomeSectionModel>[
      const HomeSectionModel(
        key: 'hero',
        title: 'Hero',
        layoutType: 'hero',
        items: <ContentTileModel>[heroTile],
      ),
      const HomeSectionModel(
        key: 'continue',
        title: 'Continuer',
        layoutType: 'continue_watching',
        items: <ContentTileModel>[],
      ),
      const HomeSectionModel(
        key: 'my_list',
        title: 'Ma liste',
        items: <ContentTileModel>[heroTile, favoriteTile],
      ),
    ];

    final presentation = HomeSectionResolver.resolve(
      sections: sections,
      favoriteIds: <String>{favoriteTile.id},
      continueWatching: <PlaybackProgressModel>[
        PlaybackProgressModel(
          contentId: progressTile.id,
          contentType: progressTile.contentType,
          positionSeconds: 120,
          durationSeconds: 1800,
          updatedAt: DateTime(2026),
          content: progressTile,
        ),
      ],
    );

    expect(presentation.heroSection?.items, <ContentTileModel>[heroTile]);
    expect(presentation.orderedSections[0].items.single.id, progressTile.id);
    expect(presentation.orderedSections[1].items.single.id, favoriteTile.id);
  });

  test('keeps default section items when favorites cannot be resolved from catalog payload', () {
    final section = const HomeSectionModel(
      key: 'my_list',
      title: 'Ma liste',
      items: <ContentTileModel>[heroTile],
    );

    final presentation = HomeSectionResolver.resolve(
      sections: <HomeSectionModel>[section],
      favoriteIds: <String>{'missing'},
      continueWatching: const <PlaybackProgressModel>[],
    );

    expect(presentation.orderedSections.single.items, section.items);
  });

  test('layout exposes stable responsive thresholds', () {
    expect(HomeScreenLayout.heroHeight(360), 380);
    expect(HomeScreenLayout.heroHeight(960), 460);
    expect(HomeScreenLayout.showHeroPoster(900), isTrue);
    expect(HomeScreenLayout.continueWatchingCardWidth(390), closeTo(327.6, 0.1));
  });
}
