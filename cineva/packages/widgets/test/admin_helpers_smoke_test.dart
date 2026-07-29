import 'package:cineva_widgets/src/player/player_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('player formatter remains available for admin-related progress labels', () {
    expect(PlayerFormatters.formatBytes(1024), '1.0 KB');
  });
}
