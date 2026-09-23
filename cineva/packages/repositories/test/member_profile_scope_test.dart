import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemberProfileScope', () {
    test('sans profil, la portée reste vide', () {
      final scope = MemberProfileScope();

      expect(scope.activeProfileId, isNull);
      expect(scope.hasActiveProfile, isFalse);
    });

    test('un identifiant vide ou blanc ne devient jamais un profil actif', () {
      final scope = MemberProfileScope(activeProfileId: 'p1');

      scope.setActiveProfile('   ');
      expect(scope.hasActiveProfile, isFalse);

      scope.setActiveProfile(null);
      expect(scope.hasActiveProfile, isFalse);
    });

    test('l’identifiant est nettoyé et remplaçable', () {
      final scope = MemberProfileScope(activeProfileId: '  p1  ');
      expect(scope.activeProfileId, 'p1');

      scope.setActiveProfile('p2');
      expect(scope.activeProfileId, 'p2');
      expect(scope.hasActiveProfile, isTrue);
      expect(scope.toString(), contains('p2'));
    });
  });
}
