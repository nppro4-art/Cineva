/// Pipeline DSP complet — miroir exact de `native/cineva_dsp/src/cineva_dsp.c`.
///
/// Le même tableau de paramètres + le même PCM d'entrée produisent la même
/// sortie que le cœur C (contrat vérifié par golden tests).
library;

import '../config/param_layout.dart';
import 'bass_processor.dart';
import 'biquad.dart' as dsp;
import 'channel_mapper.dart' as mapper;
import 'dialogue_enhancer.dart';
import 'drc.dart';
import 'loudness.dart';
import 'parametric_eq.dart';
import 'room_processor.dart';
import 'spatial_processor.dart';
import 'true_peak_limiter.dart';

class DartDspPipeline {
  DartDspPipeline({double sampleRate = 48000})
      : _sampleRate = _validRate(sampleRate) {
    loudness = LoudnessProcessor(_sampleRate);
    eq = ParametricEq(_sampleRate);
    drc = DynamicRangeCompressor(_sampleRate);
    dialogue = DialogueEnhancer(_sampleRate);
    bass = BassProcessor(_sampleRate);
    spatial = SpatialProcessor(_sampleRate);
    room = RoomProcessor(_sampleRate);
    limiter = TruePeakLimiter(_sampleRate);
    for (int i = 0; i < kDspMaxChannels; i++) {
      _chan.add(Float32List(kDspMaxBlock));
      _weights.add(1);
    }
    _stereo.add(Float32List(kDspMaxBlock));
    _stereo.add(Float32List(kDspMaxBlock));
    _params = neutralParams(sampleRate: _sampleRate);
    _applyParams();
  }

  static double _validRate(double sr) {
    if (sr.isNaN || sr < 8000 || sr > 192000) return 48000;
    return sr;
  }

  late final LoudnessProcessor loudness;
  late final ParametricEq eq;
  late final DynamicRangeCompressor drc;
  late final DialogueEnhancer dialogue;
  late final BassProcessor bass;
  late final SpatialProcessor spatial;
  late final RoomProcessor room;
  late final TruePeakLimiter limiter;

  double _sampleRate;
  int layout = mapper.layoutStereo;
  late Float64List _params;
  final List<Float32List> _chan = <Float32List>[];
  final List<Float32List> _stereo = <Float32List>[];
  final List<double> _weights = <double>[];

  double integratedLufs = -70;
  double truePeakDb = -999;
  double clippedSamples = 0;
  bool engineActive = false;

  double get sampleRate => _sampleRate;

  double _p(int i, double def, double lo, double hi) {
    double x = _params[i];
    if (x.isNaN || x < -1e30 || x > 1e30) x = def;
    if (x < lo) x = lo;
    if (x > hi) x = hi;
    _params[i] = x;
    return x;
  }

  bool _pBool(int i) => _params[i] != 0 && !_params[i].isNaN;

  void _applyParams() {
    final int inCh = _p(DspParam.inChannels, 2, 1, 8).toInt();
    _p(DspParam.outChannels, 2, 2, 2);
    _p(DspParam.inputLayout, 1, 0, 4);
    layout = mapper.layoutFromChannels(inCh);
    _params[DspParam.inputLayout] = layout.toDouble();

    loudness.set(
      _pBool(DspParam.loudnessEnable),
      _p(DspParam.loudnessTargetLufs, -16, -36, -8),
      _p(DspParam.loudnessMaxGainDb, 8, 0, 12),
      _p(DspParam.loudnessMaxAttenuationDb, 8, 0, 12),
      _p(DspParam.loudnessAdaptRateDbPerSec, 1.5, 0.1, 6),
    );

    final List<int> types = <int>[];
    final List<double> freqs = <double>[], gains = <double>[], qs = <double>[];
    for (int i = 0; i < eqBands; i++) {
      types.add(_p(DspParam.eqType(i), 1, 0, 4).toInt());
      freqs.add(_p(DspParam.eqFreq(i), 1000, 20, 20000));
      gains.add(_p(DspParam.eqGainDb(i), 0, -15, 15));
      qs.add(_p(DspParam.eqQ(i), 0.9, 0.3, 4));
    }
    eq.set(_pBool(DspParam.eqEnable), types, freqs, gains, qs);

    drc.set(
      _pBool(DspParam.drcEnable),
      _p(DspParam.drcThresholdDb, -24, -60, 0),
      _p(DspParam.drcRatio, 2.5, 1, 20),
      _p(DspParam.drcKneeDb, 6, 0, 24),
      _p(DspParam.drcAttackMs, 15, 0.5, 200),
      _p(DspParam.drcReleaseMs, 250, 20, 1000),
      _p(DspParam.drcMakeupDb, 0, -6, 12),
      _p(DspParam.drcMixPercent, 100, 0, 100),
      _p(DspParam.drcDetector, 1, 0, 1).toInt(),
    );

    dialogue.set(
      _pBool(DspParam.dialogueEnable),
      _p(DspParam.dialogueIntensityPercent, 35, 0, 100),
    );

    bass.set(
      _pBool(DspParam.bassEnable),
      _p(DspParam.bassIntensityPercent, 50, 0, 100),
      _p(DspParam.bassCrossoverHz, 80, 50, 160),
      _p(DspParam.bassSpeakerMode, 0, 0, 2).toInt(),
      _p(DspParam.bassSubShelfGainDb, 5, -6, 9),
      _p(DspParam.bassHarmonicDrivePercent, 0, 0, 100),
      _p(DspParam.bassLfeGainDb, 0, -12, 6),
    );

    spatial.set(
      _pBool(DspParam.spatialEnable),
      _p(DspParam.spatialMode, 1, 0, 3).toInt(),
      _p(DspParam.spatialWidthPercent, 100, 0, 150),
      _p(DspParam.spatialCrossfeedPercent, 0, 0, 100),
      _p(DspParam.spatialBinauralAmountPercent, 100, 0, 100),
    );

    room.set(
      _pBool(DspParam.roomEnable),
      _p(DspParam.roomWetPercent, 6, 0, 15),
      _p(DspParam.roomSizePercent, 100, 50, 150),
    );

    limiter.set(
      _pBool(DspParam.limiterEnable),
      _p(DspParam.limiterCeilingDb, -1, -6, 0),
      _p(DspParam.limiterLookaheadMs, 5, 1, 10),
      _p(DspParam.limiterReleaseMs, 120, 40, 500),
    );

    mapper.mapperWeights(layout, inCh, _weights);
  }

  /// Applique un jeu de paramètres. Retourne 0 si OK, -2 si version invalide.
  int setParams(Float64List values) {
    if (values.length != kDspParamCount) return -1;
    final double version = values[DspParam.layoutVersion];
    if (version.isNaN || version.toInt() != kDspParamVersion) return -2;

    final double newSr = _clampRate(values[DspParam.sampleRate]);
    if (newSr != _sampleRate) {
      _sampleRate = newSr;
      loudness = LoudnessProcessor(newSr);
      eq = ParametricEq(newSr);
      drc = DynamicRangeCompressor(newSr);
      dialogue = DialogueEnhancer(newSr);
      bass = BassProcessor(newSr);
      spatial = SpatialProcessor(newSr);
      room = RoomProcessor(newSr);
      limiter = TruePeakLimiter(newSr);
    }

    _params.setAll(0, values);
    _params[DspParam.sampleRate] = _sampleRate;
    _applyParams();
    return 0;
  }

  static double _clampRate(double sr) {
    if (sr.isNaN || sr < 8000 || sr > 192000) return 48000;
    return sr;
  }

  Float64List getParams() {
    final Float64List out = Float64List(kDspParamCount);
    out.setAll(0, _params);
    return out;
  }

  void reset() {
    loudness.reset();
    eq.reset();
    drc.reset();
    dialogue.reset();
    bass.reset();
    spatial.reset();
    room.reset();
    limiter.reset();
    integratedLufs = -70;
    truePeakDb = -999;
    clippedSamples = 0;
  }

  /// Traite un bloc (planar). `out` doit avoir 2 canaux.
  int process(List<Float32List> in_, int inChannels, List<Float32List> out,
      int outChannels, int frames) {
    if (inChannels < 1 || inChannels > kDspMaxChannels) return -1;
    if (outChannels != 2) return -1;
    if (frames <= 0) return 0;

    int offset = 0;
    while (offset < frames) {
      int n = frames - offset;
      if (n > kDspMaxBlock) n = kDspMaxBlock;
      final List<Float32List> chunkIn = <Float32List>[];
      for (int ch = 0; ch < inChannels; ch++) {
        chunkIn.add(Float32List.sublistView(
            in_[ch], offset, offset + n)); // hmm : le C avance les pointeurs
      }
      final List<Float32List> chunkOut = <Float32List>[
        Float32List.sublistView(out[0], offset, offset + n),
        Float32List.sublistView(out[1], offset, offset + n),
      ];
      _processChunk(chunkIn, inChannels, chunkOut, n);
      offset += n;
    }
    return 0;
  }

  void _processChunk(List<Float32List> in_, int inChannels,
      List<Float32List> out, int frames) {
    final bool master = _pBool(DspParam.masterEnable);
    final int layout = this.layout;

    for (int ch = 0; ch < inChannels; ch++) {
      for (int i = 0; i < frames; i++) {
        _chan[ch][i] = dsp.sanitizeD(in_[ch][i]);
      }
    }

    if (!master) {
      for (int i = 0; i < frames; i++) {
        final double l = inChannels > 0 ? in_[0][i] : 0;
        final double r = inChannels > 1 ? in_[1][i] : l;
        final double cl = _clampF(dsp.sanitizeD(l));
        final double cr = _clampF(dsp.sanitizeD(r));
        if (cl != l || cr != r) clippedSamples += 1;
        out[0][i] = cl;
        out[1][i] = cr;
      }
      engineActive = false;
      return;
    }
    engineActive = true;

    loudness.process(_chan, _chan, inChannels, frames, _weights);
    integratedLufs = loudness.integratedLufs;

    dialogue.process(_chan, inChannels, layout, frames);

    final double headroom =
        dsp.dbToLin(_p(DspParam.masterHeadroomDb, 0, -12, 12));
    final bool bassHandlesLfe = bass.enable &&
        _pBool(DspParam.lfeIntoBass) &&
        layout >= mapper.layout51 &&
        inChannels >= 6;
    double lfeDownmixGain = 0;
    if (layout >= mapper.layout51 && inChannels >= 6 && !bassHandlesLfe) {
      lfeDownmixGain = _pBool(DspParam.lfeIntoBass)
          ? dsp.dbToLin(_p(DspParam.bassLfeGainDb, 0, -12, 6))
          : 0;
    }

    if (spatial.enable) {
      spatial.process(_chan, inChannels, layout, _stereo, lfeDownmixGain, frames);
    } else {
      mapper.downmixItu(_chan, inChannels, layout, _stereo, lfeDownmixGain, frames);
    }

    final Float32List? lfePtr = bassHandlesLfe ? _chan[3] : null;
    bass.process(_stereo, lfePtr, frames);

    if (headroom != 1) {
      for (int i = 0; i < frames; i++) {
        _stereo[0][i] = _stereo[0][i] * headroom;
        _stereo[1][i] = _stereo[1][i] * headroom;
      }
    }

    eq.process(_stereo, 2, frames);
    drc.process(_stereo, 2, frames);
    room.process(_stereo, frames);
    limiter.process(_stereo, out, frames);

    for (int i = 0; i < frames; i++) {
      final double l = out[0][i];
      final double r = out[1][i];
      final double pl = l.abs() > r.abs() ? l.abs() : r.abs();
      final double pdb = dsp.linToDb(pl);
      if (pdb > truePeakDb) truePeakDb = pdb;
      final double cl = _clampF(dsp.sanitizeD(l));
      final double cr = _clampF(dsp.sanitizeD(r));
      if (cl != l || cr != r) clippedSamples += 1;
      out[0][i] = cl;
      out[1][i] = cr;
    }
  }

  static double _clampF(double v) {
    if (v.isNaN) return 0;
    if (v < -1) return -1;
    if (v > 1) return 1;
    return v;
  }

  /// Métriques (le true peak est remis après lecture, comme en C).
  Float64List getMetrics() {
    final Float64List m = Float64List(kDspMetricCount);
    m[DspMetric.loudnessLufs] = integratedLufs;
    m[DspMetric.truePeakDb] = truePeakDb;
    truePeakDb = -999;
    m[DspMetric.loudnessGainDb] = loudness.gainDb;
    m[DspMetric.limiterGainDb] = limiter.gainDb;
    m[DspMetric.clippedSamples] = clippedSamples;
    clippedSamples = 0;
    m[DspMetric.engineActive] = engineActive ? 1 : 0;
    return m;
  }
}
