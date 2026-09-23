import 'package:cineva_services/cineva_services.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._backendService);

  final BackendService _backendService;

  @override
  Stream<void> authStateChanges() async* {
    final state = await _backendService.ensureInitialized();
    if (!state.supabaseReady || _backendService.client == null) {
      return;
    }

    yield* _backendService.client!.auth.onAuthStateChange.map((_) => null);
  }

  @override
  Future<void> resetPassword({required String email}) async {
    final client = await _client();
    await client.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final client = await _client();
    await client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    final client = await _client();
    await client.auth.signOut();
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final client = await _client();
    await client.auth.signUp(
      email: email,
      password: password,
      data: <String, dynamic>{
        'full_name': fullName,
      },
    );
  }

  @override
  Future<void> updateFullName({required String fullName}) async {
    final String name = fullName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) {
      throw const AppFailure(
        'Le nom affiché ne peut pas être vide.',
        code: 'EMPTY_DISPLAY_NAME',
      );
    }
    if (name.length > 60) {
      throw const AppFailure(
        'Le nom affiché doit contenir au plus 60 caractères.',
        code: 'DISPLAY_NAME_TOO_LONG',
      );
    }

    final client = await _client();
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppFailure('Aucune session active.', code: 'NO_SESSION');
    }

    try {
      await client
          .from(SupabaseConstants.profilesTable)
          .update(<String, dynamic>{'full_name': name}).eq('id', userId);
    } on PostgrestException catch (error) {
      throw AppFailure(
        'Nom non enregistré : ${error.message}',
        code: error.code,
      );
    }
  }

  Future<SupabaseClient> _client() async {
    final state = await _backendService.ensureInitialized();
    final client = _backendService.client;
    if (!state.supabaseReady || client == null) {
      throw const AppFailure('Supabase n’est pas configuré.', code: 'SUPABASE_NOT_READY');
    }
    return client;
  }
}
