/*
 * Test du MODE WORKLET de cineva_audio_worklet.js.
 *
 * On simule un AudioWorkletGlobalScope minimal (registerProcessor,
 * AudioWorkletProcessor, sampleRate) et on charge le fichier dedans :
 * le processeur 'cineva-audio-processor' doit s'enregistrer, traiter
 * l'audio, répondre aux messages params/reset/metrics, et la glue page
 * ne doit PAS être installée dans ce contexte.
 *
 * Usage : node test/web/worklet_processor_test.js
 */
'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const WORKLET_FILE = path.join(__dirname, '..', '..', 'assets', 'js', 'cineva_audio_worklet.js');
const code = fs.readFileSync(WORKLET_FILE, 'utf8');

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

// ── AudioWorkletGlobalScope simulé ─────────────────────────────────────

function makeWorkletScope(sampleRate) {
  let registered = null;
  const posted = [];
  const scope = {
    sampleRate,
    registerProcessor: (name, ctor) => {
      if (registered) throw new Error('double enregistrement');
      registered = { name, ctor };
    },
    AudioWorkletProcessor: class {
      constructor() {
        // port bidirectionnel minimal (postMessage → collecté).
        this.port = {
          onmessage: null,
          postMessage: (msg) => posted.push(msg),
        };
      }
    },
    isFinite,
    Math,
    Float32Array,
    Float64Array,
    console,
  };
  scope.globalThis = scope;
  vm.createContext(scope);
  vm.runInContext(code, scope, { filename: WORKLET_FILE });
  return { scope, getRegistered: () => registered, posted };
}

function neutralParamsArray() {
  // Valeurs neutres (profil par défaut du worklet) : on relit celles que le
  // pipeline s'applique à sa construction via un second scope tampon.
  const probe = makeWorkletScope(48000);
  const reg = probe.getRegistered();
  assert.ok(reg, 'le processeur doit être enregistré');
  const proc = new reg.ctor();
  // Le pipeline interne a été construit avec ses paramètres neutres ; on
  // récupère ce tableau via les métriques d'abord pour prouver le canal.
  return proc;
}

function sineInput(frames, channels) {
  const input = [];
  for (let c = 0; c < channels; c++) input.push(new Float32Array(frames));
  for (let i = 0; i < frames; i++) {
    for (let c = 0; c < channels; c++) {
      input[c][i] = 0.5 * Math.sin((2 * Math.PI * (220 + 40 * c) * i) / 48000);
    }
  }
  return input;
}

function main() {
  console.log('Worklet JS — mode AudioWorklet (scope simulé)');
  console.log('=============================================');

  const SAMPLE_RATE = 48000;

  test('le processeur s\'enregistre sous le bon nom', () => {
    const w = makeWorkletScope(SAMPLE_RATE);
    const reg = w.getRegistered();
    assert.ok(reg, 'registerProcessor doit être appelé');
    assert.strictEqual(reg.name, 'cineva-audio-processor');
  });

  test('la glue page n\'est PAS installée dans le scope worklet', () => {
    const w = makeWorkletScope(SAMPLE_RATE);
    assert.strictEqual(w.scope.__cinevaAudioEngine, undefined,
      'globalThis.__cinevaAudioEngine ne doit pas exister côté worklet');
  });

  test('process() traite des frames stéréo et reste fini', () => {
    const w = makeWorkletScope(SAMPLE_RATE);
    const proc = new (w.getRegistered().ctor)();
    // Le limiteur a un lookahead de 5 ms (240 samples) : la sortie lue dans
    // la ligne de délai est muette tant qu'on n'a pas dépassé ce délai —
    // on traite donc 1024 frames et on vérifie la fin du bloc.
    const input = [sineInput(1024, 2)];
    const outputs = [[new Float32Array(1024), new Float32Array(1024)]];
    const ok = proc.process(input, outputs);
    assert.strictEqual(ok, true, 'process doit retourner true (rester vivant)');
    let nonZero = 0;
    for (let i = 0; i < 1024; i++) {
      assert.ok(Number.isFinite(outputs[0][0][i]) && Number.isFinite(outputs[0][1][i]));
      if (i >= 512 && Math.abs(outputs[0][0][i]) > 1e-6) nonZero++;
    }
    assert.ok(nonZero > 256, 'la sortie doit être audible après le lookahead du limiteur');
  });

  test('message params masterEnable=0 → bypass bit-exact', () => {
    const w = makeWorkletScope(SAMPLE_RATE);
    const proc = new (w.getRegistered().ctor)();
    // Récupère les params neutres internes via une triche autorisée :
    // on envoie une version modifiée du tableau que le pipeline expose.
    // Le pipeline est neutre par défaut ; masterEnable est en indice 2.
    const probeParams = proc.pipeline.params;
    const off = Float64Array.from(probeParams);
    off[2] = 0;
    proc.port.onmessage({ data: { type: 'params', params: Array.from(off) } });

    const input = [sineInput(128, 2)];
    const outputs = [[new Float32Array(128), new Float32Array(128)]];
    proc.process(input, outputs);
    for (let i = 0; i < 128; i++) {
      assert.strictEqual(outputs[0][0][i], input[0][0][i]);
      assert.strictEqual(outputs[0][1][i], input[0][1][i]);
    }
  });

  test('message params avec version incorrecte → rejeté proprement', () => {
    const w = makeWorkletScope(SAMPLE_RATE);
    const proc = new (w.getRegistered().ctor)();
    const bad = Array.from(proc.pipeline.params);
    bad[0] = 99;
    proc.port.onmessage({ data: { type: 'params', params: bad } });
    // La config interne ne doit pas avoir changé : masterEnable toujours 1.
    assert.strictEqual(proc.pipeline.params[2], 1);
  });

  test('message metrics → postMessage avec 16 valeurs', () => {
    const w = makeWorkletScope(SAMPLE_RATE);
    const proc = new (w.getRegistered().ctor)();
    // engineActive reflète le dernier process() : traiter d'abord.
    proc.process([sineInput(128, 2)], [[new Float32Array(128), new Float32Array(128)]]);
    proc.port.onmessage({ data: { type: 'metrics' } });
    assert.strictEqual(w.posted.length, 1);
    assert.strictEqual(w.posted[0].type, 'metrics');
    assert.strictEqual(w.posted[0].metrics.length, 16);
    assert.strictEqual(w.posted[0].metrics[5], 1, 'engineActive après un process');
  });

  test('message reset → pas de crash, sortie reste finie', () => {
    const w = makeWorkletScope(SAMPLE_RATE);
    const proc = new (w.getRegistered().ctor)();
    proc.process([sineInput(128, 2)], [[new Float32Array(128), new Float32Array(128)]]);
    proc.port.onmessage({ data: { type: 'reset' } });
    const outputs = [[new Float32Array(128), new Float32Array(128)]];
    proc.process([sineInput(128, 2)], outputs);
    for (let i = 0; i < 128; i++) {
      assert.ok(Number.isFinite(outputs[0][0][i]));
    }
  });

  test('input vide (pas de source) → sortie silence, process true', () => {
    const w = makeWorkletScope(SAMPLE_RATE);
    const proc = new (w.getRegistered().ctor)();
    const outputs = [[new Float32Array(128), new Float32Array(128)]];
    const ok = proc.process([[]], outputs);
    assert.strictEqual(ok, true);
    for (let i = 0; i < 128; i++) {
      assert.strictEqual(outputs[0][0][i], 0);
      assert.strictEqual(outputs[0][1][i], 0);
    }
  });

  test('rendu 5.1 (6 canaux) → downmix stéréo fini', () => {
    const w = makeWorkletScope(SAMPLE_RATE);
    const proc = new (w.getRegistered().ctor)();
    const params = Float64Array.from(proc.pipeline.params);
    params[3] = 6; // inChannels
    proc.port.onmessage({ data: { type: 'params', params: Array.from(params) } });
    const input = [sineInput(128, 6)];
    const outputs = [[new Float32Array(128), new Float32Array(128)]];
    proc.process(input, outputs);
    for (let i = 0; i < 128; i++) {
      assert.ok(Number.isFinite(outputs[0][0][i]) && Math.abs(outputs[0][0][i]) <= 1.0001);
      assert.ok(Number.isFinite(outputs[0][1][i]) && Math.abs(outputs[0][1][i]) <= 1.0001);
    }
  });

  console.log('=============================================');
  console.log(`${passed} ok, ${failures} échec(s)`);
  if (failures > 0) process.exit(1);
}

main();
