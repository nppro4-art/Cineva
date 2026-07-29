import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';

abstract interface class HomeRepository {
  List<HomeSectionModel> sectionsFor(AppTarget target);
}
