import 'package:cineva_models/cineva_models.dart';

abstract final class AdminUserQuerySupport {
  static bool matchesUser(
    AppUser user, {
    String query = '',
    AdminUserFilter filter = AdminUserFilter.all,
    required DateTime now,
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isNotEmpty) {
      final haystack = '${user.fullName} ${user.email}'.toLowerCase();
      if (!haystack.contains(normalized)) return false;
    }

    final soon = now.add(const Duration(days: 7));
    return switch (filter) {
      AdminUserFilter.all => true,
      AdminUserFilter.active => !user.isAdmin && user.status != 'suspended' && user.subscriptionExpiresAt != null && user.subscriptionExpiresAt!.isAfter(now),
      AdminUserFilter.expired => !user.isAdmin && (user.status == 'suspended' || user.subscriptionExpiresAt == null || !user.subscriptionExpiresAt!.isAfter(now)),
      AdminUserFilter.expiringSoon => !user.isAdmin && user.subscriptionExpiresAt != null && user.subscriptionExpiresAt!.isAfter(now) && user.subscriptionExpiresAt!.isBefore(soon),
      AdminUserFilter.suspended => user.isSuspended,
      AdminUserFilter.admins => user.isAdmin,
    };
  }
}
