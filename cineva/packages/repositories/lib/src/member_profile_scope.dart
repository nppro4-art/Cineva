/// Profil membre actif sur cet appareil.
///
/// Petit porteur mutable partagé entre la couche présentation — qui le met à
/// jour quand l'utilisateur change de profil — et les dépôts de données, qui
/// l'interrogent au moment de chaque requête. Injecté plutôt que passé en
/// paramètre de chaque méthode : les signatures existantes de
/// [UserLibraryRepository] ne bougent pas, et un appareil sans profil choisi
/// continue d'écrire exactement comme avant.
class MemberProfileScope {
  MemberProfileScope({String? activeProfileId}) {
    setActiveProfile(activeProfileId);
  }

  String? _activeProfileId;

  /// Identifiant du profil actif, `null` si aucun profil n'est choisi.
  String? get activeProfileId => _activeProfileId;

  bool get hasActiveProfile => _activeProfileId != null;

  void setActiveProfile(String? profileId) {
    final trimmed = profileId?.trim();
    _activeProfileId = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  @override
  String toString() => 'MemberProfileScope(activeProfileId: $_activeProfileId)';
}
