import 'package:equatable/equatable.dart';

class AdminHomeSectionItemModel extends Equatable {
  const AdminHomeSectionItemModel({
    required this.id,
    required this.homeSectionId,
    required this.contentType,
    required this.contentId,
    required this.sortOrder,
    required this.title,
  });

  final String id;
  final String homeSectionId;
  final String contentType;
  final String contentId;
  final int sortOrder;
  final String title;

  @override
  List<Object?> get props => <Object?>[
        id,
        homeSectionId,
        contentType,
        contentId,
        sortOrder,
        title,
      ];
}

class AdminHomeSectionModel extends Equatable {
  const AdminHomeSectionModel({
    required this.id,
    required this.sectionKey,
    required this.title,
    required this.layoutType,
    required this.sortOrder,
    required this.isEnabled,
    required this.items,
  });

  final String id;
  final String sectionKey;
  final String title;
  final String layoutType;
  final int sortOrder;
  final bool isEnabled;
  final List<AdminHomeSectionItemModel> items;

  AdminHomeSectionModel copyWith({
    String? id,
    String? sectionKey,
    String? title,
    String? layoutType,
    int? sortOrder,
    bool? isEnabled,
    List<AdminHomeSectionItemModel>? items,
  }) {
    return AdminHomeSectionModel(
      id: id ?? this.id,
      sectionKey: sectionKey ?? this.sectionKey,
      title: title ?? this.title,
      layoutType: layoutType ?? this.layoutType,
      sortOrder: sortOrder ?? this.sortOrder,
      isEnabled: isEnabled ?? this.isEnabled,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        sectionKey,
        title,
        layoutType,
        sortOrder,
        isEnabled,
        items,
      ];
}
