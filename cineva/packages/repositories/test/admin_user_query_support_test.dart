import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/src/admin_user_query_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 9);
  final settings = AppSettingsModel.defaults();

  AppUser user({
    required String id,
    required String email,
    required String role,
    required String status,
    DateTime? expiresAt,
    bool suspended = false,
  }) {
    return AppUser(
      id: id,
      email: email,
      fullName: 'User $id',
      role: role,
      status: status,
      subscriptionSuspended: suspended,
      subscriptionExpiresAt: expiresAt,
      settings: settings,
    );
  }

  test('matches active non admin users with valid subscription', () {
    final candidate = user(
      id: '1',
      email: 'active@cineva.app',
      role: 'user',
      status: 'active',
      expiresAt: now.add(const Duration(days: 30)),
    );

    expect(
      AdminUserQuerySupport.matchesUser(
        candidate,
        filter: AdminUserFilter.active,
        now: now,
      ),
      isTrue,
    );
  });

  test('matches expiring soon users inside 7 day window', () {
    final candidate = user(
      id: '2',
      email: 'soon@cineva.app',
      role: 'user',
      status: 'active',
      expiresAt: now.add(const Duration(days: 3)),
    );

    expect(
      AdminUserQuerySupport.matchesUser(
        candidate,
        filter: AdminUserFilter.expiringSoon,
        now: now,
      ),
      isTrue,
    );
  });

  test('filters by query and admin status', () {
    final admin = user(
      id: '3',
      email: 'admin@cineva.app',
      role: 'admin',
      status: 'active',
      expiresAt: now.add(const Duration(days: 365)),
    );

    expect(
      AdminUserQuerySupport.matchesUser(
        admin,
        query: 'admin@cineva',
        filter: AdminUserFilter.admins,
        now: now,
      ),
      isTrue,
    );
    expect(
      AdminUserQuerySupport.matchesUser(
        admin,
        query: 'missing',
        filter: AdminUserFilter.admins,
        now: now,
      ),
      isFalse,
    );
  });
}
