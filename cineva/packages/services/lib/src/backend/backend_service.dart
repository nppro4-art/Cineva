import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cineva_shared/cineva_shared.dart';

import 'backend_state.dart';

class BackendService {
  BackendService({AppEnv? environment}) : _environment = environment ?? AppEnv.fromDartDefine();

  final AppEnv _environment;
  BackendState? _state;
  SupabaseClient? _client;

  AppEnv get environment => _environment;
  SupabaseClient? get client => _client;
  BackendState? get state => _state;

  Future<BackendState> ensureInitialized() async {
    if (_state != null) return _state!;

    var firebaseReady = false;
    var supabaseReady = false;
    String? firebaseMessage;
    String? supabaseMessage;

    if (_environment.firebaseEnabled) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp();
        }
        firebaseReady = true;
      } catch (error) {
        firebaseMessage = 'Firebase non initialisé : $error';
      }
    } else {
      firebaseMessage = 'Firebase désactivé via dart-define.';
    }

    if (_environment.hasSupabaseConfig) {
      try {
        if (_client == null) {
          await Supabase.initialize(
            url: _environment.supabaseUrl,
            anonKey: _environment.supabaseAnonKey,
          );
        }
        _client = Supabase.instance.client;
        supabaseReady = true;
      } catch (error) {
        try {
          _client = Supabase.instance.client;
          supabaseReady = true;
        } catch (_) {
          supabaseMessage = 'Supabase non initialisé : $error';
        }
      }
    } else {
      supabaseMessage = 'SUPABASE_URL et SUPABASE_ANON_KEY sont absents.';
    }

    _state = BackendState(
      environment: _environment,
      supabaseReady: supabaseReady,
      firebaseReady: firebaseReady,
      firebaseMessage: firebaseMessage,
      supabaseMessage: supabaseMessage,
    );

    return _state!;
  }
}
