import 'package:equatable/equatable.dart';

import 'admin_catalog_item_model.dart';

/// Résultat d'un enregistrement de contenu dans le catalogue.
///
/// Distingue deux choses que l'administrateur doit pouvoir séparer :
///
/// * [item] — la fiche **enregistrée** en base (le film existe, il est
///   publié ou non selon ce qui a été demandé) ;
/// * [warning] — une étape annexe qui n'a pas abouti (le plus souvent le
///   rattachement aux catégories, quand la table de liaison manque en base).
///
/// Sans cette distinction, un échec de liaison faisait croire à une fiche non
/// enregistrée alors qu'elle était bien en base : l'administrateur la
/// ré-enregistrait, ou abandonnait.
class CatalogSaveOutcome extends Equatable {
  const CatalogSaveOutcome({required this.item, this.warning});

  /// Fiche telle qu'elle est en base après l'enregistrement.
  final AdminCatalogItemModel item;

  /// Avertissement lisible, ou `null` si tout a abouti.
  final String? warning;

  bool get hasWarning => warning != null && warning!.isNotEmpty;

  @override
  List<Object?> get props => <Object?>[item, warning];
}
