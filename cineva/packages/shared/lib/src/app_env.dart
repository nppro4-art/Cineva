import 'package:equatable/equatable.dart';

class AppEnv extends Equatable {
  const AppEnv({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.firebaseEnabled,
    required this.enableDebugLogs,
  });

  factory AppEnv.fromDartDefine() {
    return AppEnv(
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
      firebaseEnabled: const bool.fromEnvironment('FIREBASE_ENABLED', defaultValue: true),
      enableDebugLogs: const bool.fromEnvironment('ENABLE_DEBUG_LOGS', defaultValue: false),
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool firebaseEnabled;
  final bool enableDebugLogs;

  bool get hasSupabaseConfig => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  @override
  List<Object?> get props => <Object?>[
        supabaseUrl,
        supabaseAnonKey,
        firebaseEnabled,
        enableDebugLogs,
      ];
}
