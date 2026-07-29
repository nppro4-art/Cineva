import 'package:equatable/equatable.dart';

import 'app_user.dart';
import 'device_model.dart';

class AdminDashboardSummary extends Equatable {
  const AdminDashboardSummary({
    required this.totalUsers,
    required this.activeUsers,
    required this.expiredUsers,
    required this.expiringSoonUsers,
    required this.totalMovies,
    required this.totalSeries,
    required this.totalDownloads,
    required this.totalWatchEvents,
    required this.totalWatchMinutes,
    required this.recentUsers,
    required this.recentDevices,
  });

  const AdminDashboardSummary.empty()
      : totalUsers = 0,
        activeUsers = 0,
        expiredUsers = 0,
        expiringSoonUsers = 0,
        totalMovies = 0,
        totalSeries = 0,
        totalDownloads = 0,
        totalWatchEvents = 0,
        totalWatchMinutes = 0,
        recentUsers = const <AppUser>[],
        recentDevices = const <DeviceModel>[];

  final int totalUsers;
  final int activeUsers;
  final int expiredUsers;
  final int expiringSoonUsers;
  final int totalMovies;
  final int totalSeries;
  final int totalDownloads;
  final int totalWatchEvents;
  final int totalWatchMinutes;
  final List<AppUser> recentUsers;
  final List<DeviceModel> recentDevices;

  @override
  List<Object?> get props => <Object?>[
        totalUsers,
        activeUsers,
        expiredUsers,
        expiringSoonUsers,
        totalMovies,
        totalSeries,
        totalDownloads,
        totalWatchEvents,
        totalWatchMinutes,
        recentUsers,
        recentDevices,
      ];
}
