import 'package:cineva_models/cineva_models.dart';

/// Profils membres d'un foyer : un abonnement, jusqu'à 5 profils, chacun avec
/// sa liste et sa reprise de lecture.
///
/// Le plafond de 5 est appliqué par la base (`enforce_member_profile_limit`) ;
/// les erreurs sont ramenées à un [AppFailure] lisible plutôt qu'à une
/// exception Postgres brute.
abstract interface class MemberProfileRepository {
  /// Profils du compte connecté, triés (`sort_order`, puis création).
  ///
  /// Un compte sans profil reçoit automatiquement un « Profil principal » :
  /// personne ne se retrouve avec une liste vide après la migration.
  Future<List<MemberProfileModel>> fetchProfiles();

  Future<MemberProfileModel> createProfile({
    required String name,
    String? avatarKey,
    String? colorKey,
    bool? isKid,
  });

  Future<MemberProfileModel> updateProfile(MemberProfileModel profile);

  Future<void> deleteProfile(String profileId);

  /// Profil actif mémorisé sur cet appareil (`null` si aucun).
  Future<String?> readActiveProfileId();

  Future<void> saveActiveProfileId(String? profileId);
}
