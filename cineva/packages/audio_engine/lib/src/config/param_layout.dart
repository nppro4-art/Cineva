/// Contrat de paramètres du Cineva Audio Engine.
///
/// Tableau de 128 doubles versionné, partagé à l'identique par les cœurs
/// C (FFI), Dart et JS (AudioWorklet). Tout index hors définition est
/// réservé et doit valoir 0.
library;

const int kDspParamVersion = 1;
const int kDspParamCount = 128;
const int kDspMetricCount = 16;
const int kDspMaxChannels = 8;
const int kDspMaxBlock = 8192;

/// Index de paramètres (version 1).
abstract final class DspParam {
  static const int layoutVersion = 0;
  static const int sampleRate = 1;
  static const int masterEnable = 2;
  static const int inChannels = 3;
  static const int outChannels = 4;
  static const int inputLayout = 5;
  static const int lfeIntoBass = 6;
  static const int masterHeadroomDb = 7;

  // Loudness 8..15
  static const int loudnessEnable = 8;
  static const int loudnessTargetLufs = 9;
  static const int loudnessMaxGainDb = 10;
  static const int loudnessMaxAttenuationDb = 11;
  static const int loudnessAdaptRateDbPerSec = 12;

  // EQ 16..47 : 6 bandes × 5 slots
  static const int eqEnable = 16;
  static int eqType(int band) => 17 + 5 * band;
  static int eqFreq(int band) => 18 + 5 * band;
  static int eqGainDb(int band) => 19 + 5 * band;
  static int eqQ(int band) => 20 + 5 * band;

  // DRC 48..59
  static const int drcEnable = 48;
  static const int drcThresholdDb = 49;
  static const int drcRatio = 50;
  static const int drcKneeDb = 51;
  static const int drcAttackMs = 52;
  static const int drcReleaseMs = 53;
  static const int drcMakeupDb = 54;
  static const int drcMixPercent = 55;
  static const int drcDetector = 56;

  // Dialogue 60..67
  static const int dialogueEnable = 60;
  static const int dialogueIntensityPercent = 61;

  // Bass 68..79
  static const int bassEnable = 68;
  static const int bassIntensityPercent = 69;
  static const int bassCrossoverHz = 70;
  static const int bassSpeakerMode = 71;
  static const int bassSubShelfGainDb = 72;
  static const int bassHarmonicDrivePercent = 73;
  static const int bassLfeGainDb = 74;

  // Spatial 80..91
  static const int spatialEnable = 80;
  static const int spatialMode = 81;
  static const int spatialWidthPercent = 82;
  static const int spatialCrossfeedPercent = 83;
  static const int spatialBinauralAmountPercent = 84;

  // Room 92..99
  static const int roomEnable = 92;
  static const int roomWetPercent = 93;
  static const int roomSizePercent = 94;

  // Limiter 100..107
  static const int limiterEnable = 100;
  static const int limiterCeilingDb = 101;
  static const int limiterLookaheadMs = 102;
  static const int limiterReleaseMs = 103;
}

/// Index de métriques.
abstract final class DspMetric {
  static const int loudnessLufs = 0;
  static const int truePeakDb = 1;
  static const int loudnessGainDb = 2;
  static const int limiterGainDb = 3;
  static const int clippedSamples = 4;
  static const int engineActive = 5;
}

/// Remplit un tableau de paramètres neutre (tous traitements actifs,
/// réglages par défaut « Standard »).
Float64List neutralParams({double sampleRate = 48000, int channels = 2}) {
  final Float64List p = Float64List(kDspParamCount);
  p[DspParam.layoutVersion] = kDspParamVersion.toDouble();
  p[DspParam.sampleRate] = sampleRate;
  p[DspParam.masterEnable] = 1;
  p[DspParam.inChannels] = channels.toDouble();
  p[DspParam.outChannels] = 2;
  p[DspParam.inputLayout] = channels >= 6 ? 3 : (channels >= 4 ? 2 : (channels >= 2 ? 1 : 0)).toDouble();
  p[DspParam.loudnessEnable] = 1;
  p[DspParam.loudnessTargetLufs] = -16;
  p[DspParam.loudnessMaxGainDb] = 8;
  p[DspParam.loudnessMaxAttenuationDb] = 8;
  p[DspParam.loudnessAdaptRateDbPerSec] = 1.5;
  p[DspParam.eqEnable] = 1;
  const types = <int>[0, 1, 1, 1, 1, 2];
  const freqs = <double>[45, 90, 300, 1200, 3500, 10000];
  for (int i = 0; i < 6; i++) {
    p[DspParam.eqType(i)] = types[i].toDouble();
    p[DspParam.eqFreq(i)] = freqs[i];
    p[DspParam.eqGainDb(i)] = 0;
    p[DspParam.eqQ(i)] = 0.9;
  }
  p[DspParam.drcEnable] = 1;
  p[DspParam.drcThresholdDb] = -24;
  p[DspParam.drcRatio] = 2.5;
  p[DspParam.drcKneeDb] = 6;
  p[DspParam.drcAttackMs] = 15;
  p[DspParam.drcReleaseMs] = 250;
  p[DspParam.drcMakeupDb] = 0;
  p[DspParam.drcMixPercent] = 100;
  p[DspParam.drcDetector] = 1;
  p[DspParam.dialogueEnable] = 1;
  p[DspParam.dialogueIntensityPercent] = 35;
  p[DspParam.bassEnable] = 1;
  p[DspParam.bassIntensityPercent] = 50;
  p[DspParam.bassCrossoverHz] = 80;
  p[DspParam.bassSpeakerMode] = 0;
  p[DspParam.bassSubShelfGainDb] = 5;
  p[DspParam.bassHarmonicDrivePercent] = 0;
  p[DspParam.bassLfeGainDb] = 0;
  p[DspParam.spatialEnable] = 1;
  p[DspParam.spatialMode] = 1;
  p[DspParam.spatialWidthPercent] = 100;
  p[DspParam.spatialBinauralAmountPercent] = 100;
  p[DspParam.roomEnable] = 1;
  p[DspParam.roomWetPercent] = 6;
  p[DspParam.roomSizePercent] = 100;
  p[DspParam.limiterEnable] = 1;
  p[DspParam.limiterCeilingDb] = -1;
  p[DspParam.limiterLookaheadMs] = 5;
  p[DspParam.limiterReleaseMs] = 120;
  return p;
}
