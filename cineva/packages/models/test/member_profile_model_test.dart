import 'package:cineva_models/cineva_models.dart';
import 'package:test/test.dart';

void main() {
  group('MemberProfileModel', () {
    test('valeurs par défaut cohérentes avec les choix proposés', () {
      const profile = MemberProfileModel(id: 'p1', accountId: 'a1', name: 'Noah');

      expect(profile.avatarKey, MemberProfileModel.defaultAvatarKey);
      expect(profile.colorKey, MemberProfileModel.defaultColorKey);
      expect(MemberProfileModel.avatarChoices, contains(MemberProfileModel.defaultAvatarKey));
      expect(MemberProfileModel.colorChoices, contains(MemberProfileModel.defaultColorKey));
      expect(profile.isKid, isFalse);
      expect(profile.isDraft, isFalse);
    });

    test('un profil sans identifiant est un brouillon', () {
      const profile = MemberProfileModel(id: '', accountId: 'a1', name: 'Noah');

      expect(profile.isDraft, isTrue);
    });

    test('initiale majuscule, y compris pour un nom vide', () {
      expect(const MemberProfileModel(id: 'p', accountId: 'a', name: 'léa').initial, 'L');
      expect(const MemberProfileModel(id: 'p', accountId: 'a', name: '   ').initial, '?');
      expect(const MemberProfileModel(id: 'p', accountId: 'a', name: '').initial, '?');
    });

    test('normalizeName : espaces repliés, longueur bornée', () {
      expect(MemberProfileModel.normalizeName('  Noah   Dupont '), 'Noah Dupont');
      expect(MemberProfileModel.normalizeName('a\tb\nc'), 'a b c');
      expect(MemberProfileModel.normalizeName(''), '');
      expect(MemberProfileModel.normalizeName('x' * 40), hasLength(24));
    });

    test('copyWith ne perd pas les champs non fournis', () {
      const profile = MemberProfileModel(
        id: 'p1',
        accountId: 'a1',
        name: 'Noah',
        avatarKey: 'star',
        colorKey: 'sky',
        isKid: true,
        sortOrder: 3,
      );

      final renamed = profile.copyWith(name: 'Léa');

      expect(renamed.name, 'Léa');
      expect(renamed.id, 'p1');
      expect(renamed.avatarKey, 'star');
      expect(renamed.colorKey, 'sky');
      expect(renamed.isKid, isTrue);
      expect(renamed.sortOrder, 3);
      expect(renamed == profile, isFalse);
      expect(renamed.props, hasLength(8));
    });
  });
}
