import 'package:cineva_shared/cineva_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SessionRouteResolver user app', () {
    test('redirects booting user to splash', () {
      expect(
        SessionRouteResolver.resolve(
          const SessionRouteInput(
            surface: AppSurface.user,
            phase: SessionPhase.booting,
            location: '/home',
          ),
        ),
        SessionRouteResolver.splash,
      );
    });

    test('redirects guest user to login', () {
      expect(
        SessionRouteResolver.resolve(
          const SessionRouteInput(
            surface: AppSurface.user,
            phase: SessionPhase.guest,
            location: '/home',
          ),
        ),
        SessionRouteResolver.login,
      );
    });

    test('redirects authenticated user away from login', () {
      expect(
        SessionRouteResolver.resolve(
          const SessionRouteInput(
            surface: AppSurface.user,
            phase: SessionPhase.authenticated,
            location: '/login',
          ),
        ),
        SessionRouteResolver.userHome,
      );
    });
  });

  group('SessionRouteResolver admin app', () {
    test('redirects unauthorized admin session', () {
      expect(
        SessionRouteResolver.resolve(
          const SessionRouteInput(
            surface: AppSurface.admin,
            phase: SessionPhase.unauthorized,
            location: '/dashboard',
          ),
        ),
        SessionRouteResolver.unauthorized,
      );
    });

    test('redirects authenticated admin from login to dashboard', () {
      expect(
        SessionRouteResolver.resolve(
          const SessionRouteInput(
            surface: AppSurface.admin,
            phase: SessionPhase.authenticated,
            location: '/login',
          ),
        ),
        SessionRouteResolver.adminDashboard,
      );
    });
  });
}
