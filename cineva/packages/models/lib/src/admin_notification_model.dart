import 'package:equatable/equatable.dart';

class AdminNotificationModel extends Equatable {
  const AdminNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.channel,
    required this.status,
    this.userId,
    this.scheduledAt,
    this.sentAt,
  });

  final String id;
  final String title;
  final String body;
  final String channel;
  final String status;
  final String? userId;
  final DateTime? scheduledAt;
  final DateTime? sentAt;

  bool get isBroadcast => userId == null;

  @override
  List<Object?> get props => <Object?>[
        id,
        title,
        body,
        channel,
        status,
        userId,
        scheduledAt,
        sentAt,
      ];
}
