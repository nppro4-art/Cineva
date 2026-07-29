class SessionGuardSnapshot {
  const SessionGuardSnapshot({
    required this.isAuthenticated,
    required this.hasActiveSubscription,
    required this.deviceLimitReached,
  });

  final bool isAuthenticated;
  final bool hasActiveSubscription;
  final bool deviceLimitReached;
}

class SessionGuardService {
  const SessionGuardService();

  SessionGuardSnapshot bootstrapSnapshot() {
    return const SessionGuardSnapshot(
      isAuthenticated: false,
      hasActiveSubscription: false,
      deviceLimitReached: false,
    );
  }
}
