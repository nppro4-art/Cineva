import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';

import 'home_repository.dart';

class FakeHomeRepository implements HomeRepository {
  const FakeHomeRepository();

  @override
  List<HomeSectionModel> sectionsFor(AppTarget target) {
    final suffix = switch (target) {
      AppTarget.mobile => 'Mobile',
      AppTarget.admin => 'Admin',
      AppTarget.windows => 'Windows',
      AppTarget.macos => 'macOS',
      AppTarget.androidTv => 'TV',
      AppTarget.web => 'Web',
    };

    return <HomeSectionModel>[
      HomeSectionModel(
        key: 'continue',
        title: 'Continuer le visionnage',
        items: _items('continue', suffix),
      ),
      HomeSectionModel(
        key: 'for-you',
        title: 'Pour vous',
        items: _items('foryou', suffix),
      ),
      HomeSectionModel(
        key: 'trending',
        title: 'Tendances',
        items: _items('trending', suffix),
      ),
      HomeSectionModel(
        key: 'recent',
        title: 'Derniers ajouts',
        items: _items('recent', suffix),
      ),
    ];
  }

  List<ContentTileModel> _items(String prefix, String suffix) {
    return List<ContentTileModel>.generate(
      6,
      (index) => ContentTileModel(
        id: '$prefix-$index',
        title: 'Cineva $suffix ${index + 1}',
        subtitle: index.isEven ? 'Film premium' : 'Série premium',
        badge: index.isEven ? '4K' : 'HDR',
      ),
    );
  }
}
