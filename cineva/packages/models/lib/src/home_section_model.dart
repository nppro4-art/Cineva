import 'package:equatable/equatable.dart';

import 'content_tile_model.dart';

class HomeSectionModel extends Equatable {
  const HomeSectionModel({
    required this.key,
    required this.title,
    required this.items,
    this.description,
    this.layoutType = 'rail',
  });

  final String key;
  final String title;
  final String? description;
  final String layoutType;
  final List<ContentTileModel> items;

  bool get isHero => layoutType == 'hero';

  bool get isContinueWatching => layoutType == 'continue_watching';

  @override
  List<Object?> get props => <Object?>[key, title, description, layoutType, items];
}
