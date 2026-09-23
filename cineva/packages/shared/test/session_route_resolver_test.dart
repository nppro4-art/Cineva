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

  group('SessionRouteResolver sas de profil', () {
    test('authenticated user without active profile lands on the gate', () {
      expect(
        SessionRouteResolver.resolve(
          const SessionRouteInput(
            surface: AppSurface.user,
            phase: SessionPhase.authenticated,
            location: '/home',
            needsProfileSelection: true,
          ),
        ),
        SessionRouteResolver.profileSelect,
      );
    });

    test('gate does not redirect to itself', () {
      expect(
        SessionRouteResolver.resolve(
          const SessionRouteInput(
            surface: AppSurface.user,
            phase: SessionPhase.authenticated,
            location: '/profiles/select',
            needsProfileSelection: true,
          ),
        ),
        isNull,
      );
    });

    test('profile management stays reachable from the gate', () {
      expect(
        SessionRouteResolver.resolve(
          const SessionRouteInput(
            surface: AppSurface.user,
            phase: SessionPhase.authenticated,
            location: '/account/profiles',
            needsProfileSelection: true,
          ),
        ),
        isNull,
      );
    });

    test('choosing a profile leaves the gate for home', () {
      expect(
        SessionRouteResolver.resolve(
          const SessionRouteInput(
            surface: AppSurface.user,
            phase: SessionPhase.authenticated,
            location: '/profiles/select',
          ),
        ),
        SessionRouteResolver.userHome,
      );
    });

    test('home stays reachable when no profile is required', () {
      expect(
        SessionRouteResolver.resolve(
          const SessionRouteInput(
            surface: AppSurface.user,
            phase: SessionPhase.authenticated,
            location: '/home',
          ),
        ),
        isNull,
      );
    });

    test('gate never applies to the admin app', () {
      expect(
        SessionRouteResolver.resolve(
          const SessionRouteInput(
            surface: AppSurface.admin,
            phase: SessionPhase.authenticated,
            location: '/dashboard',
            needsProfileSelection: true,
          ),
        ),
        isNull,
      );
    });
  });
}
