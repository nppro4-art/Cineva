enum AdminUserFilter {
  all,
  active,
  expired,
  expiringSoon,
  suspended,
  admins,
}

extension AdminUserFilterX on AdminUserFilter {
  String get label => switch (this) {
        AdminUserFilter.all => 'Tous',
        AdminUserFilter.active => 'Actifs',
        AdminUserFilter.expired => 'Expirés',
        AdminUserFilter.expiringSoon => 'Bientôt expirés',
        AdminUserFilter.suspended => 'Suspendus',
        AdminUserFilter.admins => 'Admins',
      };
}
