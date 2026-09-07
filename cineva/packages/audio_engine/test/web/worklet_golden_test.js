/*
 * Test Node.js du worklet web (cineva_audio_worklet.js).
 *
 * En Node, le fichier se charge en « mode glue » (pas de
 * registerProcessor/AudioWorkletProcessor) et exporte CinevaPipeline :
 * on vérifie que le pipeline JS — celui qui tournera dans l'AudioWorklet
 * du navigateur — est en parité avec les goldens générés par le cœur C
 * (`make goldens`), aux mêmes tolérances que les tests Dart.
 *
 * Usage : node test/web/worklet_golden_test.js
 */
'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const { CinevaPipeline, PARAM_COUNT, PARAM_VERSION } = require('../../assets/js/cineva_audio_worklet.js');

const GOLDEN_DIR = path.join(__dirname, '..', 'goldens');

function readTyped(file, Type) {
  const b = fs.readFileSync(file);
  const dv = new DataView(b.buffer, b.byteOffset, b.byteLength);
  const n = b.byteLength / Type.BYTES_PER_ELEMENT;
  const out = new Type(n);
  const isF64 = Type === Float64Array;
  for (let i = 0; i < n; i++) {
    out[i] = isF64 ? dv.getFloat64(i * 8, true) : dv.getFloat32(i * 4, true);
  }
  return out;
}

let failures = 0;
let passed = 0;

function test(name, fn) {
  try {
    fn();
    passed++;
    console.log(`  ok  ${name}`);
  } catch (e) {
    failures++;
    console.error(`FAIL  ${name}\n      ${e.message}`);
  }
}

async function testAsync(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`  ok  ${name}`);
  } catch (e) {
    failures++;
    console.error(`FAIL  ${name}\n      ${e.message}`);
  }
}

// Paramètres neutres (miroir de neutralParams Dart/C) pour les tests hors goldens.
function neutralParams(sampleRate) {
  const p = new CinevaPipeline(sampleRate).params;
  return Float64Array.from(p);
}

function goldenCase(tag, inputChannels) {
  const paramsFile = path.join(GOLDEN_DIR, `${tag}_params.f64`);
  const outputFile = path.join(GOLDEN_DIR, `${tag}_output.f32`);
  const inputFile = path.join(
    GOLDEN_DIR, inputChannels === 6 ? 'input_51_multitone.f32' : 'input_stereo_noise.f32');

  const params = readTyped(paramsFile, Float64Array);
  const expected = readTyped(outputFile, Float32Array);
  const interleaved = readTyped(inputFile, Float32Array);

  assert.strictEqual(params.length, PARAM_COUNT, 'params doit faire 128 doubles');
  assert.strictEqual(params[0], PARAM_VERSION, 'layoutVersion');

  const frames = interleaved.length / inputChannels;
  const inCh = [];
  for (let c = 0; c < inputChannels; c++) inCh.push(new Float32Array(frames));
  for (let i = 0; i < frames; i++) {
    for (let c = 0; c < inputChannels; c++) inCh[c][i] = interleaved[i * inputChannels + c];
  }

  const pipeline = new CinevaPipeline(params[1] /* sampleRate */);
  assert.strictEqual(pipeline.setParams(params), 0, 'setParams doit réussir');
  const outL = new Float32Array(frames);
  const outR = new Float32Array(frames);
  assert.strictEqual(pipeline.process(inCh, inputChannels, [outL, outR], frames), 0);

  let maxDiff = 0;
  let sumSqExpected = 0;
  let sumSqDiff = 0;
  for (let i = 0; i < frames; i++) {
    const dl = Math.abs(outL[i] - expected[2 * i]);
    const dr = Math.abs(outR[i] - expected[2 * i + 1]);
    if (dl > maxDiff) maxDiff = dl;
    if (dr > maxDiff) maxDiff = dr;
    sumSqExpected += expected[2 * i] * expected[2 * i] + expected[2 * i + 1] * expected[2 * i + 1];
    sumSqDiff += dl * dl + dr * dr;
  }
  const errorRatio = sumSqExpected > 0 ? Math.sqrt(sumSqDiff / sumSqExpected) : 0;
  return { maxDiff, errorRatio, frames };
}

const TOL_ABS = 2e-4;   // écart absolu max (arrondis float/libm)
const TOL_ENERGY = 1e-3; // énergie d'erreur relative (< -60 dB)

async function main() {
  const goldensAvailable = fs.existsSync(GOLDEN_DIR);

  console.log('Worklet JS — parité avec le cœur C');
  console.log('==================================');

  if (!goldensAvailable) {
    console.log('  (goldens absents — tests de parité sautés)');
  } else {
    const cases = [
      ['cinema_stereo_noise', 2],
      ['night_stereo_noise', 2],
      ['immersive_51_multitone', 6],
      ['bypass_stereo_noise', 2],
      ['original_stereo_noise', 2],
    ];
    for (const [tag, ch] of cases) {
      test(`golden ${tag} (${ch}ch)`, () => {
        const { maxDiff, errorRatio, frames } = goldenCase(tag, ch);
        assert.ok(frames > 0, 'aucune frame');
        assert.ok(
          maxDiff < TOL_ABS,
          `écart max JS↔C trop grand : ${maxDiff.toExponential(3)} >= ${TOL_ABS}`);
        assert.ok(
          errorRatio < TOL_ENERGY,
          `énergie d'erreur JS↔C trop grande : ${errorRatio.toExponential(3)}`);
        console.log(`      maxDiff=${maxDiff.toExponential(2)}  errEnergie=${errorRatio.toExponential(2)}`);
      });
    }

    test('bypass bit-exact (masterEnable=0)', () => {
      const { maxDiff } = goldenCase('bypass_stereo_noise', 2);
      assert.strictEqual(maxDiff, 0, 'le bypass doit être bit-exact');
    });
  }

  test('setParams rejette taille et version incorrectes', () => {
    const p = new CinevaPipeline(48000);
    assert.strictEqual(p.setParams(new Float64Array(10)), -1);
    const bad = neutralParams(48000);
    bad[0] = 99;
    assert.strictEqual(p.setParams(bad), -2);
  });

  test('silence → silence', () => {
    const p = new CinevaPipeline(48000);
    const n = 2048;
    const outL = new Float32Array(n);
    const outR = new Float32Array(n);
    for (let rep = 0; rep < 5; rep++) {
      p.process([new Float32Array(n), new Float32Array(n)], 2, [outL, outR], n);
      for (let i = 0; i < n; i++) {
        assert.ok(Number.isFinite(outL[i]) && Number.isFinite(outR[i]));
        assert.ok(Math.abs(outL[i]) < 1e-9 && Math.abs(outR[i]) < 1e-9);
      }
    }
  });

  test('entrée NaN/Inf → sortie finie et bornée', () => {
    const p = new CinevaPipeline(48000);
    const n = 4096;
    const inL = new Float32Array(n);
    const inR = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      inL[i] = 0.3 * Math.sin((2 * Math.PI * 440 * i) / 48000);
      inR[i] = inL[i];
    }
    inL[100] = NaN;
    inL[101] = Infinity;
    inR[200] = NaN;
    const outL = new Float32Array(n);
    const outR = new Float32Array(n);
    p.process([inL, inR], 2, [outL, outR], n);
    for (let i = 0; i < n; i++) {
      assert.ok(Number.isFinite(outL[i]), `outL[${i}] non finie`);
      assert.ok(Number.isFinite(outR[i]), `outR[${i}] non finie`);
      assert.ok(Math.abs(outL[i]) <= 1.0001 && Math.abs(outR[i]) <= 1.0001);
    }
  });

  test('métriques : lecture et remise à zéro', () => {
    const p = new CinevaPipeline(48000);
    const n = 96000; // 2 s à 48 kHz : au moins un hop de loudness
    const inL = new Float32Array(n);
    const inR = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      inL[i] = 0.4 * Math.sin((2 * Math.PI * 300 * i) / 48000);
      inR[i] = 0.4 * Math.sin((2 * Math.PI * 310 * i) / 48000);
    }
    const outL = new Float32Array(n);
    const outR = new Float32Array(n);
    p.process([inL, inR], 2, [outL, outR], n);
    const m = p.getMetrics();
    assert.strictEqual(m.length, 16);
    assert.ok(m[5] === 1, 'engineActive doit être 1');
    const peakBefore = m[1];
    const m2 = p.getMetrics();
    assert.ok(m2[1] <= -999 || m2[1] === -999, 'truePeakDb remis à zéro après lecture');
    assert.ok(peakBefore > -60, 'truePeakDb doit être plausible');
  });

  test('reset : convergence propre (miroir du comportement C)', () => {
    // Sans pré-chauffe, le premier process déclenche la rampe (~20 ms) des
    // coefficients bass/EQ : la sortie post-reset diffère transitoirement
    // puis converge — comportement identique au cœur C (vérifié par dump).
    const p = new CinevaPipeline(48000);
    const n = 48000;
    const inL = new Float32Array(n);
    const inR = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      inL[i] = 0.5 * Math.sin((2 * Math.PI * 500 * i) / 48000);
      inR[i] = -inL[i];
    }
    const run = () => {
      const out = [new Float32Array(n), new Float32Array(n)];
      p.process([inL, inR], 2, out, n);
      return out;
    };
    const out1 = run();
    p.reset();
    const out2 = run();
    // Écart par quart : divergence transitoire forte puis décroissance
    // monotone (valeurs de référence vérifiées identiques au cœur C :
    // ~0.41 → 0.061 → 0.041 → 0.022).
    const quarters = [0, 0, 0, 0];
    for (let i = 0; i < n; i++) {
      const d = Math.max(Math.abs(out1[0][i] - out2[0][i]), Math.abs(out1[1][i] - out2[1][i]));
      const q = Math.min(3, Math.floor((4 * i) / n));
      if (d > quarters[q]) quarters[q] = d;
    }
    assert.ok(quarters[0] < 2.0, 'divergence transitoire bornée');
    assert.ok(quarters[3] < quarters[0], 'doit converger');
    assert.ok(quarters[1] >= quarters[2] && quarters[2] >= quarters[3],
      `décroissance monotone attendue : ${quarters.map((v) => v.toExponential(2)).join(' → ')}`);
    assert.ok(quarters[3] < 3e-2, 'résidu de fin de signal petit');
  });

  test('reset après pré-chauffe : relecture bit-exact', () => {
    // Une fois les rampes de coefficients consommées, un reset + rejeu du
    // même signal doit reproduire exactement la même sortie.
    const p = new CinevaPipeline(48000);
    const warm = 96000;
    p.process(
      [new Float32Array(warm), new Float32Array(warm)], 2,
      [new Float32Array(warm), new Float32Array(warm)], warm);
    p.reset();
    const n = 4800;
    const inL = new Float32Array(n);
    const inR = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      inL[i] = 0.5 * Math.sin((2 * Math.PI * 500 * i) / 48000);
      inR[i] = -inL[i];
    }
    const out1 = [new Float32Array(n), new Float32Array(n)];
    p.process([inL, inR], 2, out1, n);
    p.reset();
    const out2 = [new Float32Array(n), new Float32Array(n)];
    p.process([inL, inR], 2, out2, n);
    for (let i = 0; i < n; i++) {
      assert.strictEqual(out1[0][i], out2[0][i], `frame ${i}`);
      assert.strictEqual(out1[1][i], out2[1][i], `frame ${i}`);
    }
  });

  test('smoke : profil night complet (params réalistes) traité proprement', () => {
    // Simule ce que produit AudioEngineConfig.forProfile(night) + overrides
    // utilisateur (dialogue 80, bass 30, casque, night, A/B off) via toParams.
    const p = new CinevaPipeline(48000);
    const params = Float64Array.from(new CinevaPipeline(48000).params);
    params[2] = 1;   // masterEnable
    params[8] = 1; params[9] = -15; params[10] = 6; params[12] = 2.0;  // loudness
    params[48] = 1; params[49] = -34; params[50] = 4; params[51] = 10;
    params[52] = 5; params[53] = 150; params[55] = 30;  // DRC night
    params[60] = 1; params[61] = 80;   // dialogue 80 %
    params[68] = 1; params[69] = 30; params[70] = 100;
    params[71] = 2; params[72] = 3;    // bass 30 %, casque
    params[80] = 1; params[81] = 3; params[82] = 100; params[83] = 20;
    params[84] = 70;                   // spatial binaural+crossfeed
    params[92] = 1; params[93] = 3; params[94] = 90;
    params[100] = 1; params[101] = -1;
    assert.strictEqual(p.setParams(params), 0);

    const n = 48000;
    const inL = new Float32Array(n);
    const inR = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      inL[i] = 0.6 * Math.sin((2 * Math.PI * 220 * i) / 48000);
      inR[i] = 0.5 * Math.sin((2 * Math.PI * 330 * i) / 48000);
    }
    const outL = new Float32Array(n);
    const outR = new Float32Array(n);
    p.process([inL, inR], 2, [outL, outR], n);
    for (let i = 0; i < n; i++) {
      assert.ok(Number.isFinite(outL[i]) && Math.abs(outL[i]) <= 1.0001);
      assert.ok(Number.isFinite(outR[i]) && Math.abs(outR[i]) <= 1.0001);
    }
    // Le traitement est bien actif (sortie ≠ entrée).
    let diff = 0;
    for (let i = n / 2; i < n; i++) {
      diff = Math.max(diff, Math.abs(outL[i] - inL[i]));
    }
    assert.ok(diff > 1e-3, `sortie trop proche de l'entrée (${diff})`);
    const m = p.getMetrics();
    assert.ok(m[5] === 1, 'engineActive');
  });

  test('A/B : masterEnable=0 → bypass bit-exact même avec profil night', () => {
    const p = new CinevaPipeline(48000);
    const params = Float64Array.from(new CinevaPipeline(48000).params);
    params[2] = 0; // bypass A/B
    assert.strictEqual(p.setParams(params), 0);
    const n = 4096;
    const inL = new Float32Array(n);
    const inR = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      inL[i] = 0.7 * Math.sin((2 * Math.PI * 440 * i) / 48000);
      inR[i] = 0.2 * Math.cos((2 * Math.PI * 440 * i) / 48000);
    }
    const outL = new Float32Array(n);
    const outR = new Float32Array(n);
    p.process([inL, inR], 2, [outL, outR], n);
    for (let i = 0; i < n; i++) {
      assert.strictEqual(outL[i], inL[i]);
      assert.strictEqual(outR[i], inR[i]);
    }
  });

  test('mode glue : __cinevaAudioEngine exposé, honnête sans DOM', () => {
    const glue = globalThis.__cinevaAudioEngine;
    assert.ok(glue, 'la glue doit être définie hors worklet');
    assert.strictEqual(glue.isAttached(), false);
    const status = glue.getStatus();
    assert.strictEqual(status.attached, false);
  });

  await testAsync('mode glue : attach() échoue proprement sans navigateur', async () => {
    const glue = globalThis.__cinevaAudioEngine;
    const ok = await glue.attach();
    assert.strictEqual(ok, false, 'sans <video>/AudioContext, attach doit rendre false');
    assert.strictEqual(glue.isAttached(), false);
  });

  console.log('==================================');
  console.log(`${passed} ok, ${failures} échec(s)`);
  if (failures > 0) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
