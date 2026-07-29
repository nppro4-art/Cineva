import 'package:cineva_widgets/src/user/cineva_artwork.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CinevaArtworkPalette returns deterministic gradients for same seed', () {
    final first = CinevaArtworkPalette.gradientFor('movie_radiant_city');
    final second = CinevaArtworkPalette.gradientFor('movie_radiant_city');

    expect(first.colors, second.colors);
    expect(first.begin, second.begin);
    expect(first.end, second.end);
  });
}
