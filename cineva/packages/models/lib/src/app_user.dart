import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import 'app_settings_model.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.status,
    required this.subscriptionSuspended,
    required this.settings,
    this.avatarPath,
    this.subscriptionExpiresAt,
  });

  final String id;
  final String email;
  final String fullName;
  final String role;
  final String status;
  final String? avatarPath;
  final DateTime? subscriptionExpiresAt;
  final bool subscriptionSuspended;
  final AppSettingsModel settings;

  bool get isAdmin => role == 'admin';

  bool get isSuspended => status == 'suspended' || subscriptionSuspended;

  bool get hasActiveSubscription {
    if (isAdmin) return true;
    if (isSuspended) return false;
    if (subscriptionExpiresAt == null) return false;
    return subscriptionExpiresAt!.isAfter(DateTime.now());
  }

  int get daysRemaining {
    if (subscriptionExpiresAt == null) return 0;
    final diff = subscriptionExpiresAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  String get subscriptionExpiresLabel {
    final date = subscriptionExpiresAt;
    if (date == null) return 'Aucune date';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        email,
        fullName,
        role,
        status,
        avatarPath,
        subscriptionExpiresAt,
        subscriptionSuspended,
        settings,
      ];
}
