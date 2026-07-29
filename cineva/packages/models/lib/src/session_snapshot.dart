import 'package:cineva_shared/cineva_shared.dart';
import 'package:equatable/equatable.dart';

import 'app_user.dart';
import 'device_model.dart';

class SessionSnapshot extends Equatable {
  const SessionSnapshot({
    required this.target,
    required this.surface,
    required this.supabaseReady,
    required this.firebaseReady,
    required this.isBootstrapping,
    this.user,
    this.devices = const <DeviceModel>[],
    this.deviceLimitReached = false,
    this.message,
  });

  factory SessionSnapshot.booting({
    required AppTarget target,
    required AppSurface surface,
  }) {
    return SessionSnapshot(
      target: target,
      surface: surface,
      supabaseReady: false,
      firebaseReady: false,
      isBootstrapping: true,
    );
  }

  factory SessionSnapshot.guest({
    required AppTarget target,
    required AppSurface surface,
    required bool supabaseReady,
    required bool firebaseReady,
    String? message,
  }) {
    return SessionSnapshot(
      target: target,
      surface: surface,
      supabaseReady: supabaseReady,
      firebaseReady: firebaseReady,
      isBootstrapping: false,
      message: message,
    );
  }

  final AppTarget target;
  final AppSurface surface;
  final bool supabaseReady;
  final bool firebaseReady;
  final bool isBootstrapping;
  final AppUser? user;
  final List<DeviceModel> devices;
  final bool deviceLimitReached;
  final String? message;

  bool get isAuthenticated => user != null;

  bool get isAdmin => user?.isAdmin ?? false;

  bool get hasActiveSubscription => user?.hasActiveSubscription ?? false;

  SessionPhase get phase {
    if (isBootstrapping) return SessionPhase.booting;
    if (!isAuthenticated) return SessionPhase.guest;
    if (surface == AppSurface.admin && !isAdmin) return SessionPhase.unauthorized;
    if (deviceLimitReached) return SessionPhase.deviceLimit;
    if (surface == AppSurface.user && !isAdmin && !hasActiveSubscription) {
      return SessionPhase.subscriptionExpired;
    }
    return SessionPhase.authenticated;
  }

  SessionSnapshot copyWith({
    AppTarget? target,
    AppSurface? surface,
    bool? supabaseReady,
    bool? firebaseReady,
    bool? isBootstrapping,
    AppUser? user,
    List<DeviceModel>? devices,
    bool? deviceLimitReached,
    String? message,
    bool clearUser = false,
    bool clearMessage = false,
  }) {
    return SessionSnapshot(
      target: target ?? this.target,
      surface: surface ?? this.surface,
      supabaseReady: supabaseReady ?? this.supabaseReady,
      firebaseReady: firebaseReady ?? this.firebaseReady,
      isBootstrapping: isBootstrapping ?? this.isBootstrapping,
      user: clearUser ? null : user ?? this.user,
      devices: devices ?? this.devices,
      deviceLimitReached: deviceLimitReached ?? this.deviceLimitReached,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        target,
        surface,
        supabaseReady,
        firebaseReady,
        isBootstrapping,
        user,
        devices,
        deviceLimitReached,
        message,
      ];
}
