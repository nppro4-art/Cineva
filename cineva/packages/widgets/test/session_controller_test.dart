import 'dart:async';

import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_widgets/src/app/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SessionController loads authenticated snapshot on refresh', () async {
    final authRepository = _FakeAuthRepository();
    final sessionRepository = _FakeSessionRepository(
      snapshot: SessionSnapshot(
        target: AppTarget.mobile,
        surface: AppSurface.user,
        supabaseReady: true,
        firebaseReady: true,
        isBootstrapping: false,
        user: AppUser(
          id: 'u1',
          email: 'user@cineva.app',
          fullName: 'User',
          role: 'user',
          status: 'active',
          subscriptionExpiresAt: DateTime.now().add(const Duration(days: 20)),
          subscriptionSuspended: false,
          settings: AppSettingsModel.defaults(),
        ),
      ),
    );

    final controller = SessionController(
      sessionRepository: sessionRepository,
      authRepository: authRepository,
      appTarget: AppTarget.mobile,
      appSurface: AppSurface.user,
    );

    await Future<void>.delayed(Duration.zero);

    expect(controller.state.valueOrNull?.isAuthenticated, isTrue);
    expect(controller.state.valueOrNull?.phase, SessionPhase.authenticated);
  });

  test('SessionController signs out through auth repository', () async {
    final authRepository = _FakeAuthRepository();
    final sessionRepository = _FakeSessionRepository(
      snapshot: SessionSnapshot.guest(
        target: AppTarget.mobile,
        surface: AppSurface.user,
        supabaseReady: true,
        firebaseReady: true,
      ),
    );

    final controller = SessionController(
      sessionRepository: sessionRepository,
      authRepository: authRepository,
      appTarget: AppTarget.mobile,
      appSurface: AppSurface.user,
    );

    await controller.signOut();

    expect(authRepository.signOutCalled, isTrue);
  });
}

class _FakeAuthRepository implements AuthRepository {
  bool signOutCalled = false;

  @override
  Stream<void> authStateChanges() => Stream<void>.empty();

  @override
  Future<void> resetPassword({required String email}) async {}

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<void> signUp({required String email, required String password, required String fullName}) async {}
}

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({required this.snapshot});

  final SessionSnapshot snapshot;

  @override
  Future<SessionSnapshot> bootstrap({required AppTarget target, required AppSurface surface}) async => snapshot;

  @override
  Future<void> disconnectAllDevices({String? userId}) async {}

  @override
  Future<List<DeviceModel>> fetchDevices() async => const <DeviceModel>[];

  @override
  Future<void> removeDevice(String deviceId) async {}
}
