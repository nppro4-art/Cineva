import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';

import 'admin_supabase_gateway.dart';
import 'supabase_support.dart';

class SupabaseAdminDashboardRepository {
  SupabaseAdminDashboardRepository(this._gateway);

  final AdminSupabaseGateway _gateway;

  Future<AdminDashboardSummary> fetchDashboardSummary() async {
    final client = await _gateway.client();
    final users = await client.from(SupabaseConstants.profilesTable).select().order('created_at', ascending: false);
    final movies = await client.from(SupabaseConstants.moviesTable).select('id');
    final series = await client.from('series').select('id');
    final downloads = await client.from('downloads').select('id');
    final watchEvents = await client.from('watch_events').select('event_value').order('created_at', ascending: false).limit(500);
    final devices = await client.from(SupabaseConstants.devicesTable).select().order('last_seen_at', ascending: false).limit(8);

    final allUsers = users.map<AppUser>((row) => mapAppUser(Map<String, dynamic>.from(row as Map))).toList();
    final now = DateTime.now();
    final expiringSoon = now.add(const Duration(days: 7));

    final activeUsers = allUsers.where((user) => !user.isAdmin && user.hasActiveSubscription).length;
    final expiredUsers = allUsers.where((user) => !user.isAdmin && !user.hasActiveSubscription).length;
    final expiringSoonUsers = allUsers.where((user) {
      final expiry = user.subscriptionExpiresAt;
      return !user.isAdmin && expiry != null && expiry.isAfter(now) && expiry.isBefore(expiringSoon);
    }).length;

    final totalWatchMinutes = watchEvents.fold<int>(0, (sum, row) => sum + (((row['event_value'] as int?) ?? 0) ~/ 60));

    return AdminDashboardSummary(
      totalUsers: allUsers.length,
      activeUsers: activeUsers,
      expiredUsers: expiredUsers,
      expiringSoonUsers: expiringSoonUsers,
      totalMovies: movies.length,
      totalSeries: series.length,
      totalDownloads: downloads.length,
      totalWatchEvents: watchEvents.length,
      totalWatchMinutes: totalWatchMinutes,
      recentUsers: allUsers.take(6).toList(),
      recentDevices: devices.map<DeviceModel>((row) => mapDevice(Map<String, dynamic>.from(row as Map))).toList(),
    );
  }

  Future<List<AdminWatchStatModel>> fetchTopWatchStats() async {
    final client = await _gateway.client();
    final rows = await client.from('watch_events').select('content_id, content_type, event_value').order('created_at', ascending: false).limit(800);

    final accumulator = <String, _WatchAccumulator>{};
    for (final dynamic row in rows) {
      final map = Map<String, dynamic>.from(row as Map);
      final key = '${map['content_type']}:${map['content_id']}';
      final current = accumulator[key] ?? _WatchAccumulator(contentId: map['content_id'] as String, contentType: map['content_type'] as String);
      current.events += 1;
      current.minutes += (((map['event_value'] as int?) ?? 0) ~/ 60);
      accumulator[key] = current;
    }

    final movieIds = accumulator.values.where((value) => value.contentType == 'movie').map((e) => e.contentId).toSet().toList();
    final contentIds = accumulator.values.where((value) => value.contentType != 'movie').map((e) => e.contentId).toSet().toList();
    final titles = <String, String>{};

    if (movieIds.isNotEmpty) {
      final movies = await client.from('movies').select('id, title').inFilter('id', movieIds);
      for (final dynamic row in movies) {
        final map = Map<String, dynamic>.from(row as Map);
        titles['movie:${map['id']}'] = map['title'] as String? ?? 'Film';
      }
    }

    if (contentIds.isNotEmpty) {
      final uuidIds = contentIds.where(_looksLikeUuid).toList();
      if (uuidIds.isNotEmpty) {
        final series = await client.from('series').select('id, title').inFilter('id', uuidIds);
        for (final dynamic row in series) {
          final map = Map<String, dynamic>.from(row as Map);
          titles['series:${map['id']}'] = map['title'] as String? ?? 'Série';
        }
        final episodes = await client.from('episodes').select('id, title').inFilter('id', uuidIds);
        for (final dynamic row in episodes) {
          final map = Map<String, dynamic>.from(row as Map);
          titles['episode:${map['id']}'] = map['title'] as String? ?? 'Épisode';
        }
      }
    }

    final stats = accumulator.values
        .map(
          (value) => AdminWatchStatModel(
            contentId: value.contentId,
            contentType: value.contentType,
            title: titles['${value.contentType}:${value.contentId}'] ?? value.contentId,
            totalEvents: value.events,
            totalMinutes: value.minutes,
          ),
        )
        .toList()
      ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));

    return stats.take(12).toList();
  }

  bool _looksLikeUuid(String value) => _uuidRegex.hasMatch(value);

  static final RegExp _uuidRegex = RegExp(r'^[0-9a-fA-F-]{36}$');
}

class _WatchAccumulator {
  _WatchAccumulator({required this.contentId, required this.contentType});

  final String contentId;
  final String contentType;
  int events = 0;
  int minutes = 0;
}
