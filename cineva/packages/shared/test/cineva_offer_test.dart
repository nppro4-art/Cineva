import 'package:cineva_shared/cineva_shared.dart';
import 'package:test/test.dart';

void main() {
  group('CinevaOffer', () {
    test('l’offre annoncée est celle vendue : 15 €, 5 appareils, 5 profils', () {
      expect(CinevaOffer.monthlyPriceEur, 15);
      expect(CinevaOffer.maxDevices, 5);
      expect(CinevaOffer.maxProfiles, 5);
      expect(CinevaOffer.priceLabel, contains('15'));
    });

    test('les coordonnées de paiement sont présentes et complètes', () {
      expect(CinevaOffer.supportPhoneDisplay, '+33 7 87 14 69 92');
      expect(CinevaOffer.supportPhoneRaw, '+33787146992');
      expect(CinevaOffer.revolutTag, '@noah_s0_xy5c');
    });

    test('la marche à suivre cite Revolut et le téléphone', () {
      final joined = CinevaOffer.paymentSteps.join(' ');

      expect(joined, contains(CinevaOffer.revolutTag));
      expect(joined, contains(CinevaOffer.supportPhoneDisplay));
      expect(CinevaOffer.included.join(' '), contains('5 appareils'));
      expect(CinevaOffer.included.join(' '), contains('5 profils'));
    });

    test('le numéro brut est appelable (format E.164)', () {
      expect(RegExp(r'^\+33[1-9]\d{8}$').hasMatch(CinevaOffer.supportPhoneRaw), isTrue);
    });
  });
}
