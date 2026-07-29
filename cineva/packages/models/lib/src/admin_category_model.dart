import 'package:equatable/equatable.dart';

class AdminCategoryModel extends Equatable {
  const AdminCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.categoryType,
  });

  final String id;
  final String name;
  final String slug;
  final String categoryType;

  @override
  List<Object?> get props => <Object?>[id, name, slug, categoryType];
}
