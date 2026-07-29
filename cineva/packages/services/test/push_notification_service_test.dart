import 'package:cineva_services/src/notifications/push_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('routeFromData prefers content route when contentId exists', () {
    final route = PushNotificationService.routeFromData(<String, dynamic>{
      'contentId': 'movie_1',
      'screen': '/home',
    });

    expect(route, '/content/movie_1');
  });

  test('routeFromData falls back to screen route', () {
    final route = PushNotificationService.routeFromData(<String, dynamic>{
      'screen': 'downloads',
    });

    expect(route, '/downloads');
  });
}
