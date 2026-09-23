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
    this.needsProfileSelection = false,
  });

  final AppSurface surface;
  final SessionPhase phase;
  final String location;

  /// Vrai quand le compte a des profils membres mais qu'aucun n'est encore
  /// choisi sur cet appareil : l'abonné passe d'abord par le sas « Qui
  /// regarde ? ». Sans profil en base (ou base non migrée), reste faux —
  /// l'app fonctionne exactement comme avant.
  final bool needsProfileSelection;

  @override
  List<Object?> get props => <Object?>[surface, phase, location, needsProfileSelection];
}

abstract final class SessionRouteResolver {
  static const splash = '/splash';
  static const login = '/login';
  static const unauthorized = '/unauthorized';
  static const deviceLimit = '/device-limit';
  static const subscriptionExpired = '/subscription-expired';
  static const profileSelect = '/profiles/select';
  static const profileManage = '/account/profiles';
  static const userHome = '/home';
  static const adminDashboard = '/dashboard';

  static String? resolve(SessionRouteInput input) {
    return switch (input.surface) {
      AppSurface.user => _resolveUser(input.phase, input.location, input.needsProfileSelection),
      AppSurface.admin => _resolveAdmin(input.phase, input.location),
    };
  }

  static String? _resolveUser(SessionPhase phase, String location, bool needsProfileSelection) {
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
        // Sas « Qui regarde ? » : tant qu'aucun profil n'est choisi, toute
        // autre route ramène ici. Dès qu'un profil est actif, on en sort.
        if (needsProfileSelection) {
          // Le sas lui-même et la gestion des profils restent accessibles :
          // renommer ou supprimer un profil depuis le sas ne doit pas renvoyer
          // l'abonné à la case départ.
          if (location == profileSelect || location == profileManage) return null;
          return profileSelect;
        }
        if (location == splash ||
            location == login ||
            location == deviceLimit ||
            location == subscriptionExpired ||
            location == profileSelect) {
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
