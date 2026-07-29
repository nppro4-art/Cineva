import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationRouteIntent {
  const NotificationRouteIntent({
    required this.route,
    this.messageId,
  });

  final String route;
  final String? messageId;
}

class PushNotificationService {
  PushNotificationService();

  final StreamController<NotificationRouteIntent> _routeController =
      StreamController<NotificationRouteIntent>.broadcast();
  final StreamController<RemoteMessage> _foregroundController =
      StreamController<RemoteMessage>.broadcast();
  bool _initialized = false;

  Stream<NotificationRouteIntent> get routeStream => _routeController.stream;
  Stream<RemoteMessage> get foregroundMessages => _foregroundController.stream;

  Future<String?> initializeAndGetToken({required bool firebaseReady}) async {
    if (!firebaseReady) return null;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      if (!_initialized) {
        FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
        FirebaseMessaging.onMessage.listen((message) {
          if (!_foregroundController.isClosed) {
            _foregroundController.add(message);
          }
        });
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleOpenedMessage(initialMessage);
        }
        _initialized = true;
      }

      return messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final route = routeFromData(message.data);
    if (route != null) {
      _routeController.add(NotificationRouteIntent(route: route, messageId: message.messageId));
    }
  }

  static String? routeFromData(Map<String, dynamic> data) {
    final screen = data['screen'] as String?;
    final contentId = data['contentId'] as String?;
    if (contentId != null && contentId.isNotEmpty) {
      return '/content/$contentId';
    }
    if (screen != null && screen.isNotEmpty) {
      return screen.startsWith('/') ? screen : '/$screen';
    }
    return null;
  }

  void dispose() {
    _routeController.close();
    _foregroundController.close();
  }
}
