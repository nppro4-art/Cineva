/*
 * Cineva Audio Engine — AudioWorklet (Web).
 *
 * Même pipeline et même contrat de paramètres (128 doubles, version 1)
 * que le cœur C (`native/cineva_dsp`) et le cœur Dart.
 *
 * Ce fichier s'exécute dans deux contextes :
 *  - AudioWorkletGlobalScope (chargé via audioWorklet.addModule) :
 *    enregistre le processeur 'cineva-audio-processor' ;
 *  - contexte page (chargé via <script>) : expose la glue
 *    globalThis.__cinevaAudioEngine qui branche l'élément <video>
 *    dans le graphe Web Audio.
 */
(function () {
  'use strict';

  // ─────────────────────────── Utilitaires ───────────────────────────

  const PARAM_VERSION = 1;
  const PARAM_COUNT = 128;
  const MAX_CHANNELS = 8;
  const MAX_BLOCK = 8192;

  const P = {
    layoutVersion: 0, sampleRate: 1, masterEnable: 2, inChannels: 3,
    outChannels: 4, inputLayout: 5, lfeIntoBass: 6, masterHeadroomDb: 7,
    loudnessEnable: 8, loudnessTargetLufs: 9, loudnessMaxGainDb: 10,
    loudnessMaxAttenuationDb: 11, loudnessAdaptRateDbPerSec: 12,
    eqEnable: 16,
    drcEnable: 48, drcThresholdDb: 49, drcRatio: 50, drcKneeDb: 51,
    drcAttackMs: 52, drcReleaseMs: 53, drcMakeupDb: 54, drcMixPercent: 55,
    drcDetector: 56,
    dialogueEnable: 60, dialogueIntensityPercent: 61,
    bassEnable: 68, bassIntensityPercent: 69, bassCrossoverHz: 70,
    bassSpeakerMode: 71, bassSubShelfGainDb: 72, bassHarmonicDrivePercent: 73,
    bassLfeGainDb: 74,
    spatialEnable: 80, spatialMode: 81, spatialWidthPercent: 82,
    spatialCrossfeedPercent: 83, spatialBinauralAmountPercent: 84,
    roomEnable: 92, roomWetPercent: 93, roomSizePercent: 94,
    limiterEnable: 100, limiterCeilingDb: 101, limiterLookaheadMs: 102,
    limiterReleaseMs: 103,
  };

  function eqType(b) { return 17 + 5 * b; }
  function eqFreq(b) { return 18 + 5 * b; }
  function eqGain(b) { return 19 + 5 * b; }
  function eqQ(b) { return 20 + 5 * b; }

  function clampD(v, lo, hi) {
    if (typeof v !== 'number' || !isFinite(v)) return lo;
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
  }
  function sanitizeD(v) {
    return (typeof v === 'number' && isFinite(v) && v > -1e30 && v < 1e30) ? v : 0;
  }
  function dbToLin(db) { return Math.pow(10, db / 20); }
  function linToDb(lin) { return 20 * Math.log10(lin > 1e-12 ? lin : 1e-12); }
  function onepoleCoef(sr, tau) {
    if (tau <= 0 || sr <= 0) return 0;
    return Math.exp(-1 / (sr * tau));
  }
  function pNum(params, i, def, lo, hi) {
    return clampD(sanitizeD(params[i]), lo, hi);
  }

  const LAYOUT_MONO = 0, LAYOUT_STEREO = 1, LAYOUT_QUAD = 2, LAYOUT_51 = 3, LAYOUT_71 = 4;
  function layoutFromChannels(c) {
    if (c === 1) return LAYOUT_MONO;
    if (c === 2) return LAYOUT_STEREO;
    if (c === 4) return LAYOUT_QUAD;
    if (c === 6) return LAYOUT_51;
    if (c === 8) return LAYOUT_71;
    return c > 2 ? LAYOUT_71 : (c < 1 ? LAYOUT_MONO : LAYOUT_STEREO);
  }
  function mapperWeights(layout, channels) {
    const w = new Array(MAX_CHANNELS).fill(1);
    if (layout >= LAYOUT_51 && channels >= 6) {
      w[4] = 1.4142135623730951; w[5] = 1.4142135623730951; w[3] = 0;
    }
    if (layout >= LAYOUT_71 && channels >= 8) {
      w[6] = 1.4142135623730951; w[7] = 1.4142135623730951;
    }
    return w;
  }
  function downmixItu(inCh, channels, layout, out, lfeGainLin, frames) {
    const lg = Math.max(0, sanitizeD(lfeGainLin));
    if (channels <= 1) {
      for (let i = 0; i < frames; i++) { out[0][i] = inCh[0][i]; out[1][i] = inCh[0][i]; }
      return;
    }
    const hasCenter = layout >= LAYOUT_51 && channels >= 6;
    const hasSurround = layout >= LAYOUT_QUAD && channels >= 4;
    const hasLfe = layout >= LAYOUT_51 && channels >= 6;
    const hasBack = layout >= LAYOUT_71 && channels >= 8;
    for (let i = 0; i < frames; i++) {
      let l = sanitizeD(inCh[0][i]);
      let r = sanitizeD(inCh[1][i]);
      if (hasCenter) { const c = sanitizeD(inCh[2][i]) * 0.7071067811865476; l += c; r += c; }
      if (hasSurround) {
        l += sanitizeD(inCh[4 % channels][i]) * 0.7071067811865476;
        r += sanitizeD(inCh[5 % channels][i]) * 0.7071067811865476;
      }
      if (hasBack) {
        l += sanitizeD(inCh[6][i]) * 0.7071067811865476;
        r += sanitizeD(inCh[7][i]) * 0.7071067811865476;
      }
      if (hasLfe && lg > 0) { const lfe = sanitizeD(inCh[3][i]) * lg; l += lfe; r += lfe; }
      out[0][i] = l; out[1][i] = r;
    }
  }

  // ─────────────────────────── Biquad ───────────────────────────

  const BQ_LOWSHELF = 0, BQ_PEAKING = 1, BQ_HIGHSHELF = 2, BQ_LOWPASS = 3, BQ_HIGHPASS = 4;

  class Biquad {
    constructor() { this.b0 = 1; this.b1 = 0; this.b2 = 0; this.a1 = 0; this.a2 = 0;
      this.tb0 = 1; this.tb1 = 0; this.tb2 = 0; this.ta1 = 0; this.ta2 = 0;
      this.s1 = 0; this.s2 = 0; this.ramp = false; }
    setRaw(tb0, tb1, tb2, ta1, ta2) {
      this.tb0 = tb0; this.tb1 = tb1; this.tb2 = tb2; this.ta1 = ta1; this.ta2 = ta2;
      this.ramp = true;
    }
    snap() { this.b0 = this.tb0; this.b1 = this.tb1; this.b2 = this.tb2;
      this.a1 = this.ta1; this.a2 = this.ta2; this.ramp = false; }
    resetState() { this.s1 = 0; this.s2 = 0; }
    set(type, freqHz, gainDb, q, sampleRate) {
      const fs = sampleRate > 0 ? sampleRate : 48000;
      const f0 = clampD(freqHz, 10, fs * 0.49);
      const qq = clampD(q, 0.1, 20);
      const A = Math.pow(10, clampD(gainDb, -40, 40) / 40);
      const w0 = 2 * Math.PI * f0 / fs;
      const cw = Math.cos(w0), sw = Math.sin(w0);
      const alpha = sw / (2 * qq);
      let b0 = 1, b1 = 0, b2 = 0, a0 = 1, a1 = 0, a2 = 0;
      if (type === BQ_LOWSHELF) {
        const sq = 2 * Math.sqrt(A) * alpha;
        b0 = A * ((A + 1) - (A - 1) * cw + sq);
        b1 = 2 * A * ((A - 1) - (A + 1) * cw);
        b2 = A * ((A + 1) - (A - 1) * cw - sq);
        a0 = (A + 1) + (A - 1) * cw + sq;
        a1 = -2 * ((A - 1) + (A + 1) * cw);
        a2 = (A + 1) + (A - 1) * cw - sq;
      } else if (type === BQ_HIGHSHELF) {
        const sq = 2 * Math.sqrt(A) * alpha;
        b0 = A * ((A + 1) + (A - 1) * cw + sq);
        b1 = -2 * A * ((A - 1) + (A + 1) * cw);
        b2 = A * ((A + 1) + (A - 1) * cw - sq);
        a0 = (A + 1) - (A - 1) * cw + sq;
        a1 = 2 * ((A - 1) - (A + 1) * cw);
        a2 = (A + 1) - (A - 1) * cw - sq;
      } else if (type === BQ_LOWPASS) {
        b0 = (1 - cw) * 0.5; b1 = 1 - cw; b2 = (1 - cw) * 0.5;
        a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha;
      } else if (type === BQ_HIGHPASS) {
        b0 = (1 + cw) * 0.5; b1 = -(1 + cw); b2 = (1 + cw) * 0.5;
        a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha;
      } else {
        b0 = 1 + alpha * A; b1 = -2 * cw; b2 = 1 - alpha * A;
        a0 = 1 + alpha / A; a1 = -2 * cw; a2 = 1 - alpha / A;
      }
      if (!(a0 > 0) || !isFinite(a0)) a0 = 1;
      this.setRaw(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
    }
    tick(x, rampCoef) {
      if (this.ramp) {
        this.b0 += (this.tb0 - this.b0) * rampCoef;
        this.b1 += (this.tb1 - this.b1) * rampCoef;
        this.b2 += (this.tb2 - this.b2) * rampCoef;
        this.a1 += (this.ta1 - this.a1) * rampCoef;
        this.a2 += (this.ta2 - this.a2) * rampCoef;
        const e0 = this.b0 - this.tb0, e1 = this.b1 - this.tb1, e2 = this.b2 - this.tb2;
        const e3 = this.a1 - this.ta1, e4 = this.a2 - this.ta2;
        if (e0 * e0 + e1 * e1 + e2 * e2 + e3 * e3 + e4 * e4 < 1e-18) this.snap();
      }
      const y = this.b0 * x + this.s1;
      this.s1 = this.b1 * x - this.a1 * y + this.s2;
      this.s2 = this.b2 * x - this.a2 * y;
      return y;
    }
  }

  // ─────────────────────────── Loudness (BS.1770-4) ───────────────────────────

  const LOUDNESS_HOPS = 600;
  const LOUDNESS_OFFSET = -0.691;

  class Loudness {
    constructor(sr) {
      this.sr = sr;
      this.hopLen = Math.max(1, Math.floor(sr * 0.1));
      this.hopPos = 0;
      this.hopMs = new Float64Array(MAX_CHANNELS);
      this.k1 = []; this.k2 = [];
      for (let i = 0; i < MAX_CHANNELS; i++) {
        const k1 = new Biquad(), k2 = new Biquad();
        k1.set(BQ_HIGHSHELF, 1681.97, 3.9998, 0.7071752369556, sr);
        k2.set(BQ_HIGHPASS, 38.13, 0, 0.5003270372833, sr);
        k1.snap(); k2.snap();
        this.k1.push(k1); this.k2.push(k2);
      }
      this.hopZ = new Float64Array(LOUDNESS_HOPS);
      this.hopCount = 0; this.hopHead = 0; this.silentRun = 0;
      this.integratedLufs = -70; this.gainDb = 0; this.targetGainDb = 0;
      this.set(true, -16, 8, 8, 1.5);
    }
    set(enable, targetLufs, maxGainDb, maxAttDb, adaptRate) {
      this.enable = !!enable;
      this.targetLufs = pNum([targetLufs], 0, -16, -36, -8);
      this.maxGainDb = clampD(sanitizeD(maxGainDb), 0, 12);
      this.maxAttDb = clampD(sanitizeD(maxAttDb), 0, 12);
      this.adaptRate = clampD(sanitizeD(adaptRate), 0.1, 6);
    }
    reset() {
      this.hopPos = 0; this.hopMs.fill(0); this.hopZ.fill(0);
      this.hopCount = 0; this.hopHead = 0; this.silentRun = 0;
      this.integratedLufs = -70; this.gainDb = 0; this.targetGainDb = 0;
      for (let i = 0; i < MAX_CHANNELS; i++) { this.k1[i].resetState(); this.k2[i].resetState(); }
    }
    recompute() {
      const n = this.hopCount;
      if (n <= 0) { this.integratedLufs = -70; return; }
      let sum = 0, count = 0;
      for (let i = 0; i < n; i++) {
        const z = this.hopZ[i];
        if (z <= 0) continue;
        if (LOUDNESS_OFFSET + 10 * Math.log10(z) > -70) { sum += z; count++; }
      }
      if (count === 0 || sum <= 0) { this.integratedLufs = -70; return; }
      const meanZ = sum / count;
      const relThr = LOUDNESS_OFFSET + 10 * Math.log10(meanZ) - 10;
      let sum2 = 0, count2 = 0;
      for (let i = 0; i < n; i++) {
        const z = this.hopZ[i];
        if (z <= 0) continue;
        const lb = LOUDNESS_OFFSET + 10 * Math.log10(z);
        if (lb > -70 && lb > relThr) { sum2 += z; count2++; }
      }
      if (count2 === 0 || sum2 <= 0) { this.integratedLufs = -70; return; }
      this.integratedLufs = LOUDNESS_OFFSET + 10 * Math.log10(sum2 / count2);
    }
    process(inCh, outCh, channels, frames, weights) {
      if (channels < 1 || channels > MAX_CHANNELS) return;
      const ramp = 1 - onepoleCoef(this.sr, 0.02);
      const gainStepDb = this.adaptRate / this.sr;
      for (let ch = 0; ch < channels; ch++) {
        if (outCh[ch] !== inCh[ch]) {
          const src = inCh[ch], dst = outCh[ch];
          for (let i = 0; i < frames; i++) dst[i] = src[i];
        }
      }
      if (!this.enable) { this.gainDb = 0; this.targetGainDb = 0; return; }
      for (let i = 0; i < frames; i++) {
        for (let ch = 0; ch < channels; ch++) {
          const x = sanitizeD(inCh[ch][i]);
          let y = this.k1[ch].tick(x, ramp);
          y = this.k2[ch].tick(y, ramp);
          this.hopMs[ch] += y * y;
        }
        this.hopPos++;
        if (this.hopPos >= this.hopLen) {
          this.hopPos = 0;
          let z = 0;
          for (let ch = 0; ch < channels; ch++) {
            z += weights[ch] * (this.hopMs[ch] / this.hopLen);
            this.hopMs[ch] = 0;
          }
          this.hopZ[this.hopHead] = z;
          this.hopHead = (this.hopHead + 1) % LOUDNESS_HOPS;
          if (this.hopCount < LOUDNESS_HOPS) this.hopCount++;
          this.silentRun = z < 1e-10 ? this.silentRun + 1 : 0;
          this.recompute();
          if (this.silentRun >= 10 || this.integratedLufs <= -69.9) {
            this.targetGainDb = this.gainDb;
          } else {
            this.targetGainDb = clampD(this.targetLufs - this.integratedLufs, -this.maxAttDb, this.maxGainDb);
          }
        }
        if (this.gainDb < this.targetGainDb) {
          this.gainDb = Math.min(this.gainDb + gainStepDb, this.targetGainDb);
        } else if (this.gainDb > this.targetGainDb) {
          this.gainDb = Math.max(this.gainDb - gainStepDb, this.targetGainDb);
        }
        const g = dbToLin(this.gainDb);
        for (let ch = 0; ch < channels; ch++) outCh[ch][i] = sanitizeD(outCh[ch][i]) * g;
      }
    }
  }

  // ─────────────────────────── EQ ───────────────────────────

  const EQ_BANDS = 6;
  const EQ_DEF_TYPES = [BQ_LOWSHELF, BQ_PEAKING, BQ_PEAKING, BQ_PEAKING, BQ_PEAKING, BQ_HIGHSHELF];
  const EQ_DEF_FREQS = [45, 90, 300, 1200, 3500, 10000];

  class ParametricEq {
    constructor(sr) {
      this.sr = sr;
      this.types = EQ_DEF_TYPES.slice();
      this.freq = EQ_DEF_FREQS.slice();
      this.gainDb = new Array(EQ_BANDS).fill(0);
      this.q = new Array(EQ_BANDS).fill(0.9);
      this.bands = [];
      for (let i = 0; i < EQ_BANDS; i++) this.bands.push([new Biquad(), new Biquad()]);
      this.dirty = true;
    }
    set(enable, types, freq, gainDb, q) {
      this.enable = !!enable;
      for (let i = 0; i < EQ_BANDS; i++) {
        const t = clampD(types[i], 0, 4) | 0;
        const f = pNum(freq, i, 1000, 20, 20000);
        const g = pNum(gainDb, i, 0, -15, 15);
        const qq = pNum(q, i, 0.9, 0.3, 4);
        if (t !== this.types[i] || f !== this.freq[i] || g !== this.gainDb[i] || qq !== this.q[i]) {
          this.types[i] = t; this.freq[i] = f; this.gainDb[i] = g; this.q[i] = qq;
          this.dirty = true;
        }
      }
    }
    reset() { for (const pair of this.bands) { pair[0].resetState(); pair[1].resetState(); } }
    process(io, channels, frames) {
      if (!this.enable) return;
      if (channels < 1 || channels > 2) return;
      if (this.dirty) {
        for (let i = 0; i < EQ_BANDS; i++) {
          for (let ch = 0; ch < 2; ch++) this.bands[i][ch].set(this.types[i], this.freq[i], this.gainDb[i], this.q[i], this.sr);
        }
        this.dirty = false;
      }
      const ramp = 1 - onepoleCoef(this.sr, 0.02);
      for (let i = 0; i < frames; i++) {
        let l = sanitizeD(io[0][i]);
        let r = channels > 1 ? sanitizeD(io[1][i]) : l;
        for (let b = 0; b < EQ_BANDS; b++) {
          l = this.bands[b][0].tick(l, ramp);
          r = this.bands[b][1].tick(r, ramp);
        }
        io[0][i] = l;
        if (channels > 1) io[1][i] = r;
      }
    }
  }

  // ─────────────────────────── DRC ───────────────────────────

  class Drc {
    constructor(sr) { this.sr = sr; this.envDb = -70; this.gainDb = 0; this.rmsState = 0; this.set(false, -24, 2.5, 6, 15, 250, 0, 100, 1); }
    set(enable, thresholdDb, ratio, kneeDb, attackMs, releaseMs, makeupDb, mixPercent, detector) {
      this.enable = !!enable;
      this.thresholdDb = pNum([thresholdDb], 0, -24, -60, 0);
      this.ratio = clampD(sanitizeD(ratio), 1, 20);
      this.kneeDb = clampD(sanitizeD(kneeDb), 0, 24);
      this.attackMs = clampD(sanitizeD(attackMs), 0.5, 200);
      this.releaseMs = clampD(sanitizeD(releaseMs), 20, 1000);
      this.makeupDb = clampD(sanitizeD(makeupDb), -6, 12);
      this.mix = clampD(sanitizeD(mixPercent), 0, 100) / 100;
      this.detector = detector === 0 ? 0 : 1;
      this.attCoef = onepoleCoef(this.sr, this.attackMs / 1000);
      this.relCoef = onepoleCoef(this.sr, this.releaseMs / 1000);
      this.rmsCoef = onepoleCoef(this.sr, 0.010);
    }
    reset() { this.envDb = -70; this.gainDb = 0; this.rmsState = 0; }
    computeGainDb(levelDb) {
      const slope = 1 / this.ratio - 1;
      const over = levelDb - this.thresholdDb;
      if (this.kneeDb > 0 && 2 * over < this.kneeDb && 2 * over > -this.kneeDb) {
        const x = over + this.kneeDb * 0.5;
        return slope * x * x / (2 * this.kneeDb);
      }
      if (over <= 0) return 0;
      return slope * over;
    }
    process(io, channels, frames) {
      if (!this.enable) return;
      if (channels < 1 || channels > 2) return;
      let rmsState = this.rmsState;
      const makeup = dbToLin(this.makeupDb);
      const dryMix = 1 - this.mix;
      for (let i = 0; i < frames; i++) {
        const l = sanitizeD(io[0][i]);
        const r = channels > 1 ? sanitizeD(io[1][i]) : l;
        let level;
        if (this.detector === 0) {
          level = Math.max(Math.abs(l), Math.abs(r));
        } else {
          const ms = (l * l + r * r) * 0.5;
          rmsState = this.rmsCoef * rmsState + (1 - this.rmsCoef) * ms;
          level = Math.sqrt(rmsState);
        }
        const levelDb = linToDb(level);
        if (levelDb > this.envDb) {
          this.envDb = this.attCoef * this.envDb + (1 - this.attCoef) * levelDb;
        } else {
          this.envDb = this.relCoef * this.envDb + (1 - this.relCoef) * levelDb;
        }
        const targetGain = this.computeGainDb(this.envDb);
        if (targetGain < this.gainDb) {
          this.gainDb = this.attCoef * this.gainDb + (1 - this.attCoef) * targetGain;
        } else {
          this.gainDb = this.relCoef * this.gainDb + (1 - this.relCoef) * targetGain;
        }
        const wetGain = dbToLin(this.gainDb) * makeup;
        const g = dryMix + wetGain * this.mix;
        io[0][i] = l * g;
        if (channels > 1) io[1][i] = r * g;
      }
      this.rmsState = rmsState;
    }
  }

  // ─────────────────────────── Dialogue ───────────────────────────

  class Dialogue {
    constructor(sr) {
      this.sr = sr;
      const mk = (type, f, q) => { const b = new Biquad(); b.set(type, f, 0, q, sr); b.snap(); return b; };
      this.hpMid = [mk(BQ_HIGHPASS, 1200, 0.707), mk(BQ_HIGHPASS, 1200, 0.707)];
      this.lpMid = [mk(BQ_LOWPASS, 4500, 0.707), mk(BQ_LOWPASS, 4500, 0.707)];
      this.hpSide = [mk(BQ_HIGHPASS, 1200, 0.707), mk(BQ_HIGHPASS, 1200, 0.707)];
      this.lpSide = [mk(BQ_LOWPASS, 4500, 0.707), mk(BQ_LOWPASS, 4500, 0.707)];
      this.hpMud = [mk(BQ_HIGHPASS, 200, 0.707), mk(BQ_HIGHPASS, 200, 0.707)];
      this.lpMud = [mk(BQ_LOWPASS, 350, 0.707), mk(BQ_LOWPASS, 350, 0.707)];
      this.hpMudLr = [mk(BQ_HIGHPASS, 200, 0.707), mk(BQ_HIGHPASS, 200, 0.707)];
      this.lpMudLr = [mk(BQ_LOWPASS, 350, 0.707), mk(BQ_LOWPASS, 350, 0.707)];
      this.hpC = mk(BQ_HIGHPASS, 1200, 0.707);
      this.lpC = mk(BQ_LOWPASS, 4500, 0.707);
      this.set(true, 35);
    }
    set(enable, intensityPercent) {
      this.enable = !!enable;
      this.intensity = clampD(sanitizeD(intensityPercent), 0, 100) / 100;
    }
    reset() {
      for (const b of [...this.hpMid, ...this.lpMid, ...this.hpSide, ...this.lpSide,
        ...this.hpMud, ...this.lpMud, ...this.hpMudLr, ...this.lpMudLr, this.hpC, this.lpC]) b.resetState();
    }
    process(io, channels, layout, frames) {
      if (!this.enable || this.intensity <= 0) return;
      if (channels < 1 || frames <= 0) return;
      const ramp = 1 - onepoleCoef(this.sr, 0.02);
      const amt = this.intensity;
      const presenceAdd = (dbToLin(4) - 1) * amt;
      const mudSub = (1 - dbToLin(-2)) * amt;
      const sideSub = (1 - dbToLin(-1.5)) * amt;
      const multichannel = layout >= LAYOUT_51 && channels >= 6;
      for (let i = 0; i < frames; i++) {
        if (multichannel) {
          const c = sanitizeD(io[2][i]);
          let cp = this.hpC.tick(c, ramp);
          cp = this.lpC.tick(cp, ramp);
          io[2][i] = c + cp * presenceAdd;
          for (let ch = 0; ch < 2; ch++) {
            const x = sanitizeD(io[ch][i]);
            let mud = this.hpMudLr[ch].tick(x, ramp);
            mud = this.lpMudLr[ch].tick(mud, ramp);
            io[ch][i] = x - mud * mudSub;
          }
        }
        if (channels >= 2) {
          const l = sanitizeD(io[0][i]);
          const r = sanitizeD(io[1][i]);
          let m = (l + r) * 0.5;
          let s = (l - r) * 0.5;
          let mp = this.hpMid[0].tick(m, ramp);
          mp = this.lpMid[0].tick(mp, ramp);
          m += mp * presenceAdd;
          let mmud = this.hpMud[0].tick(m, ramp);
          mmud = this.lpMud[0].tick(mmud, ramp);
          m -= mmud * mudSub;
          let sp = this.hpSide[0].tick(s, ramp);
          sp = this.lpSide[0].tick(sp, ramp);
          s -= sp * sideSub;
          io[0][i] = m + s;
          io[1][i] = m - s;
        }
      }
    }
  }

  // ─────────────────────────── Bass ───────────────────────────

  class Bass {
    constructor(sr) {
      this.sr = sr;
      this.crossoverHz = 80; this.speakerMode = 0; this.subShelfGainDb = 5;
      this.harmonicDrive = 0; this.lfeGainDb = 0; this.intensity = 0.5;
      this.lp = [[new Biquad(), new Biquad()], [new Biquad(), new Biquad()]];
      this.hp = [[new Biquad(), new Biquad()], [new Biquad(), new Biquad()]];
      this.subShelf = [new Biquad(), new Biquad()];
      this.harmHp = [new Biquad(), new Biquad()];
      this.bandEnv = 0;
      this.bandThrLin = dbToLin(-1);
      this.dirty = true;
    }
    set(enable, intensityPercent, crossoverHz, speakerMode, subShelfGainDb, harmonicDrivePercent, lfeGainDb) {
      const wasDisabled = !this.enable;
      this.enable = !!enable;
      this.intensity = clampD(sanitizeD(intensityPercent), 0, 100) / 100;
      const xo = clampD(sanitizeD(crossoverHz), 50, 160);
      if (xo !== this.crossoverHz) { this.crossoverHz = xo; this.dirty = true; }
      let mode = speakerMode | 0;
      if (mode < 0 || mode > 2) mode = 0;
      if (mode !== this.speakerMode) { this.speakerMode = mode; this.dirty = true; }
      this.subShelfGainDb = clampD(sanitizeD(subShelfGainDb), -6, 9);
      let drive = clampD(sanitizeD(harmonicDrivePercent), 0, 100) / 100;
      if (this.speakerMode === 0 || this.speakerMode === 2) drive = 0;
      if (drive !== this.harmonicDrive) { this.harmonicDrive = drive; this.dirty = true; }
      this.lfeGainDb = clampD(sanitizeD(lfeGainDb), -12, 6);
      if (wasDisabled && this.enable) this.dirty = true;
    }
    updateFilters() {
      for (let ch = 0; ch < 2; ch++) {
        for (let s = 0; s < 2; s++) {
          this.lp[ch][s].set(BQ_LOWPASS, this.crossoverHz, 0, 0.7071, this.sr);
          this.hp[ch][s].set(BQ_HIGHPASS, this.crossoverHz, 0, 0.7071, this.sr);
        }
        let subDb = this.subShelfGainDb * this.intensity;
        if (this.speakerMode === 2) subDb *= 0.6;
        if (this.speakerMode === 1) subDb *= 0.8;
        this.subShelf[ch].set(BQ_LOWSHELF, 50, subDb, 0.707, this.sr);
        this.harmHp[ch].set(BQ_HIGHPASS, this.crossoverHz * 0.9, 0, 0.707, this.sr);
      }
      this.dirty = false;
    }
    reset() {
      for (let ch = 0; ch < 2; ch++) {
        for (let s = 0; s < 2; s++) { this.lp[ch][s].resetState(); this.hp[ch][s].resetState(); }
        this.subShelf[ch].resetState(); this.harmHp[ch].resetState();
      }
      this.bandEnv = 0;
    }
    process(io, lfe, frames) {
      if (!this.enable) return;
      if (this.dirty) this.updateFilters();
      const ramp = 1 - onepoleCoef(this.sr, 0.02);
      const rel = onepoleCoef(this.sr, 0.020);
      const lfeGain = lfe ? dbToLin(this.lfeGainDb) : 0;
      const driveK = 1 + 2 * this.harmonicDrive;
      const driveNorm = Math.tanh(driveK);
      const low = [0, 0], high = [0, 0];
      for (let i = 0; i < frames; i++) {
        for (let ch = 0; ch < 2; ch++) {
          const x = sanitizeD(io[ch][i]);
          let l = this.lp[ch][0].tick(x, ramp);
          l = this.lp[ch][1].tick(l, ramp);
          let h = this.hp[ch][0].tick(x, ramp);
          h = this.hp[ch][1].tick(h, ramp);
          low[ch] = l; high[ch] = h;
        }
        if (lfe) {
          const l = sanitizeD(lfe[i]) * lfeGain;
          low[0] += l; low[1] += l;
        }
        low[0] = this.subShelf[0].tick(low[0], ramp);
        low[1] = this.subShelf[1].tick(low[1], ramp);
        if (this.harmonicDrive > 0) {
          for (let ch = 0; ch < 2; ch++) {
            const sat = Math.tanh(low[ch] * driveK) / driveNorm;
            let harm = sat - low[ch];
            harm = this.harmHp[ch].tick(harm, ramp);
            high[ch] += harm * this.harmonicDrive;
          }
        }
        const peak = Math.max(Math.abs(low[0]), Math.abs(low[1]));
        let need = 1;
        if (peak > this.bandThrLin) need = this.bandThrLin / peak;
        if (need < this.bandEnv) this.bandEnv = need;
        else this.bandEnv = rel * this.bandEnv + (1 - rel) * need;
        io[0][i] = low[0] * this.bandEnv + high[0];
        io[1][i] = low[1] * this.bandEnv + high[1];
      }
    }
  }

  // ─────────────────────────── Spatial ───────────────────────────

  const SPATIAL_MAX_DELAY = 512;

  function azimuthFor(layout, ch) {
    if (layout === LAYOUT_QUAD) return [-30, 30, -105, 105][ch] ?? 105;
    if (layout === LAYOUT_51 || layout === LAYOUT_71) {
      return [-30, 30, 0, 0, -105, 105, -140, 140][ch] ?? 140;
    }
    return ch === 0 ? -30 : 30;
  }

  class Spatial {
    constructor(sr) {
      this.sr = sr;
      this.mode = 1; this.width = 1; this.crossfeed = 0; this.binauralAmount = 1;
      this.contraShelf = []; this.rearMuffle = []; this.frontPeak = [];
      this.delayLine = []; this.delayPos = []; this.contraDelaySmp = [];
      this.ituMix = []; this.binaMix = []; this.chIsRear = [];
      for (let ch = 0; ch < MAX_CHANNELS; ch++) {
        this.contraShelf.push(new Biquad()); this.rearMuffle.push(new Biquad()); this.frontPeak.push(new Biquad());
        this.delayLine.push(new Float64Array(SPATIAL_MAX_DELAY));
        this.delayPos.push(0); this.contraDelaySmp.push(0);
        this.ituMix.push(0); this.binaMix.push(0); this.chIsRear.push(false);
      }
      this.cfLine = [new Float64Array(SPATIAL_MAX_DELAY), new Float64Array(SPATIAL_MAX_DELAY)];
      this.cfPos = [0, 0];
      this.cfLp = [new Biquad(), new Biquad()];
      this.lfeGainLin = 0;
      this._channels = 0; this._layout = -1;
      this.dirty = true;
    }
    set(enable, mode, widthPercent, crossfeedPercent, binauralAmountPercent) {
      this.enable = !!enable;
      let m = mode | 0;
      if (m < 0 || m > 3) m = 1;
      if (m !== this.mode) { this.mode = m; this.dirty = true; }
      this.width = clampD(sanitizeD(widthPercent), 0, 150) / 100;
      this.crossfeed = clampD(sanitizeD(crossfeedPercent), 0, 100) / 100;
      this.binauralAmount = clampD(sanitizeD(binauralAmountPercent), 0, 100) / 100;
    }
    configure(channels, layout) {
      this._channels = channels; this._layout = layout;
      for (let ch = 0; ch < MAX_CHANNELS; ch++) {
        this.ituMix[ch] = 0; this.binaMix[ch] = 0; this.chIsRear[ch] = false; this.contraDelaySmp[ch] = 0;
      }
      for (let ch = 0; ch < channels; ch++) {
        const az = azimuthFor(layout, ch);
        const isLfe = layout >= LAYOUT_51 && ch === 3;
        if (isLfe) continue;
        const isCenter = layout >= LAYOUT_51 && ch === 2;
        const isRear = Math.abs(az) >= 90;
        this.chIsRear[ch] = isRear;
        this.ituMix[ch] = 0.707;
        let ipsi = 1;
        if (isCenter) ipsi = 0.85;
        if (isRear) ipsi = 0.75;
        this.binaMix[ch] = ipsi;
        if (Math.abs(az) > 1) {
          const itdS = 0.00065 * Math.sin(Math.abs(az) * Math.PI / 180);
          this.contraDelaySmp[ch] = itdS * this.sr;
        }
        const ild = isRear ? 10 : 7;
        this.contraShelf[ch].set(BQ_HIGHSHELF, 2000, -ild, 0.707, this.sr);
        if (isRear) this.rearMuffle[ch].set(BQ_LOWSHELF, 5000, -4, 0.707, this.sr);
        else this.rearMuffle[ch].setRaw(1, 0, 0, 0, 0);
        if (!isRear && !isCenter) this.frontPeak[ch].set(BQ_PEAKING, 5500, 1.5, 1.2, this.sr);
        else if (isCenter) this.frontPeak[ch].set(BQ_PEAKING, 5500, 0.8, 1.2, this.sr);
        else this.frontPeak[ch].setRaw(1, 0, 0, 0, 0);
      }
      for (let i = 0; i < 2; i++) this.cfLp[i].set(BQ_LOWPASS, 700, 0, 0.707, this.sr);
      this.dirty = false;
    }
    reset() {
      for (let ch = 0; ch < MAX_CHANNELS; ch++) {
        this.contraShelf[ch].resetState(); this.rearMuffle[ch].resetState(); this.frontPeak[ch].resetState();
        this.delayLine[ch].fill(0); this.delayPos[ch] = 0;
      }
      for (let i = 0; i < 2; i++) { this.cfLp[i].resetState(); this.cfLine[i].fill(0); this.cfPos[i] = 0; }
      this.dirty = true;
    }
    static delayRead(line, write, delaySmp) {
      const len = SPATIAL_MAX_DELAY;
      let read = write - delaySmp;
      if (read < 0) read += len;
      const i0 = Math.floor(read);
      const frac = read - i0;
      let i1 = i0 - 1;
      if (i1 < 0) i1 += len;
      const a = line[i0], b = line[i1];
      return a + (b - a) * frac;
    }
    process(inCh, channels, layout, out, lfeGainLin, frames) {
      if (!this.enable || channels < 1 || frames <= 0) {
        for (let i = 0; i < frames; i++) {
          out[0][i] = inCh[0][i];
          out[1][i] = channels > 1 ? inCh[1][i] : inCh[0][i];
        }
        return;
      }
      this.lfeGainLin = Math.max(0, sanitizeD(lfeGainLin));
      if (channels <= 2) {
        const width = this.mode === 0 ? 1 : this.width;
        const ramp = 1 - onepoleCoef(this.sr, 0.02);
        const cfGain = this.crossfeed * dbToLin(-8);
        const cfDelay = 0.00025 * this.sr;
        const doCf = cfGain > 0.0001 && layout !== LAYOUT_MONO;
        for (let i = 0; i < frames; i++) {
          let l = sanitizeD(inCh[0][i]);
          let r = channels > 1 ? sanitizeD(inCh[1][i]) : l;
          const m = (l + r) * 0.5;
          const s = (l - r) * 0.5 * width;
          l = m + s; r = m - s;
          if (doCf) {
            this.cfLine[0][this.cfPos[0] | 0] = r;
            this.cfLine[1][this.cfPos[1] | 0] = l;
            let cr = Spatial.delayRead(this.cfLine[0], this.cfPos[0] | 0, cfDelay);
            let cl = Spatial.delayRead(this.cfLine[1], this.cfPos[1] | 0, cfDelay);
            cr = this.cfLp[0].tick(cr, ramp);
            cl = this.cfLp[1].tick(cl, ramp);
            l += cr * cfGain;
            r += cl * cfGain;
            this.cfPos[0] = (this.cfPos[0] + 1) % SPATIAL_MAX_DELAY;
            this.cfPos[1] = (this.cfPos[1] + 1) % SPATIAL_MAX_DELAY;
          }
          out[0][i] = l; out[1][i] = r;
        }
        return;
      }
      if (this.dirty || this._channels !== channels || this._layout !== layout) {
        this.configure(channels, layout);
      }
      const ramp = 1 - onepoleCoef(this.sr, 0.02);
      const amt = this.mode >= 2 ? this.binauralAmount : 0;
      const itu = 1 - amt;
      for (let i = 0; i < frames; i++) {
        let ituL = 0, ituR = 0, binL = 0, binR = 0, lfeL = 0, lfeR = 0;
        for (let ch = 0; ch < channels; ch++) {
          const x = sanitizeD(inCh[ch][i]);
          const isLfe = this._layout >= LAYOUT_51 && ch === 3;
          if (isLfe) {
            if (this.lfeGainLin > 0) { lfeL += x * this.lfeGainLin; lfeR += x * this.lfeGainLin; }
            continue;
          }
          const az = azimuthFor(this._layout, ch);
          const right = az > 0;
          const center = this._layout >= LAYOUT_51 && ch === 2;
          const ituX = x * this.ituMix[ch];
          if (center) { ituL += ituX; ituR += ituX; }
          else if (right) { ituR += ituX; ituL += ituX * 0.15; }
          else { ituL += ituX; ituR += ituX * 0.15; }
          if (amt > 0) {
            const xs = this.rearMuffle[ch].tick(x, ramp);
            const ipsi = this.frontPeak[ch].tick(xs * this.binaMix[ch], ramp);
            let contra = xs * (this.binaMix[ch] * 0.85);
            const wpos = this.delayPos[ch] | 0;
            this.delayLine[ch][wpos] = contra;
            contra = Spatial.delayRead(this.delayLine[ch], wpos, this.contraDelaySmp[ch]);
            contra = this.contraShelf[ch].tick(contra, ramp);
            if (center) { binL += ipsi; binR += ipsi; }
            else if (right) { binR += ipsi; binL += contra; }
            else { binL += ipsi; binR += contra; }
            this.delayPos[ch] = (this.delayPos[ch] + 1) % SPATIAL_MAX_DELAY;
          }
        }
        out[0][i] = ituL * itu + binL * amt + lfeL;
        out[1][i] = ituR * itu + binR * amt + lfeR;
      }
    }
  }

  // ─────────────────────────── Room ───────────────────────────

  const ROOM_TAPS = 8;
  const ROOM_MAX_DELAY = 8192;
  const ROOM_TAP_MS = [4.8, 9.1, 13.7, 18.3, 23.6, 29.2, 33.8, 38.4];
  const ROOM_TAP_DB = [-16, -19, -21, -23, -25, -26.5, -28, -29.5];

  class Room {
    constructor(sr) {
      this.sr = sr;
      this.delaySmp = []; this.gain = []; this.lp = [];
      for (let t = 0; t < ROOM_TAPS; t++) {
        this.delaySmp.push(ROOM_TAP_MS[t] * 0.001 * sr);
        this.gain.push(dbToLin(ROOM_TAP_DB[t]));
        const b = new Biquad();
        b.set(BQ_LOWPASS, 3200 - t * 250, 0, 0.707, sr);
        b.snap();
        this.lp.push(b);
      }
      this.line = [new Float64Array(ROOM_MAX_DELAY), new Float64Array(ROOM_MAX_DELAY)];
      this.pos = 0;
      this.wet = 0.06; this.size = 1;
    }
    set(enable, wetPercent, sizePercent) {
      this.enable = !!enable;
      this.wet = clampD(sanitizeD(wetPercent), 0, 15) / 100;
      this.size = clampD(sanitizeD(sizePercent), 50, 150) / 100;
    }
    reset() {
      for (const b of this.lp) b.resetState();
      this.line[0].fill(0); this.line[1].fill(0);
      this.pos = 0;
    }
    process(io, frames) {
      if (!this.enable || this.wet <= 0) return;
      const ramp = 1 - onepoleCoef(this.sr, 0.02);
      const len = ROOM_MAX_DELAY;
      const wetGain = this.wet * 4;
      const dryGain = 1 - this.wet * 1.5;
      for (let i = 0; i < frames; i++) {
        const l = sanitizeD(io[0][i]);
        const r = sanitizeD(io[1][i]);
        const wpos = this.pos | 0;
        this.line[0][wpos] = l;
        this.line[1][wpos] = r;
        let wetL = 0, wetR = 0;
        for (let t = 0; t < ROOM_TAPS; t++) {
          let d = this.delaySmp[t] * this.size;
          if (d >= len) d = len - 1;
          let read = wpos - d;
          if (read < 0) read += len;
          const i0 = Math.floor(read);
          const frac = read - i0;
          let i1 = i0 - 1;
          if (i1 < 0) i1 += len;
          const srcL = this.line[0][i0] + (this.line[0][i1] - this.line[0][i0]) * frac;
          const srcR = this.line[1][i0] + (this.line[1][i1] - this.line[1][i0]) * frac;
          const tap = this.lp[t].tick((srcL + srcR) * 0.5, ramp);
          if ((t & 1) === 0) { wetL += tap * this.gain[t] * 0.75; wetR += tap * this.gain[t]; }
          else { wetL += tap * this.gain[t]; wetR += tap * this.gain[t] * 0.75; }
        }
        io[0][i] = l * dryGain + wetL * wetGain;
        io[1][i] = r * dryGain + wetR * wetGain;
        this.pos = (this.pos + 1) % len;
      }
    }
  }

  // ─────────────────────────── Limiter ───────────────────────────

  const LIMITER_MAX_DELAY = 4096;

  function tp4(x0, x1, x2) {
    const a0 = -0.1875 * x0 + 0.5625 * x1 + 0.5625 * x2 - 0.1875 * x2;
    const a1 = -0.5 * x1 + 0.5 * x2;
    const a2 = 0.1875 * x0 - 0.75 * x1 + 0.75 * x2 - 0.1875 * x2;
    const c0 = x1;
    const c1 = a0 - 0.375 * a2 - c0;
    const c2 = 0.25 * a2 - 0.5 * a1;
    let peak = Math.abs(c0);
    for (let k = 1; k <= 3; k++) {
      const t = k * 0.25;
      const v = ((c2 * t + c1) * t + a1) * t + c0;
      const av = Math.abs(v);
      if (av > peak) peak = av;
    }
    return peak;
  }

  class Limiter {
    constructor(sr) {
      this.sr = sr;
      this.delay = [new Float64Array(LIMITER_MAX_DELAY), new Float64Array(LIMITER_MAX_DELAY)];
      this.pos = 0; this.envLin = 1; this.currentGain = 1;
      this.ceilingDb = -1; this.lookaheadMs = 5; this.releaseMs = 120;
      this.delaySmp = 0;
      this.set(false, -1, 5, 120);
    }
    set(enable, ceilingDb, lookaheadMs, releaseMs) {
      this.enable = !!enable;
      this.ceilingDb = clampD(sanitizeD(ceilingDb), -6, 0);
      this.lookaheadMs = clampD(sanitizeD(lookaheadMs), 1, 10);
      this.releaseMs = clampD(sanitizeD(releaseMs), 40, 500);
      this.ceilingLin = dbToLin(this.ceilingDb);
      let d = Math.floor(this.lookaheadMs * 0.001 * this.sr);
      if (d < 1) d = 1;
      if (d > LIMITER_MAX_DELAY) d = LIMITER_MAX_DELAY;
      if (d !== this.delaySmp) { this.delaySmp = d; this.reset(); }
      this.attCoef = onepoleCoef(this.sr, this.lookaheadMs / 1000 / 3);
      this.relCoef = onepoleCoef(this.sr, this.releaseMs / 1000);
    }
    reset() {
      this.delay[0].fill(0); this.delay[1].fill(0);
      this.pos = 0; this.envLin = 1; this.currentGain = 1;
    }
    process(inCh, out, frames) {
      if (!this.enable) {
        if (out[0] !== inCh[0]) for (let i = 0; i < frames; i++) out[0][i] = inCh[0][i];
        if (out[1] !== inCh[1]) for (let i = 0; i < frames; i++) out[1][i] = inCh[1][i];
        return;
      }
      const d = this.delaySmp;
      const len = LIMITER_MAX_DELAY;
      for (let i = 0; i < frames; i++) {
        const l = sanitizeD(inCh[0][i]);
        const r = sanitizeD(inCh[1][i]);
        const p = this.pos;
        const im1 = (p + len - 1) % len;
        const im2 = (p + len - 2) % len;
        const lp0 = this.delay[0][im2], lp1 = this.delay[0][im1];
        const rp0 = this.delay[1][im2], rp1 = this.delay[1][im1];
        let peak = tp4(lp0, lp1, l);
        const peakR = tp4(rp0, rp1, r);
        if (peakR > peak) peak = peakR;
        this.delay[0][p] = l;
        this.delay[1][p] = r;
        let need = 1;
        if (peak > this.ceilingLin) need = this.ceilingLin / peak;
        if (need < this.envLin) this.envLin = need;
        else this.envLin = this.relCoef * this.envLin + (1 - this.relCoef) * need;
        const target = this.envLin;
        if (target < this.currentGain) {
          this.currentGain = this.attCoef * this.currentGain + (1 - this.attCoef) * target;
          if (this.currentGain < target) this.currentGain = target;
        } else {
          this.currentGain = this.relCoef * this.currentGain + (1 - this.relCoef) * target;
        }
        const opos = (p + len - d) % len;
        out[0][i] = this.delay[0][opos] * this.currentGain;
        out[1][i] = this.delay[1][opos] * this.currentGain;
        this.pos = (p + 1) % len;
      }
    }
  }

  // ─────────────────────────── Pipeline complet ───────────────────────────

  class CinevaPipeline {
    constructor(sampleRate) {
      if (typeof sampleRate !== 'number' || !isFinite(sampleRate) ||
          sampleRate < 8000 || sampleRate > 192000) {
        sampleRate = 48000;
      }
      this.sampleRate = sampleRate;
      this.loudness = new Loudness(sampleRate);
      this.eq = new ParametricEq(sampleRate);
      this.drc = new Drc(sampleRate);
      this.dialogue = new Dialogue(sampleRate);
      this.bass = new Bass(sampleRate);
      this.spatial = new Spatial(sampleRate);
      this.room = new Room(sampleRate);
      this.limiter = new Limiter(sampleRate);
      this.chan = [];
      for (let i = 0; i < MAX_CHANNELS; i++) this.chan.push(new Float32Array(MAX_BLOCK));
      this.stereo = [new Float32Array(MAX_BLOCK), new Float32Array(MAX_BLOCK)];
      this.weights = new Array(MAX_CHANNELS).fill(1);
      this.params = null;
      this.layout = LAYOUT_STEREO;
      this.integratedLufs = -70;
      this.truePeakDb = -999;
      this.clippedSamples = 0;
      this.engineActive = false;
      this.setParams(CinevaPipeline.neutralParams(sampleRate, 2));
    }

    static neutralParams(sampleRate, channels) {
      const p = new Float64Array(PARAM_COUNT);
      p[P.layoutVersion] = PARAM_VERSION;
      p[P.sampleRate] = sampleRate;
      p[P.masterEnable] = 1;
      p[P.inChannels] = channels;
      p[P.outChannels] = 2;
      p[P.inputLayout] = channels >= 6 ? 3 : (channels >= 4 ? 2 : (channels >= 2 ? 1 : 0));
      p[P.loudnessEnable] = 1; p[P.loudnessTargetLufs] = -16;
      p[P.loudnessMaxGainDb] = 8; p[P.loudnessMaxAttenuationDb] = 8;
      p[P.loudnessAdaptRateDbPerSec] = 1.5;
      p[P.eqEnable] = 1;
      for (let i = 0; i < 6; i++) {
        p[eqType(i)] = EQ_DEF_TYPES[i];
        p[eqFreq(i)] = EQ_DEF_FREQS[i];
        p[eqGain(i)] = 0;
        p[eqQ(i)] = 0.9;
      }
      p[P.drcEnable] = 1; p[P.drcThresholdDb] = -24; p[P.drcRatio] = 2.5;
      p[P.drcKneeDb] = 6; p[P.drcAttackMs] = 15; p[P.drcReleaseMs] = 250;
      p[P.drcMakeupDb] = 0; p[P.drcMixPercent] = 100; p[P.drcDetector] = 1;
      p[P.dialogueEnable] = 1; p[P.dialogueIntensityPercent] = 35;
      p[P.bassEnable] = 1; p[P.bassIntensityPercent] = 50; p[P.bassCrossoverHz] = 80;
      p[P.bassSpeakerMode] = 0; p[P.bassSubShelfGainDb] = 5;
      p[P.bassLfeGainDb] = 0;
      p[P.spatialEnable] = 1; p[P.spatialMode] = 1; p[P.spatialWidthPercent] = 100;
      p[P.spatialBinauralAmountPercent] = 100;
      p[P.roomEnable] = 1; p[P.roomWetPercent] = 6; p[P.roomSizePercent] = 100;
      p[P.limiterEnable] = 1; p[P.limiterCeilingDb] = -1;
      p[P.limiterLookaheadMs] = 5; p[P.limiterReleaseMs] = 120;
      return p;
    }

    setParams(values) {
      if (!values || values.length !== PARAM_COUNT) return -1;
      if (values[P.layoutVersion] !== PARAM_VERSION) return -2;
      let newSr = pNum(values, P.sampleRate, 48000, 8000, 192000);
      if (newSr !== this.sampleRate) {
        this.sampleRate = newSr;
        this.loudness = new Loudness(newSr);
        this.eq = new ParametricEq(newSr);
        this.drc = new Drc(newSr);
        this.dialogue = new Dialogue(newSr);
        this.bass = new Bass(newSr);
        this.spatial = new Spatial(newSr);
        this.room = new Room(newSr);
        this.limiter = new Limiter(newSr);
      }
      this.params = Float64Array.from(values);
      this.params[P.sampleRate] = this.sampleRate;
      this.applyParams();
      return 0;
    }

    pNum(i, def, lo, hi) { return clampD(sanitizeD(this.params[i]), lo, hi); }
    pBool(i) { const v = this.params[i]; return v !== 0 && isFinite(v); }

    applyParams() {
      const inCh = Math.trunc(this.pNum(P.inChannels, 2, 1, 8));
      this.params[P.inChannels] = inCh;
      this.params[P.outChannels] = 2;
      this.layout = layoutFromChannels(inCh);
      this.params[P.inputLayout] = this.layout;

      this.loudness.set(
        this.pBool(P.loudnessEnable),
        this.pNum(P.loudnessTargetLufs, -16, -36, -8),
        this.pNum(P.loudnessMaxGainDb, 8, 0, 12),
        this.pNum(P.loudnessMaxAttenuationDb, 8, 0, 12),
        this.pNum(P.loudnessAdaptRateDbPerSec, 1.5, 0.1, 6));

      const types = [], freqs = [], gains = [], qs = [];
      for (let i = 0; i < 6; i++) {
        types.push(this.pNum(eqType(i), 1, 0, 4) | 0);
        freqs.push(this.pNum(eqFreq(i), 1000, 20, 20000));
        gains.push(this.pNum(eqGain(i), 0, -15, 15));
        qs.push(this.pNum(eqQ(i), 0.9, 0.3, 4));
      }
      this.eq.set(this.pBool(P.eqEnable), types, freqs, gains, qs);

      this.drc.set(this.pBool(P.drcEnable),
        this.pNum(P.drcThresholdDb, -24, -60, 0),
        this.pNum(P.drcRatio, 2.5, 1, 20),
        this.pNum(P.drcKneeDb, 6, 0, 24),
        this.pNum(P.drcAttackMs, 15, 0.5, 200),
        this.pNum(P.drcReleaseMs, 250, 20, 1000),
        this.pNum(P.drcMakeupDb, 0, -6, 12),
        this.pNum(P.drcMixPercent, 100, 0, 100),
        this.pNum(P.drcDetector, 1, 0, 1) | 0);

      this.dialogue.set(this.pBool(P.dialogueEnable),
        this.pNum(P.dialogueIntensityPercent, 35, 0, 100));

      this.bass.set(this.pBool(P.bassEnable),
        this.pNum(P.bassIntensityPercent, 50, 0, 100),
        this.pNum(P.bassCrossoverHz, 80, 50, 160),
        this.pNum(P.bassSpeakerMode, 0, 0, 2) | 0,
        this.pNum(P.bassSubShelfGainDb, 5, -6, 9),
        this.pNum(P.bassHarmonicDrivePercent, 0, 0, 100),
        this.pNum(P.bassLfeGainDb, 0, -12, 6));

      this.spatial.set(this.pBool(P.spatialEnable),
        this.pNum(P.spatialMode, 1, 0, 3) | 0,
        this.pNum(P.spatialWidthPercent, 100, 0, 150),
        this.pNum(P.spatialCrossfeedPercent, 0, 0, 100),
        this.pNum(P.spatialBinauralAmountPercent, 100, 0, 100));

      this.room.set(this.pBool(P.roomEnable),
        this.pNum(P.roomWetPercent, 6, 0, 15),
        this.pNum(P.roomSizePercent, 100, 50, 150));

      this.limiter.set(this.pBool(P.limiterEnable),
        this.pNum(P.limiterCeilingDb, -1, -6, 0),
        this.pNum(P.limiterLookaheadMs, 5, 1, 10),
        this.pNum(P.limiterReleaseMs, 120, 40, 500));

      this.weights = mapperWeights(this.layout, inCh);
    }

    reset() {
      this.loudness.reset(); this.eq.reset(); this.drc.reset(); this.dialogue.reset();
      this.bass.reset(); this.spatial.reset(); this.room.reset(); this.limiter.reset();
      this.integratedLufs = -70; this.truePeakDb = -999; this.clippedSamples = 0;
    }

    process(inCh, channels, out, frames) {
      if (channels < 1 || channels > MAX_CHANNELS) return -1;
      if (frames <= 0) return 0;
      let offset = 0;
      while (offset < frames) {
        let n = frames - offset;
        if (n > MAX_BLOCK) n = MAX_BLOCK;
        const chunkIn = inCh.map((c) => c.subarray(offset, offset + n));
        const chunkOut = [out[0].subarray(offset, offset + n), out[1].subarray(offset, offset + n)];
        this.processChunk(chunkIn, channels, chunkOut, n);
        offset += n;
      }
      return 0;
    }

    processChunk(inCh, channels, out, frames) {
      const master = this.pBool(P.masterEnable);
      const layout = this.layout;

      for (let ch = 0; ch < channels; ch++) {
        const src = inCh[ch], dst = this.chan[ch];
        for (let i = 0; i < frames; i++) dst[i] = sanitizeD(src[i]);
      }

      if (!master) {
        for (let i = 0; i < frames; i++) {
          const l = channels > 0 ? inCh[0][i] : 0;
          const r = channels > 1 ? inCh[1][i] : l;
          const cl = Math.max(-1, Math.min(1, sanitizeD(l)));
          const cr = Math.max(-1, Math.min(1, sanitizeD(r)));
          if (cl !== l || cr !== r) this.clippedSamples += 1;
          out[0][i] = cl; out[1][i] = cr;
        }
        this.engineActive = false;
        return;
      }
      this.engineActive = true;

      this.loudness.process(this.chan, this.chan, channels, frames, this.weights);
      this.integratedLufs = this.loudness.integratedLufs;

      this.dialogue.process(this.chan, channels, layout, frames);

      const headroom = dbToLin(this.pNum(P.masterHeadroomDb, 0, -12, 12));
      const bassHandlesLfe = this.bass.enable && this.pBool(P.lfeIntoBass) &&
        layout >= LAYOUT_51 && channels >= 6;
      let lfeDownmixGain = 0;
      if (layout >= LAYOUT_51 && channels >= 6 && !bassHandlesLfe) {
        lfeDownmixGain = this.pBool(P.lfeIntoBass)
          ? dbToLin(this.pNum(P.bassLfeGainDb, 0, -12, 6)) : 0;
      }

      if (this.spatial.enable) {
        this.spatial.process(this.chan, channels, layout, this.stereo, lfeDownmixGain, frames);
      } else {
        downmixItu(this.chan, channels, layout, this.stereo, lfeDownmixGain, frames);
      }

      const lfePtr = bassHandlesLfe ? this.chan[3] : null;
      this.bass.process(this.stereo, lfePtr, frames);

      if (headroom !== 1) {
        for (let i = 0; i < frames; i++) {
          this.stereo[0][i] *= headroom;
          this.stereo[1][i] *= headroom;
        }
      }

      this.eq.process(this.stereo, 2, frames);
      this.drc.process(this.stereo, 2, frames);
      this.room.process(this.stereo, frames);
      this.limiter.process(this.stereo, out, frames);

      for (let i = 0; i < frames; i++) {
        const l = out[0][i], r = out[1][i];
        const pdb = linToDb(Math.max(Math.abs(l), Math.abs(r)));
        if (pdb > this.truePeakDb) this.truePeakDb = pdb;
        const cl = Math.max(-1, Math.min(1, sanitizeD(l)));
        const cr = Math.max(-1, Math.min(1, sanitizeD(r)));
        if (cl !== l || cr !== r) this.clippedSamples += 1;
        out[0][i] = cl; out[1][i] = cr;
      }
    }

    getMetrics() {
      const m = new Float64Array(16);
      m[0] = this.integratedLufs;
      m[1] = this.truePeakDb;
      this.truePeakDb = -999;
      m[2] = this.loudness.gainDb;
      m[3] = linToDb(this.limiter.currentGain);
      m[4] = this.clippedSamples;
      this.clippedSamples = 0;
      m[5] = this.engineActive ? 1 : 0;
      return m;
    }
  }

  // ─────────────────────────── Mode AudioWorklet ───────────────────────────

  if (typeof registerProcessor === 'function' && typeof AudioWorkletProcessor === 'function') {
    class CinevaAudioProcessor extends AudioWorkletProcessor {
      constructor() {
        super();
        this.pipeline = new CinevaPipeline(sampleRate);
        this.pendingReset = false;
        this.port.onmessage = (event) => {
          const data = event.data || {};
          if (data.type === 'params' && Array.isArray(data.params)) {
            this.pipeline.setParams(data.params);
          } else if (data.type === 'reset') {
            this.pipeline.reset();
          } else if (data.type === 'metrics') {
            this.port.postMessage({ type: 'metrics', metrics: Array.from(this.pipeline.getMetrics()) });
          }
        };
      }

      process(inputs, outputs) {
        const input = inputs[0];
        const output = outputs[0];
        if (!output || output.length < 2) return true;
        const outL = output[0];
        const outR = output.length > 1 ? output[1] : output[0];
        if (!input || input.length === 0) {
          outL.fill(0);
          if (outR !== outL) outR.fill(0);
          return true;
        }
        const channels = Math.min(input.length, MAX_CHANNELS);
        const frames = Math.min(outL.length, MAX_BLOCK);
        this.pipeline.process(input, channels, [outL, outR], frames);
        return true;
      }
    }
    registerProcessor('cineva-audio-processor', CinevaAudioProcessor);
    return;
  }

  // ─────────────────────────── Mode glue page ───────────────────────────

  if (typeof globalThis !== 'undefined') {
    const state = {
      ctx: null, node: null, src: null, video: null,
      moduleLoaded: false, attached: false, error: null,
      metrics: [0, -999, 0, 0, 0, 0], lastParams: null,
    };

    async function tryAddModule(ctx, urls) {
      let lastError = null;
      for (const url of urls) {
        try {
          await ctx.audioWorklet.addModule(url);
          return true;
        } catch (e) {
          lastError = e;
        }
      }
      if (lastError) throw lastError;
      return false;
    }

    const WORKLET_URLS = [
      // Asset déclaré dans le pubspec du package cineva_audio_engine :
      // bundlé par Flutter web sous assets/packages/<pkg>/<chemin>.
      'assets/packages/cineva_audio_engine/assets/js/cineva_audio_worklet.js',
      'packages/cineva_audio_engine/assets/js/cineva_audio_worklet.js',
      // Variantes (asset déclaré directement dans l'app, ou servi à la racine).
      'assets/assets/js/cineva_audio_worklet.js',
      'assets/js/cineva_audio_worklet.js',
      'cineva_audio_worklet.js',
    ];

    const api = {
      async attach() {
        try {
          if (state.attached) return true;
          const video = document.querySelector('video');
          if (!video) throw new Error('aucun élément video actif');
          const AudioCtx = window.AudioContext || window.webkitAudioContext;
          if (!AudioCtx) throw new Error('Web Audio indisponible');
          if (!state.ctx) {
            state.ctx = new AudioCtx();
            state.moduleLoaded = false;
          }
          if (state.ctx.state === 'suspended') await state.ctx.resume();
          if (!state.moduleLoaded) {
            await tryAddModule(state.ctx, WORKLET_URLS);
            state.moduleLoaded = true;
          }
          // createMediaElementSource est définitif (un seul par élément) :
          // on le crée une fois puis on le réutilise à chaque attach.
          if (!state.src || state.video !== video) {
            state.src = state.ctx.createMediaElementSource(video);
            state.video = video;
          }
          if (!state.node) {
            state.node = new AudioWorkletNode(state.ctx, 'cineva-audio-processor', {
              numberOfInputs: 1,
              numberOfOutputs: 1,
              outputChannelCount: [2],
            });
            state.node.port.onmessage = (event) => {
              const data = event.data || {};
              if (data.type === 'metrics' && Array.isArray(data.metrics)) {
                state.metrics = data.metrics;
              }
            };
          }
          state.src.disconnect();
          state.src.connect(state.node);
          state.node.connect(state.ctx.destination);
          if (state.lastParams) {
            state.node.port.postMessage({ type: 'params', params: state.lastParams });
          }
          state.attached = true;
          state.error = null;
          return true;
        } catch (e) {
          state.error = String((e && e.message) || e);
          api.detach();
          return false;
        }
      },
      detach() {
        // Ne JAMAIS fermer l'AudioContext : le MediaElementSource détourne
        // définitivement l'audio de l'élément vers le graphe — on rebranche
        // donc la source en direct vers la sortie (son d'origine).
        try {
          if (state.src && state.ctx) {
            state.src.disconnect();
            state.src.connect(state.ctx.destination);
          }
          if (state.node) state.node.disconnect();
        } catch (e) {
          // déjà détaché
        }
        state.attached = false;
      },
      setParams(params) {
        const list = Array.from(params);
        state.lastParams = list;
        if (state.node && state.node.port && state.attached) {
          state.node.port.postMessage({ type: 'params', params: list });
        }
      },
      reset() {
        if (state.node && state.node.port) state.node.port.postMessage({ type: 'reset' });
      },
      requestMetrics() {
        if (state.node && state.node.port) state.node.port.postMessage({ type: 'metrics' });
      },
      getMetrics() { return state.metrics.slice(); },
      isAttached() { return state.attached; },
      getStatus() {
        return { attached: state.attached, error: state.error, sampleRate: state.ctx ? state.ctx.sampleRate : 0 };
      },
    };

    globalThis.__cinevaAudioEngine = api;
    if (typeof module !== 'undefined' && module.exports) {
      // Node (tests) : exporte le pipeline pour la vérification des goldens.
      module.exports = { CinevaPipeline, PARAM_COUNT, PARAM_VERSION };
    }
  }
})();
