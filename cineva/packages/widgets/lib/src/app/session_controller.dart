import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionController extends StateNotifier<AsyncValue<SessionSnapshot>> {
  SessionController({
    required SessionRepository sessionRepository,
    required AuthRepository authRepository,
    required AppTarget appTarget,
    required AppSurface appSurface,
  })  : _sessionRepository = sessionRepository,
        _authRepository = authRepository,
        _appTarget = appTarget,
        _appSurface = appSurface,
        super(AsyncValue.data(SessionSnapshot.booting(target: appTarget, surface: appSurface))) {
    refresh();
  }

  final SessionRepository _sessionRepository;
  final AuthRepository _authRepository;
  final AppTarget _appTarget;
  final AppSurface _appSurface;

  Future<void> refresh({bool showLoader = true}) async {
    final previous = state.valueOrNull;
    if (showLoader) {
      state = const AsyncValue.loading();
    }

    try {
      final snapshot = await _sessionRepository.bootstrap(target: _appTarget, surface: _appSurface);
      state = AsyncValue.data(snapshot);
    } catch (error, stackTrace) {
      final fallback = previous ??
          SessionSnapshot.guest(
            target: _appTarget,
            surface: _appSurface,
            supabaseReady: false,
            firebaseReady: false,
            message: error.toString(),
          );
      state = AsyncValue.error(error, stackTrace);
      state = AsyncValue.data(fallback.copyWith(message: error.toString()));
    }
  }

  Future<void> removeDevice(String deviceId) async {
    await _sessionRepository.removeDevice(deviceId);
    await refresh(showLoader: false);
  }

  Future<void> disconnectAllDevices({String? userId}) async {
    await _sessionRepository.disconnectAllDevices(userId: userId);
    await refresh(showLoader: false);
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    await refresh(showLoader: false);
  }
}
