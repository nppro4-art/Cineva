import 'package:cineva_shared/cineva_shared.dart';
import 'package:test/test.dart';

void main() {
  group('CinevaIdentifier normalize', () {
    test('lowercases and strips surrounding spaces', () {
      expect(CinevaIdentifier.normalize('  NOAH '), 'noah');
    });

    test('removes inner spaces so an identifier cannot be ambiguous', () {
      expect(CinevaIdentifier.normalize('Noah S'), 'noahs');
    });

    test('keeps a real email untouched apart from casing', () {
      expect(CinevaIdentifier.normalize('  Noah@Exemple.FR '), 'noah@exemple.fr');
    });
  });

  group('CinevaIdentifier toEmail', () {
    test('a plain identifier becomes a synthetic address', () {
      expect(CinevaIdentifier.toEmail('noah'), 'noah@cineva.app');
    });

    test('a real email is preserved', () {
      expect(CinevaIdentifier.toEmail('noah@exemple.fr'), 'noah@exemple.fr');
    });

    test('synthetic addresses stay stable (idempotent)', () {
      expect(
        CinevaIdentifier.toEmail(CinevaIdentifier.toEmail('noah')),
        'noah@cineva.app',
      );
    });
  });

  group('CinevaIdentifier looksLikeEmail', () {
    test('detects a usable address', () {
      expect(CinevaIdentifier.looksLikeEmail('noah@exemple.fr'), isTrue);
    });

    test('rejects an identifier', () {
      expect(CinevaIdentifier.looksLikeEmail('noah'), isFalse);
    });

    test('rejects a domain without a dot', () {
      expect(CinevaIdentifier.looksLikeEmail('noah@exemple'), isFalse);
    });

    test('rejects a leading or trailing @', () {
      expect(CinevaIdentifier.looksLikeEmail('@exemple.fr'), isFalse);
      expect(CinevaIdentifier.looksLikeEmail('noah@'), isFalse);
    });
  });

  group('CinevaIdentifier displayName', () {
    test('shows the identifier for a synthetic account', () {
      expect(CinevaIdentifier.displayName('noah@cineva.app'), 'noah');
    });

    test('shows the full address for a real account', () {
      expect(CinevaIdentifier.displayName('noah@exemple.fr'), 'noah@exemple.fr');
    });

    test('is null safe and empty safe', () {
      expect(CinevaIdentifier.displayName(null), '');
      expect(CinevaIdentifier.displayName('   '), '');
    });
  });

  group('CinevaIdentifier isSyntheticEmail', () {
    test('flags the fallback domain whatever the casing', () {
      expect(CinevaIdentifier.isSyntheticEmail('noah@cineva.app'), isTrue);
      expect(CinevaIdentifier.isSyntheticEmail('Noah@Cineva.APP'), isTrue);
    });

    test('does not flag a real domain', () {
      expect(CinevaIdentifier.isSyntheticEmail('noah@exemple.fr'), isFalse);
      expect(CinevaIdentifier.isSyntheticEmail(null), isFalse);
    });
  });

  group('CinevaIdentifier validationError', () {
    test('accepts a simple identifier', () {
      expect(CinevaIdentifier.validationError('noah'), isNull);
    });

    test('accepts dots, dashes and underscores inside an identifier', () {
      expect(CinevaIdentifier.validationError('noah.s-0_xy'), isNull);
    });

    test('accepts a real email', () {
      expect(CinevaIdentifier.validationError('noah@exemple.fr'), isNull);
    });

    test('accepts uppercase and spaces around the input', () {
      expect(CinevaIdentifier.validationError('  NOAH '), isNull);
    });

    test('rejects an empty input', () {
      expect(CinevaIdentifier.validationError(''), isNotNull);
    });

    test('rejects a too short identifier', () {
      expect(CinevaIdentifier.validationError('no'), isNotNull);
    });

    test('rejects a too long identifier', () {
      expect(CinevaIdentifier.validationError('a' * 25), isNotNull);
    });

    test('rejects forbidden characters', () {
      expect(CinevaIdentifier.validationError('noah!'), isNotNull);
      expect(CinevaIdentifier.validationError('no ah'), isNull, reason: 'les espaces sont retirés à la normalisation');
    });

    test('rejects an identifier starting or ending with punctuation', () {
      expect(CinevaIdentifier.validationError('.noah'), isNotNull);
      expect(CinevaIdentifier.validationError('noah-'), isNotNull);
    });

    test('rejects an incomplete email', () {
      expect(CinevaIdentifier.validationError('noah@exemple..fr'), isNotNull);
      expect(CinevaIdentifier.validationError('noah@.fr'), isNotNull);
    });

    test('rejects a lone @ inside an identifier', () {
      expect(CinevaIdentifier.validationError('noah@exemple'), isNotNull);
    });
  });
}
