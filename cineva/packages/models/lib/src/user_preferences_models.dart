import 'package:equatable/equatable.dart';

enum AppThemeMode {
  dark,
  light,
  system,
}

extension AppThemeModeX on AppThemeMode {
  String get label => switch (this) {
        AppThemeMode.dark => 'Sombre',
        AppThemeMode.light => 'Clair',
        AppThemeMode.system => 'Système',
      };
}

class NotificationPreferencesModel extends Equatable {
  const NotificationPreferencesModel({
    required this.enabled,
    required this.newContent,
    required this.downloads,
    required this.subscriptionReminders,
    required this.productUpdates,
  });

  factory NotificationPreferencesModel.defaults() {
    return const NotificationPreferencesModel(
      enabled: true,
      newContent: true,
      downloads: true,
      subscriptionReminders: true,
      productUpdates: false,
    );
  }

  final bool enabled;
  final bool newContent;
  final bool downloads;
  final bool subscriptionReminders;
  final bool productUpdates;

  NotificationPreferencesModel copyWith({
    bool? enabled,
    bool? newContent,
    bool? downloads,
    bool? subscriptionReminders,
    bool? productUpdates,
  }) {
    return NotificationPreferencesModel(
      enabled: enabled ?? this.enabled,
      newContent: newContent ?? this.newContent,
      downloads: downloads ?? this.downloads,
      subscriptionReminders: subscriptionReminders ?? this.subscriptionReminders,
      productUpdates: productUpdates ?? this.productUpdates,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'newContent': newContent,
        'downloads': downloads,
        'subscriptionReminders': subscriptionReminders,
        'productUpdates': productUpdates,
      };

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return NotificationPreferencesModel.defaults();
    return NotificationPreferencesModel(
      enabled: json['enabled'] as bool? ?? true,
      newContent: json['newContent'] as bool? ?? true,
      downloads: json['downloads'] as bool? ?? true,
      subscriptionReminders: json['subscriptionReminders'] as bool? ?? true,
      productUpdates: json['productUpdates'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        enabled,
        newContent,
        downloads,
        subscriptionReminders,
        productUpdates,
      ];
}

class PrivacyPreferencesModel extends Equatable {
  const PrivacyPreferencesModel({
    required this.personalizedRecommendations,
    required this.shareWatchHistoryAcrossDevices,
    required this.analyticsEnabled,
    required this.publicProfile,
  });

  factory PrivacyPreferencesModel.defaults() {
    return const PrivacyPreferencesModel(
      personalizedRecommendations: true,
      shareWatchHistoryAcrossDevices: true,
      analyticsEnabled: true,
      publicProfile: false,
    );
  }

  final bool personalizedRecommendations;
  final bool shareWatchHistoryAcrossDevices;
  final bool analyticsEnabled;
  final bool publicProfile;

  PrivacyPreferencesModel copyWith({
    bool? personalizedRecommendations,
    bool? shareWatchHistoryAcrossDevices,
    bool? analyticsEnabled,
    bool? publicProfile,
  }) {
    return PrivacyPreferencesModel(
      personalizedRecommendations:
          personalizedRecommendations ?? this.personalizedRecommendations,
      shareWatchHistoryAcrossDevices:
          shareWatchHistoryAcrossDevices ?? this.shareWatchHistoryAcrossDevices,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      publicProfile: publicProfile ?? this.publicProfile,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'personalizedRecommendations': personalizedRecommendations,
        'shareWatchHistoryAcrossDevices': shareWatchHistoryAcrossDevices,
        'analyticsEnabled': analyticsEnabled,
        'publicProfile': publicProfile,
      };

  factory PrivacyPreferencesModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PrivacyPreferencesModel.defaults();
    return PrivacyPreferencesModel(
      personalizedRecommendations:
          json['personalizedRecommendations'] as bool? ?? true,
      shareWatchHistoryAcrossDevices:
          json['shareWatchHistoryAcrossDevices'] as bool? ?? true,
      analyticsEnabled: json['analyticsEnabled'] as bool? ?? true,
      publicProfile: json['publicProfile'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        personalizedRecommendations,
        shareWatchHistoryAcrossDevices,
        analyticsEnabled,
        publicProfile,
      ];
}
