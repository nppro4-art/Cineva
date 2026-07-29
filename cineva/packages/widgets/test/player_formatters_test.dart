import 'package:cineva_widgets/src/player/player_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatDuration handles minutes and hours', () {
    expect(PlayerFormatters.formatDuration(65), '01:05');
    expect(PlayerFormatters.formatDuration(3665), '1:01:05');
  });

  test('formatBytes converts bytes into human readable format', () {
    expect(PlayerFormatters.formatBytes(0), '0 B');
    expect(PlayerFormatters.formatBytes(2048), '2.0 KB');
  });

  test('formatEta formats seconds into compact string', () {
    expect(PlayerFormatters.formatEta(12), '12s');
    expect(PlayerFormatters.formatEta(75), '1m 15s');
  });
}
