import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'member_profile_repository.dart';

/// Profils membres stockés dans Supabase (table `member_profiles`).
///
/// Rattachés au compte connecté : un seul abonnement, jusqu'à
/// [CinevaOffer.maxProfiles] profils. Le plafond est vérifié ici **et** par un
/// trigger en base — l'app donne un message clair avant même l'appel réseau.
///
/// Si la migration n'a pas encore été jouée, les erreurs Postgres sont traduites
/// en [AppFailure] explicite : l'écran affiche quoi faire plutôt qu'un échec muet.
class SupabaseMemberProfileRepository implements MemberProfileRepository {
  SupabaseMemberProfileRepository({
    required BackendService backendService,
    required LocalPreferencesService localPreferencesService,
  })  : _backendService = backendService,
        _localPreferencesService = localPreferencesService;

  /// Nom du profil créé automatiquement pour un compte qui n'en a aucun.
  static const String defaultProfileName = 'Profil principal';

  final BackendService _backendService;
  final LocalPreferencesService _localPreferencesService;

  @override
  Future<List<MemberProfileModel>> fetchProfiles() async {
    final client = await _safeClient();
    if (client == null) return const <MemberProfileModel>[];
    final accountId = client.auth.currentUser!.id;

    try {
      final rows = await client
          .from(SupabaseConstants.memberProfilesTable)
          .select()
          .eq('account_id', accountId)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true);

      if (rows.isNotEmpty) {
        return rows.map<MemberProfileModel>(_fromRow).toList();
      }

      // Aucun profil sur ce compte : on crée le profil principal, une fois.
      final created = await _insert(
        client,
        accountId: accountId,
        name: defaultProfileName,
        sortOrder: 0,
      );
      return <MemberProfileModel>[created];
    } on PostgrestException catch (error) {
      throw _failureFrom(error, fallback: 'Profils impossibles à charger.');
    }
  }

  @override
  Future<MemberProfileModel> createProfile({
    required String name,
    String? avatarKey,
    String? colorKey,
    bool? isKid,
  }) async {
    final client = await _safeClient();
    if (client == null) {
      throw const AppFailure('Connectez-vous pour créer un profil.');
    }

    final cleanName = MemberProfileModel.normalizeName(name);
    if (cleanName.isEmpty) {
      throw const AppFailure('Donnez un nom au profil.');
    }

    final accountId = client.auth.currentUser!.id;
    try {
      final existing = await client
          .from(SupabaseConstants.memberProfilesTable)
          .select('id')
          .eq('account_id', accountId);
      if (existing.length >= CinevaOffer.maxProfiles) {
        throw AppFailure(
          'L’abonnement couvre ${CinevaOffer.maxProfiles} profils. '
          'Supprimez-en un pour en créer un autre.',
          code: 'PROFILE_LIMIT_REACHED',
        );
      }

      return await _insert(
        client,
        accountId: accountId,
        name: cleanName,
        avatarKey: avatarKey,
        colorKey: colorKey,
        isKid: isKid,
        sortOrder: existing.length,
      );
    } on PostgrestException catch (error) {
      throw _failureFrom(error, fallback: 'Profil impossible à créer.');
    }
  }

  @override
  Future<MemberProfileModel> updateProfile(MemberProfileModel profile) async {
    final client = await _safeClient();
    if (client == null) {
      throw const AppFailure('Connectez-vous pour modifier un profil.');
    }

    final cleanName = MemberProfileModel.normalizeName(profile.name);
    if (cleanName.isEmpty) {
      throw const AppFailure('Donnez un nom au profil.');
    }

    try {
      final row = await client
          .from(SupabaseConstants.memberProfilesTable)
          .update(<String, dynamic>{
            'name': cleanName,
            'avatar_key': profile.avatarKey,
            'color_key': profile.colorKey,
            'is_kid': profile.isKid,
            'sort_order': profile.sortOrder,
          })
          .eq('id', profile.id)
          .eq('account_id', profile.accountId)
          .select()
          .single();
      return _fromRow(row);
    } on PostgrestException catch (error) {
      throw _failureFrom(error, fallback: 'Profil impossible à modifier.');
    }
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    final client = await _safeClient();
    if (client == null) {
      throw const AppFailure('Connectez-vous pour supprimer un profil.');
    }
    if (profileId.trim().isEmpty) return;

    try {
      await client
          .from(SupabaseConstants.memberProfilesTable)
          .delete()
          .eq('id', profileId)
          .eq('account_id', client.auth.currentUser!.id);
    } on PostgrestException catch (error) {
      throw _failureFrom(error, fallback: 'Profil impossible à supprimer.');
    }
  }

  @override
  Future<String?> readActiveProfileId() => _localPreferencesService.readActiveMemberProfileId();

  @override
  Future<void> saveActiveProfileId(String? profileId) =>
      _localPreferencesService.saveActiveMemberProfileId(profileId);

  // ------------------------------------------------------------------ interne

  Future<MemberProfileModel> _insert(
    SupabaseClient client, {
    required String accountId,
    required String name,
    required int sortOrder,
    String? avatarKey,
    String? colorKey,
    bool? isKid,
  }) async {
    final row = await client
        .from(SupabaseConstants.memberProfilesTable)
        .insert(<String, dynamic>{
          'account_id': accountId,
          'name': name,
          'avatar_key': avatarKey ?? MemberProfileModel.defaultAvatarKey,
          'color_key': colorKey ?? MemberProfileModel.defaultColorKey,
          'is_kid': isKid ?? false,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return _fromRow(row);
  }

  MemberProfileModel _fromRow(Map<String, dynamic> row) {
    return MemberProfileModel(
      id: row['id'] as String? ?? '',
      accountId: row['account_id'] as String? ?? '',
      name: row['name'] as String? ?? 'Profil',
      avatarKey: row['avatar_key'] as String? ?? MemberProfileModel.defaultAvatarKey,
      colorKey: row['color_key'] as String? ?? MemberProfileModel.defaultColorKey,
      isKid: row['is_kid'] as bool? ?? false,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
    );
  }

  AppFailure _failureFrom(PostgrestException error, {required String fallback}) {
    final raw = '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'.toLowerCase();

    if (raw.contains('profile_limit_reached')) {
      return AppFailure(
        'L’abonnement couvre ${CinevaOffer.maxProfiles} profils. '
        'Supprimez-en un pour en créer un autre.',
        code: 'PROFILE_LIMIT_REACHED',
      );
    }
    if (error.code == '23505' || raw.contains('duplicate key')) {
      return const AppFailure(
        'Un profil porte déjà ce nom sur ce compte.',
        code: 'PROFILE_NAME_TAKEN',
      );
    }
    if (error.code == '42P01' || raw.contains('does not exist') || raw.contains("n'existe pas")) {
      return const AppFailure(
        'Les profils membres ne sont pas encore activés sur ce serveur : jouez '
        'cineva/supabase/migration_profils_abonnement.sql dans le SQL Editor.',
        code: 'PROFILE_TABLE_MISSING',
      );
    }
    if (error.code == '42501' || raw.contains('permission') || raw.contains('autorisation')) {
      return const AppFailure(
        'Accès refusé sur les profils membres : rejouez les droits '
        '(GRANT) de cineva/supabase/repair_movies.sql.',
        code: 'PROFILE_FORBIDDEN',
      );
    }
    return AppFailure(error.message.isEmpty ? fallback : error.message, code: error.code);
  }

  Future<SupabaseClient?> _safeClient() async {
    final state = await _backendService.ensureInitialized();
    final client = _backendService.client;
    if (!state.supabaseReady || client == null || client.auth.currentUser == null) return null;
    return client;
  }
}
