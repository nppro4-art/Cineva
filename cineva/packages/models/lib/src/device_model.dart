import 'package:equatable/equatable.dart';

class DeviceModel extends Equatable {
  const DeviceModel({
    required this.id,
    required this.deviceFingerprint,
    required this.platform,
    required this.isActive,
    this.deviceName,
    this.appVersion,
    this.lastSeenAt,
  });

  final String id;
  final String deviceFingerprint;
  final String platform;
  final bool isActive;
  final String? deviceName;
  final String? appVersion;
  final DateTime? lastSeenAt;

  String get displayName => deviceName?.trim().isNotEmpty == true ? deviceName!.trim() : platform;

  @override
  List<Object?> get props => <Object?>[
        id,
        deviceFingerprint,
        platform,
        isActive,
        deviceName,
        appVersion,
        lastSeenAt,
      ];
}
