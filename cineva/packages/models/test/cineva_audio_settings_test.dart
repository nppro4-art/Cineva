import 'package:cineva_models/cineva_models.dart';
import 'package:test/test.dart';

void main() {
  group('CinevaAudioSettings', () {
    test('defaults : moteur actif, profil cinéma, curseurs à 50', () {
      final CinevaAudioSettings s = CinevaAudioSettings.defaults();
      expect(s.enabled, isTrue);
      expect(s.profile, CinevaAudioProfile.cinema);
      expect(s.dialogueAmount, 50);
      expect(s.bassAmount, 50);
      expect(s.dynamicRange, CinevaAudioDynamicRange.cinema);
      expect(s.loudnessEnabled, isTrue);
      expect(s.output, CinevaAudioOutput.speakers);
      expect(s.abCompare, isFalse);
      expect(s.advanced, isNull);
    });

    test('fromJson(null) et json vide → defaults', () {
      expect(CinevaAudioSettings.fromJson(null), CinevaAudioSettings.defaults());
      expect(
        CinevaAudioSettings.fromJson(const <String, dynamic>{}),
        CinevaAudioSettings.defaults(),
      );
    });

    test('fromJson tolère les valeurs hors bornes et noms inconnus', () {
      final CinevaAudioSettings s = CinevaAudioSettings.fromJson(
        <String, dynamic>{
          'enabled': false,
          'profile': 'profile-inconnu',
          'spatialEnabled': false,
          'dialogueAmount': 250,
          'bassAmount': -30,
          'dynamicRange': 'night',
          'loudnessEnabled': false,
          'output': 'headphone',
          'abCompare': true,
        },
      );
      expect(s.enabled, isFalse);
      expect(s.profile, CinevaAudioProfile.cinema); // fallback
      expect(s.spatialEnabled, isFalse);
      expect(s.dialogueAmount, 100); // clampé
      expect(s.bassAmount, 0); // clampé
      expect(s.dynamicRange, CinevaAudioDynamicRange.night);
      expect(s.loudnessEnabled, isFalse);
      expect(s.output, CinevaAudioOutput.headphone);
      expect(s.abCompare, isTrue);
    });

    test('copyWith clamp les curseurs et clearAdvanced remet à null', () {
      final CinevaAudioSettings s = CinevaAudioSettings.defaults()
          .copyWith(dialogueAmount: 300, bassAmount: -5)
          .copyWith(
            advanced: CinevaAudioAdvancedSettings.defaults()
                .copyWith(crossoverHz: 120, subShelfGainDb: 7),
          );
      expect(s.dialogueAmount, 100);
      expect(s.bassAmount, 0);
      expect(s.advanced?.crossoverHz, 120);
      expect(s.advanced?.subShelfGainDb, 7);

      final CinevaAudioSettings cleared = s.copyWith(clearAdvanced: true);
      expect(cleared.advanced, isNull);
    });

    test('round-trip toJson → fromJson', () {
      final CinevaAudioSettings s = CinevaAudioSettings.defaults().copyWith(
        profile: CinevaAudioProfile.immersive,
        dialogueAmount: 75,
        bassAmount: 30,
        dynamicRange: CinevaAudioDynamicRange.night,
        output: CinevaAudioOutput.headphone,
        abCompare: true,
        advanced: CinevaAudioAdvancedSettings.defaults().copyWith(
          eqBandGains: <double>[-2, 0, 1.5, 3, 0, -1],
          eqEnabled: false,
          crossoverHz: 100,
          subShelfGainDb: 6,
          roomWetPercent: 8,
          limiterCeilingDb: -2,
        ),
      );
      final CinevaAudioSettings restored =
          CinevaAudioSettings.fromJson(s.toJson());
      expect(restored, s);
    });

    test('CinevaAudioAdvancedSettings.fromJson borne les 6 bandes', () {
      final CinevaAudioAdvancedSettings adv =
          CinevaAudioAdvancedSettings.fromJson(
        <String, dynamic>{
          'eqBandGains': <dynamic>[20, -20, 2, 3, 4, 5, 99],
          'eqEnabled': false,
          'crossoverHz': 500,
          'subShelfGainDb': -20,
          'roomWetPercent': 90,
          'limiterCeilingDb': -9,
        },
      );
      expect(adv.eqBandGains.length, 6);
      expect(adv.eqBandGains[0], 15); // clampé
      expect(adv.eqBandGains[1], -15); // clampé
      expect(adv.eqBandGains[5], 5);
      expect(adv.eqEnabled, isFalse);
      expect(adv.crossoverHz, 160); // clampé
      expect(adv.subShelfGainDb, -6); // clampé
      expect(adv.roomWetPercent, 15); // clampé
      expect(adv.limiterCeilingDb, -6); // clampé
    });
  });

  group('AppSettingsModel — audioSettings', () {
    test('defaults embarque les réglages audio par défaut', () {
      expect(
        AppSettingsModel.defaults().audioSettings,
        CinevaAudioSettings.defaults(),
      );
    });

    test('toJson expose audioSettings et copyWith le propage', () {
      final AppSettingsModel settings = AppSettingsModel.defaults().copyWith(
        audioSettings: CinevaAudioSettings.defaults()
            .copyWith(profile: CinevaAudioProfile.night),
      );
      final Map<String, dynamic> json = settings.toJson();
      expect(json.containsKey('audioSettings'), isTrue);

      final Map<String, dynamic>? audioJson =
          json['audioSettings'] is Map<String, dynamic>
              ? json['audioSettings'] as Map<String, dynamic>
              : null;
      expect(audioJson, isNotNull);
      expect(
        CinevaAudioSettings.fromJson(audioJson).profile,
        CinevaAudioProfile.night,
      );
    });
  });
}
