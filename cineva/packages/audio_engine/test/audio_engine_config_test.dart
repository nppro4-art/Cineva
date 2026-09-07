import 'package:cineva_audio_engine/cineva_audio_engine.dart';
import 'package:test/test.dart';

void main() {
  group('AudioEngineConfig', () {
    test('le profil cinéma expose des réglages dynamiques', () {
      final AudioEngineConfig c =
          AudioEngineConfig.forProfile(CinevaAudioProfile.cinema);
      expect(c.loudness.targetLufs, -18);
      expect(c.drc.thresholdDb, -28);
      expect(c.drc.ratio, 2);
      expect(c.dialogue.intensityPercent, 35);
      expect(c.bass.intensityPercent, 55);
      expect(c.spatial.widthPercent, 100);
      expect(c.room.wetPercent, 8);
      expect(c.limiter.ceilingDb, -0.5);
    });

    test('le profil original désactive tout', () {
      final AudioEngineConfig c =
          AudioEngineConfig.forProfile(CinevaAudioProfile.original);
      expect(c.loudness.enabled, isFalse);
      expect(c.drc.enabled, isFalse);
      expect(c.dialogue.enabled, isFalse);
      expect(c.bass.enabled, isFalse);
      expect(c.spatial.enabled, isFalse);
      expect(c.room.enabled, isFalse);
      expect(c.limiter.enabled, isFalse);
      expect(c.eq.bands, isEmpty);
    });

    test('chaque profil a des EQ définies (sauf original)', () {
      for (final CinevaAudioProfile p in CinevaAudioProfile.values) {
        final AudioEngineConfig c = AudioEngineConfig.forProfile(p);
        if (p == CinevaAudioProfile.original) continue;
        expect(c.eq.bands.length, 6, reason: p.name);
        for (final EqBandConfig b in c.eq.bands) {
          expect(b.gainDb, inInclusiveRange(-15, 15));
          expect(b.freqHz, inInclusiveRange(20, 20000));
        }
      }
    });

    test('toParams produit un tableau valide et complet', () {
      final AudioEngineConfig c =
          AudioEngineConfig.forProfile(CinevaAudioProfile.night);
      final Float64List p = c.toParams(sampleRate: 48000, channels: 2);
      expect(p.length, kDspParamCount);
      expect(p[DspParam.layoutVersion], kDspParamVersion);
      expect(p[DspParam.sampleRate], 48000);
      expect(p[DspParam.masterEnable], 1);
      expect(p[DspParam.inChannels], 2);
      expect(p[DspParam.drcThresholdDb], -34);
      expect(p[DspParam.drcMixPercent], 30);
      for (final double v in p) {
        expect(v.isFinite, isTrue, reason: 'aucun NaN/Inf dans les params');
      }
    });

    test('les valeurs extrêmes sont clampées', () {
      const AudioEngineConfig c = AudioEngineConfig(
        loudness: LoudnessConfig(targetLufs: 12, maxGainDb: 999, adaptRateDbPerSec: -50),
        dialogue: DialogueConfig(intensityPercent: 500),
        bass: BassConfig(crossoverHz: 5, subShelfGainDb: 40),
        spatial: SpatialConfig(widthPercent: 900, crossfeedPercent: -20),
        room: RoomConfig(wetPercent: 80, sizePercent: 5),
        limiter: LimiterConfig(ceilingDb: 3, lookaheadMs: 50),
        eq: EqConfig(bands: <EqBandConfig>[
          EqBandConfig(type: 99, freqHz: 1, gainDb: 60, q: 0.01),
        ]),
        drc: DrcConfig(thresholdDb: 30, ratio: 0.1, attackMs: 9999),
      );
      final Float64List p = c.sanitized().toParams();
      expect(p[DspParam.loudnessTargetLufs], lessThanOrEqualTo(-8));
      expect(p[DspParam.loudnessMaxGainDb], lessThanOrEqualTo(12));
      expect(p[DspParam.loudnessAdaptRateDbPerSec], greaterThanOrEqualTo(0.1));
      expect(p[DspParam.dialogueIntensityPercent], lessThanOrEqualTo(100));
      expect(p[DspParam.bassCrossoverHz], greaterThanOrEqualTo(50));
      expect(p[DspParam.bassSubShelfGainDb], lessThanOrEqualTo(9));
      expect(p[DspParam.spatialWidthPercent], lessThanOrEqualTo(150));
      expect(p[DspParam.spatialCrossfeedPercent], greaterThanOrEqualTo(0));
      expect(p[DspParam.roomWetPercent], lessThanOrEqualTo(15));
      expect(p[DspParam.roomSizePercent], greaterThanOrEqualTo(50));
      expect(p[DspParam.limiterCeilingDb], lessThanOrEqualTo(0));
      expect(p[DspParam.limiterLookaheadMs], lessThanOrEqualTo(10));
      expect(p[DspParam.eqGainDb(0)], lessThanOrEqualTo(15));
      expect(p[DspParam.eqType(0)], inInclusiveRange(0, 4));
      expect(p[DspParam.drcThresholdDb], greaterThanOrEqualTo(-60));
      expect(p[DspParam.drcRatio], greaterThanOrEqualTo(1));
      expect(p[DspParam.drcAttackMs], lessThanOrEqualTo(200));
      for (final double v in p) {
        expect(v.isFinite, isTrue);
      }
    });

    test('les NaN venant du JSON sont neutralisés', () {
      final AudioEngineConfig c = AudioEngineConfig.fromJson(
        <String, dynamic>{
          'profile': 'cinema',
          'loudness': <String, dynamic>{'targetLufs': double.nan},
          'dialogue': <String, dynamic>{'intensityPercent': double.infinity},
          'room': <String, dynamic>{'wetPercent': double.nan},
        },
      );
      final Float64List p = c.toParams();
      for (final double v in p) {
        expect(v.isFinite, isTrue);
      }
      expect(p[DspParam.dialogueIntensityPercent], inInclusiveRange(0, 100));
    });

    test('JSON aller-retour préserve les réglages', () {
      final AudioEngineConfig c = AudioEngineConfig.forProfile(
              CinevaAudioProfile.immersive)
          .copyWith(
        dialogue: const DialogueConfig(intensityPercent: 72),
        bass: const BassConfig(intensityPercent: 33, crossoverHz: 95),
      );
      final Map<String, dynamic> json = c.toJson();
      final AudioEngineConfig restored = AudioEngineConfig.fromJson(json);
      expect(restored.profile, CinevaAudioProfile.immersive);
      expect(restored.dialogue.intensityPercent, 72);
      expect(restored.bass.intensityPercent, 33);
      expect(restored.bass.crossoverHz, 95);
      expect(restored.spatial.crossfeedPercent, 35);
      expect(restored.toJson(), json);
    });

    test('JSON invalide retombe sur le profil demandé', () {
      final AudioEngineConfig c = AudioEngineConfig.fromJson(
          <String, dynamic>{'profile': 'tv'});
      expect(c.profile, CinevaAudioProfile.tv);
      expect(c.dialogue.intensityPercent, 65);
    });

    test('modes de dynamique', () {
      expect(DrcConfig.forMode(DynamicRangeMode.cinema).ratio, 2);
      expect(DrcConfig.forMode(DynamicRangeMode.standard).ratio, 2.5);
      expect(DrcConfig.forMode(DynamicRangeMode.night).ratio, 4);
      expect(DrcConfig.forMode(DynamicRangeMode.night).mixPercent, 30);
      expect(DynamicRangeModeX.fromName('night'), DynamicRangeMode.night);
      expect(DynamicRangeModeX.fromName(null), DynamicRangeMode.cinema);
    });

    test('libellés des profils', () {
      expect(CinevaAudioProfile.cinema.label, 'Cinéma');
      expect(CinevaAudioProfile.original.label, 'Original');
      expect(CinevaAudioProfileX.fromName('night'), CinevaAudioProfile.night);
      expect(CinevaAudioProfileX.fromName('nimporte'), CinevaAudioProfile.cinema);
    });
  });
}
