import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_widgets/src/library/active_profile_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un abonnement couvre 5 profils : le contrôleur doit refuser le 6e sans
/// appeler le réseau, basculer la bibliothèque au changement de profil, et
/// retomber sur un profil valide après suppression.
void main() {
  test('charge les profils et restaure le profil actif de l’appareil', () async {
    final repository = _FakeMemberProfileRepository(
      profiles: <MemberProfileModel>[_profile('p1', 'Noah'), _profile('p2', 'Léa')],
      storedActiveId: 'p2',
    );
    final scope = MemberProfileScope();
    final controller = ActiveProfileController(
      repository: repository,
      scope: scope,
      onProfileChanged: () {},
    );

    await Future<void>.delayed(Duration.zero);

    expect(controller.state.profiles, hasLength(2));
    expect(controller.state.activeProfileId, 'p2');
    expect(controller.state.activeProfileName, 'Léa');
    expect(scope.activeProfileId, 'p2');
    expect(controller.state.error, isNull);
  });

  test('sans profil mémorisé, le premier profil devient actif et est enregistré', () async {
    final repository = _FakeMemberProfileRepository(
      profiles: <MemberProfileModel>[_profile('p1', 'Noah'), _profile('p2', 'Léa')],
    );
    final scope = MemberProfileScope();
    final controller = ActiveProfileController(
      repository: repository,
      scope: scope,
      onProfileChanged: () {},
    );

    await Future<void>.delayed(Duration.zero);

    expect(controller.state.activeProfileId, 'p1');
    expect(repository.savedActiveId, 'p1');
    expect(scope.activeProfileId, 'p1');
  });

  test('un profil mémorisé disparu est remplacé, pas conservé', () async {
    final repository = _FakeMemberProfileRepository(
      profiles: <MemberProfileModel>[_profile('p1', 'Noah')],
      storedActiveId: 'p-inexistant',
    );
    final scope = MemberProfileScope();
    final controller = ActiveProfileController(
      repository: repository,
      scope: scope,
      onProfileChanged: () {},
    );

    await Future<void>.delayed(Duration.zero);

    expect(controller.state.activeProfileId, 'p1');
    expect(repository.savedActiveId, 'p1');
  });

  test('changer de profil met à jour la portée et recharge la bibliothèque', () async {
    final repository = _FakeMemberProfileRepository(
      profiles: <MemberProfileModel>[_profile('p1', 'Noah'), _profile('p2', 'Léa')],
    );
    final scope = MemberProfileScope();
    var reloads = 0;
    final controller = ActiveProfileController(
      repository: repository,
      scope: scope,
      onProfileChanged: () => reloads += 1,
    );

    await Future<void>.delayed(Duration.zero);
    await controller.selectProfile('p2');

    expect(controller.state.activeProfileId, 'p2');
    expect(scope.activeProfileId, 'p2');
    expect(repository.savedActiveId, 'p2');
    expect(reloads, 1);

    // Re-sélectionner le même profil ne recharge rien.
    await controller.selectProfile('p2');
    expect(reloads, 1);
  });

  test('créer un profil le rend actif immédiatement', () async {
    final repository = _FakeMemberProfileRepository(
      profiles: <MemberProfileModel>[_profile('p1', 'Noah')],
    );
    final scope = MemberProfileScope();
    var reloads = 0;
    final controller = ActiveProfileController(
      repository: repository,
      scope: scope,
      onProfileChanged: () => reloads += 1,
    );

    await Future<void>.delayed(Duration.zero);
    final created = await controller.createProfile(name: '  Léa  ', colorKey: 'rose');

    expect(created, isTrue);
    expect(controller.state.profiles, hasLength(2));
    expect(controller.state.profiles.last.name, 'Léa');
    expect(controller.state.activeProfileId, 'p2');
    expect(scope.activeProfileId, 'p2');
    expect(reloads, 1);
  });

  test('le 6e profil est refusé avant tout appel réseau', () async {
    final repository = _FakeMemberProfileRepository(
      profiles: <MemberProfileModel>[
        for (var index = 1; index <= CinevaOffer.maxProfiles; index += 1)
          _profile('p$index', 'Membre $index'),
      ],
    );
    final controller = ActiveProfileController(
      repository: repository,
      scope: MemberProfileScope(),
      onProfileChanged: () {},
    );

    await Future<void>.delayed(Duration.zero);

    expect(controller.state.canAddProfile, isFalse);
    expect(controller.state.remainingSlots, 0);

    final created = await controller.createProfile(name: 'Sixième');

    expect(created, isFalse);
    expect(repository.createCalls, 0);
    expect(controller.state.error, contains('${CinevaOffer.maxProfiles}'));
    expect(controller.state.profiles, hasLength(CinevaOffer.maxProfiles));
  });

  test('supprimer le profil actif bascule sur le suivant et recharge', () async {
    final repository = _FakeMemberProfileRepository(
      profiles: <MemberProfileModel>[_profile('p1', 'Noah'), _profile('p2', 'Léa')],
      storedActiveId: 'p1',
    );
    final scope = MemberProfileScope();
    var reloads = 0;
    final controller = ActiveProfileController(
      repository: repository,
      scope: scope,
      onProfileChanged: () => reloads += 1,
    );

    await Future<void>.delayed(Duration.zero);
    final deleted = await controller.deleteProfile('p1');

    expect(deleted, isTrue);
    expect(controller.state.profiles, hasLength(1));
    expect(controller.state.activeProfileId, 'p2');
    expect(scope.activeProfileId, 'p2');
    expect(repository.savedActiveId, 'p2');
    expect(reloads, 1);
  });

  test('supprimer un profil non actif ne touche pas au profil courant', () async {
    final repository = _FakeMemberProfileRepository(
      profiles: <MemberProfileModel>[_profile('p1', 'Noah'), _profile('p2', 'Léa')],
      storedActiveId: 'p1',
    );
    final scope = MemberProfileScope();
    var reloads = 0;
    final controller = ActiveProfileController(
      repository: repository,
      scope: scope,
      onProfileChanged: () => reloads += 1,
    );

    await Future<void>.delayed(Duration.zero);
    await controller.deleteProfile('p2');

    expect(controller.state.activeProfileId, 'p1');
    expect(scope.activeProfileId, 'p1');
    expect(reloads, 0);
  });

  test('un échec de chargement remonte un message lisible, sans planter', () async {
    final repository = _FakeMemberProfileRepository(
      failure: const AppFailure(
        'Les profils membres ne sont pas encore activés sur ce serveur.',
        code: 'PROFILE_TABLE_MISSING',
      ),
    );
    final scope = MemberProfileScope();
    final controller = ActiveProfileController(
      repository: repository,
      scope: scope,
      onProfileChanged: () {},
    );

    await Future<void>.delayed(Duration.zero);

    expect(controller.state.isLoading, isFalse);
    expect(controller.state.profiles, isEmpty);
    expect(controller.state.error, contains('pas encore activés'));
    expect(scope.hasActiveProfile, isFalse);
  });

  test('renommage conservé, ordre et état inchangés', () async {
    final repository = _FakeMemberProfileRepository(
      profiles: <MemberProfileModel>[_profile('p1', 'Noah'), _profile('p2', 'Léa')],
      storedActiveId: 'p2',
    );
    final controller = ActiveProfileController(
      repository: repository,
      scope: MemberProfileScope(),
      onProfileChanged: () {},
    );

    await Future<void>.delayed(Duration.zero);
    final done = await controller.updateProfile(_profile('p1', 'Noah').copyWith(isKid: true));

    expect(done, isTrue);
    expect(controller.state.profiles.first.isKid, isTrue);
    expect(controller.state.profiles.first.name, 'Noah');
    expect(controller.state.activeProfileId, 'p2');
  });
}

MemberProfileModel _profile(String id, String name) {
  return MemberProfileModel(id: id, accountId: 'account-1', name: name);
}

class _FakeMemberProfileRepository implements MemberProfileRepository {
  _FakeMemberProfileRepository({
    this.profiles = const <MemberProfileModel>[],
    this.storedActiveId,
    this.failure,
  });

  final List<MemberProfileModel> profiles;
  final String? storedActiveId;
  final AppFailure? failure;

  String? savedActiveId;
  int createCalls = 0;
  int _nextId = 2;

  @override
  Future<List<MemberProfileModel>> fetchProfiles() async {
    final error = failure;
    if (error != null) throw error;
    return List<MemberProfileModel>.of(profiles);
  }

  @override
  Future<MemberProfileModel> createProfile({
    required String name,
    String? avatarKey,
    String? colorKey,
    bool? isKid,
  }) async {
    createCalls += 1;
    final cleanName = MemberProfileModel.normalizeName(name);
    if (cleanName.isEmpty) throw const AppFailure('Donnez un nom au profil.');
    final created = MemberProfileModel(
      id: 'p${_nextId++}',
      accountId: 'account-1',
      name: cleanName,
      avatarKey: avatarKey ?? MemberProfileModel.defaultAvatarKey,
      colorKey: colorKey ?? MemberProfileModel.defaultColorKey,
      isKid: isKid ?? false,
      sortOrder: profiles.length,
    );
    // Le dépôt réel renvoie la ligne créée ; ici on l'ajoute à la liste locale.
    profiles.add(created);
    return created;
  }

  @override
  Future<MemberProfileModel> updateProfile(MemberProfileModel profile) async {
    final index = profiles.indexWhere((item) => item.id == profile.id);
    if (index < 0) throw const AppFailure('Profil introuvable.');
    profiles[index] = profile;
    return profile;
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    profiles.removeWhere((item) => item.id == profileId);
  }

  @override
  Future<String?> readActiveProfileId() async => storedActiveId ?? savedActiveId;

  @override
  Future<void> saveActiveProfileId(String? profileId) async {
    savedActiveId = profileId;
  }
}
