import 'package:equatable/equatable.dart';

import 'package:cineva_shared/cineva_shared.dart';

class BackendState extends Equatable {
  const BackendState({
    required this.environment,
    required this.supabaseReady,
    required this.firebaseReady,
    this.supabaseMessage,
    this.firebaseMessage,
  });

  final AppEnv environment;
  final bool supabaseReady;
  final bool firebaseReady;
  final String? supabaseMessage;
  final String? firebaseMessage;

  @override
  List<Object?> get props => <Object?>[
        environment,
        supabaseReady,
        firebaseReady,
        supabaseMessage,
        firebaseMessage,
      ];
}
