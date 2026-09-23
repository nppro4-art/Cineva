import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Profils membres du foyer et profil actif sur cet appareil.
///
/// Un abonnement couvre [CinevaOffer.maxProfiles] profils : chacun a sa liste
/// de favoris et sa reprise de lecture. Changer de profil recharge la
/// bibliothèque — les données des autres profils ne se mélangent pas.
class ActiveProfileState extends Equatable {
  const ActiveProfileState({
    this.profiles = const <MemberProfileModel>[],
    this.activeProfileId,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final List<MemberProfileModel> profiles;
  final String? activeProfileId;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  MemberProfileModel? get activeProfile {
    for (final MemberProfileModel profile in profiles) {
      if (profile.id == activeProfileId) return profile;
    }
    return null;
  }

  /// Libellé affiché dans le compte et le sélecteur de profil.
  String get activeProfileName => activeProfile?.name ?? 'Aucun profil';

  bool get hasProfiles => profiles.isNotEmpty;

  /// Le sas « Qui regarde ? » doit-il s'afficher ? Des profils existent, mais
  /// aucun n'est choisi sur cet appareil (premier lancement, ou profil actif
  /// supprimé ailleurs). Pendant le chargement on ne décide rien : mieux vaut
  /// laisser passer que bloquer l'abonné sur un sas vide.
  bool get needsSelection => !isLoading && profiles.isNotEmpty && activeProfileId == null;

  /// Places encore libres sur l'abonnement.
  int get remainingSlots {
    final int left = CinevaOffer.maxProfiles - profiles.length;
    return left < 0 ? 0 : left;
  }

  bool get canAddProfile => remainingSlots > 0;

  ActiveProfileState copyWith({
    List<MemberProfileModel>? profiles,
    String? activeProfileId,
    bool clearActiveProfile = false,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return ActiveProfileState(
      profiles: profiles ?? this.profiles,
      activeProfileId: clearActiveProfile ? null : (activeProfileId ?? this.activeProfileId),
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => <Object?>[profiles, activeProfileId, isLoading, isSaving, error];
}

class ActiveProfileController extends StateNotifier<ActiveProfileState> {
  ActiveProfileController({
    required MemberProfileRepository repository,
    required MemberProfileScope scope,
    required void Function() onProfileChanged,
  })  : _repository = repository,
        _scope = scope,
        _onProfileChanged = onProfileChanged,
        super(const ActiveProfileState()) {
    load();
  }

  final MemberProfileRepository _repository;
  final MemberProfileScope _scope;
  final void Function() _onProfileChanged;

  /// Charge les profils du compte et restaure le profil actif de cet appareil.
  ///
  /// Sans session (ou base non migrée), l'état reste vide et le comportement de
  /// la bibliothèque est exactement celui d'avant les profils.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<MemberProfileModel> profiles = await _repository.fetchProfiles();
      final String? stored = await _repository.readActiveProfileId();
      // Un profil mémorisé disparu (supprimé sur un autre appareil) redevient
      // « aucun profil » : le sas de choix réapparaît plutôt que de basculer en
      // silence sur le compte d'un autre membre du foyer.
      final String? resolved = _knownProfileId(profiles, stored);

      _scope.setActiveProfile(resolved);
      if (resolved != stored) {
        await _repository.saveActiveProfileId(resolved);
      }

      state = state.copyWith(
        profiles: profiles,
        activeProfileId: resolved,
        clearActiveProfile: resolved == null,
        isLoading: false,
        clearError: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(isLoading: false, error: failure.message);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: 'Profils indisponibles : $error');
    }
  }

  /// Bascule sur [profileId] : mémorisé sur l'appareil, puis bibliothèque
  /// rechargée pour ce profil.
  Future<void> selectProfile(String profileId) async {
    if (profileId.isEmpty || state.activeProfileId == profileId) return;

    state = state.copyWith(isSaving: true, clearError: true);
    _scope.setActiveProfile(profileId);
    try {
      await _repository.saveActiveProfileId(profileId);
      state = state.copyWith(activeProfileId: profileId, isSaving: false, clearError: true);
      _onProfileChanged();
    } catch (error) {
      state = state.copyWith(isSaving: false, error: 'Profil impossible à activer : $error');
    }
  }

  /// Crée un profil. Retourne `true` si la création a abouti (l'erreur lisible
  /// est alors dans [ActiveProfileState.error] en cas d'échec).
  Future<bool> createProfile({
    required String name,
    String? avatarKey,
    String? colorKey,
    bool isKid = false,
  }) async {
    if (!state.canAddProfile) {
      state = state.copyWith(
        error: 'L’abonnement couvre ${CinevaOffer.maxProfiles} profils. '
            'Supprimez-en un pour en créer un autre.',
      );
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final MemberProfileModel created = await _repository.createProfile(
        name: name,
        avatarKey: avatarKey,
        colorKey: colorKey,
        isKid: isKid,
      );
      final List<MemberProfileModel> profiles = <MemberProfileModel>[...state.profiles, created];
      _scope.setActiveProfile(created.id);
      await _repository.saveActiveProfileId(created.id);
      state = state.copyWith(
        profiles: profiles,
        activeProfileId: created.id,
        isSaving: false,
        clearError: true,
      );
      _onProfileChanged();
      return true;
    } on AppFailure catch (failure) {
      state = state.copyWith(isSaving: false, error: failure.message);
      return false;
    } catch (error) {
      state = state.copyWith(isSaving: false, error: 'Profil impossible à créer : $error');
      return false;
    }
  }

  Future<bool> updateProfile(MemberProfileModel profile) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final MemberProfileModel updated = await _repository.updateProfile(profile);
      state = state.copyWith(
        profiles: <MemberProfileModel>[
          for (final MemberProfileModel item in state.profiles) item.id == updated.id ? updated : item,
        ],
        isSaving: false,
        clearError: true,
      );
      return true;
    } on AppFailure catch (failure) {
      state = state.copyWith(isSaving: false, error: failure.message);
      return false;
    } catch (error) {
      state = state.copyWith(isSaving: false, error: 'Profil impossible à modifier : $error');
      return false;
    }
  }

  /// Supprime un profil. Sa liste et sa reprise partent avec lui (cascade en
  /// base) — l'écran de confirmation le dit explicitement.
  Future<bool> deleteProfile(String profileId) async {
    if (profileId.isEmpty) return false;

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _repository.deleteProfile(profileId);
      final List<MemberProfileModel> remaining = <MemberProfileModel>[
        for (final MemberProfileModel item in state.profiles)
          if (item.id != profileId) item,
      ];
      final bool wasActive = state.activeProfileId == profileId;
      // Suppression du profil actif : on retombe sur le premier profil restant
      // (l'abonné vient de faire un choix explicite, inutile de le renvoyer au
      // sas), sinon plus aucun profil.
      final String? nextActive = wasActive
          ? (remaining.isEmpty ? null : remaining.first.id)
          : state.activeProfileId;

      _scope.setActiveProfile(nextActive);
      await _repository.saveActiveProfileId(nextActive);

      state = state.copyWith(
        profiles: remaining,
        activeProfileId: nextActive,
        clearActiveProfile: nextActive == null,
        isSaving: false,
        clearError: true,
      );
      if (wasActive) _onProfileChanged();
      return true;
    } on AppFailure catch (failure) {
      state = state.copyWith(isSaving: false, error: failure.message);
      return false;
    } catch (error) {
      state = state.copyWith(isSaving: false, error: 'Profil impossible à supprimer : $error');
      return false;
    }
  }

  void clearError() {
    if (state.error == null) return;
    state = state.copyWith(clearError: true);
  }

  String? _knownProfileId(List<MemberProfileModel> profiles, String? stored) {
    if (stored == null || stored.isEmpty) return null;
    for (final MemberProfileModel profile in profiles) {
      if (profile.id == stored) return stored;
    }
    return null;
  }
}
