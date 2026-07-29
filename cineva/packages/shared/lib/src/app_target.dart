enum AppTarget {
  mobile,
  admin,
  windows,
  macos,
  androidTv,
  web,
}

extension AppTargetX on AppTarget {
  bool get isDesktop => this == AppTarget.windows || this == AppTarget.macos || this == AppTarget.web;

  bool get isTv => this == AppTarget.androidTv;

  bool get isMobileLike => this == AppTarget.mobile;

  String get label => switch (this) {
        AppTarget.mobile => 'Mobile',
        AppTarget.admin => 'Admin',
        AppTarget.windows => 'Windows',
        AppTarget.macos => 'macOS',
        AppTarget.androidTv => 'Android TV',
        AppTarget.web => 'Web',
      };
}
