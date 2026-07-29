import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';

import 'admin_supabase_gateway.dart';
import 'supabase_support.dart';

class SupabaseAdminNotificationsRepository {
  SupabaseAdminNotificationsRepository(this._gateway);

  final AdminSupabaseGateway _gateway;

  Future<void> createNotification({
    required String title,
    required String body,
    String? userId,
    DateTime? scheduledAt,
    String channel = 'general',
    String? contentId,
    String? screen,
  }) {
    return _gateway.invokeCheckedFunction(
      'send-fcm-notification',
      body: <String, dynamic>{
        'title': title,
        'body': body,
        'userId': userId,
        'scheduledAt': scheduledAt?.toIso8601String(),
        'channel': channel,
        'contentId': contentId,
        'screen': screen,
      },
      failureMessage: 'Notification impossible à créer.',
    );
  }

  Future<List<AdminNotificationModel>> fetchNotifications() async {
    final client = await _gateway.client();
    final rows = await client.from(SupabaseConstants.notificationsTable).select().order('created_at', ascending: false).limit(60);
    return rows.map<AdminNotificationModel>((dynamic row) {
      final map = Map<String, dynamic>.from(row as Map);
      return AdminNotificationModel(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        channel: map['channel'] as String? ?? 'general',
        status: map['status'] as String? ?? 'draft',
        userId: map['user_id'] as String?,
        scheduledAt: asDateTime(map['scheduled_at']),
        sentAt: asDateTime(map['sent_at']),
      );
    }).toList();
  }
}
