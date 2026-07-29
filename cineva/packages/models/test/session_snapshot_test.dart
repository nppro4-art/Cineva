import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SessionSnapshot.phase', () {
    const target = AppTarget.mobile;
    const surface = AppSurface.user;

    test('returns booting while initializing', () {
      final snapshot = SessionSnapshot.booting(target: target, surface: surface);
      expect(snapshot.phase, SessionPhase.booting);
    });

    test('returns guest when no user', () {
      final snapshot = SessionSnapshot.guest(
        target: target,
        surface: surface,
        supabaseReady: true,
        firebaseReady: true,
      );
      expect(snapshot.phase, SessionPhase.guest);
    });

    test('returns subscriptionExpired when non admin user is expired', () {
      final snapshot = SessionSnapshot(
        target: target,
        surface: surface,
        supabaseReady: true,
        firebaseReady: true,
        isBootstrapping: false,
        user: AppUser(
          id: '1',
          email: 'user@cineva.app',
          fullName: 'User',
          role: 'user',
          status: 'active',
          subscriptionExpiresAt: DateTime.now().subtract(const Duration(days: 1)),
          subscriptionSuspended: false,
          settings: AppSettingsModel.defaults(),
        ),
      );

      expect(snapshot.phase, SessionPhase.subscriptionExpired);
    });

    test('returns authenticated for active admin', () {
      final snapshot = SessionSnapshot(
        target: AppTarget.admin,
        surface: AppSurface.admin,
        supabaseReady: true,
        firebaseReady: true,
        isBootstrapping: false,
        user: AppUser(
          id: 'admin',
          email: 'admin@cineva.app',
          fullName: 'Admin',
          role: 'admin',
          status: 'active',
          subscriptionSuspended: false,
          settings: AppSettingsModel.defaults(),
        ),
      );

      expect(snapshot.phase, SessionPhase.authenticated);
    });

    test('returns deviceLimit when device overflow is flagged', () {
      final snapshot = SessionSnapshot(
        target: target,
        surface: surface,
        supabaseReady: true,
        firebaseReady: true,
        isBootstrapping: false,
        deviceLimitReached: true,
        user: AppUser(
          id: '1',
          email: 'user@cineva.app',
          fullName: 'User',
          role: 'user',
          status: 'active',
          subscriptionExpiresAt: DateTime.now().add(const Duration(days: 30)),
          subscriptionSuspended: false,
          settings: AppSettingsModel.defaults(),
        ),
      );

      expect(snapshot.phase, SessionPhase.deviceLimit);
    });
  });
}
