import 'package:equatable/equatable.dart';

import 'app_surface.dart';

enum SessionPhase {
  booting,
  guest,
  authenticated,
  deviceLimit,
  subscriptionExpired,
  unauthorized,
}

class SessionRouteInput extends Equatable {
  const SessionRouteInput({
    required this.surface,
    required this.phase,
    required this.location,
  });

  final AppSurface surface;
  final SessionPhase phase;
  final String location;

  @override
  List<Object?> get props => <Object?>[surface, phase, location];
}

abstract final class SessionRouteResolver {
  static const splash = '/splash';
  static const login = '/login';
  static const unauthorized = '/unauthorized';
  static const deviceLimit = '/device-limit';
  static const subscriptionExpired = '/subscription-expired';
  static const userHome = '/home';
  static const adminDashboard = '/dashboard';

  static String? resolve(SessionRouteInput input) {
    return switch (input.surface) {
      AppSurface.user => _resolveUser(input.phase, input.location),
      AppSurface.admin => _resolveAdmin(input.phase, input.location),
    };
  }

  static String? _resolveUser(SessionPhase phase, String location) {
    switch (phase) {
      case SessionPhase.booting:
        return location == splash ? null : splash;
      case SessionPhase.guest:
        return location == login ? null : login;
      case SessionPhase.deviceLimit:
        return location == deviceLimit ? null : deviceLimit;
      case SessionPhase.subscriptionExpired:
        return location == subscriptionExpired ? null : subscriptionExpired;
      case SessionPhase.authenticated:
        if (
            location == splash || location == login || location == deviceLimit || location == subscriptionExpired) {
          return userHome;
        }
        return null;
      case SessionPhase.unauthorized:
        return login;
    }
  }

  static String? _resolveAdmin(SessionPhase phase, String location) {
    switch (phase) {
      case SessionPhase.booting:
        return location == splash ? null : splash;
      case SessionPhase.guest:
        return location == login ? null : login;
      case SessionPhase.unauthorized:
        return location == unauthorized ? null : unauthorized;
      case SessionPhase.authenticated:
        if (location == splash || location == login || location == unauthorized) {
          return adminDashboard;
        }
        return null;
      case SessionPhase.deviceLimit:
        return location == deviceLimit ? null : deviceLimit;
      case SessionPhase.subscriptionExpired:
        return location == subscriptionExpired ? null : subscriptionExpired;
    }
  }
}
