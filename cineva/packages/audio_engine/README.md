# Cineva Audio Engine

Chaîne de traitement audio temps réel propriétaire de Cineva : loudness
BS.1770, EQ paramétrique 6 bandes, compresseur soft-knee, enhancement
dialogue, bass management Linkwitz-Riley, spatialisation binaurale,
réflexions précoces et limiteur true-peak — le tout par blocs, sans
allocation dans le chemin de traitement natif.

## Architecture

```
Video Player (PCM)
   ↓ planar Float32
AudioEngine (orchestrateur Dart)
   ↓ tableau de paramètres versionné (128 doubles)
┌─────────────────────────────────────────────┐
│ Cœur natif C99 (FFI)  —  production         │
│   ou cœur Dart (équivalent, tests/fallback) │
│                                             │
│ ChannelMapper → Loudness → Dialogue → Bass  │
│   → Spatial → EQ → DRC → Room → Limiter     │
└─────────────────────────────────────────────┘
   ↓
Sortie audio plateforme (backend : web AudioWorklet, …)
```

- **`lib/`** — configuration centralisée (`AudioEngineConfig`), profils
  (Cinéma / Immersif / TV / Night / Original), orchestrateur `AudioEngine`,
  cœur Dart `DartDspPipeline`, bindings FFI.
- **`native/cineva_dsp/`** — cœur C99 (`libcineva_dsp`), suite de tests C,
  benchmark, générateur de golden files. `make test`, `make bench`.
- **`test/goldens/`** — sorties de référence produites par le cœur C et
  vérifiées par les tests Dart **et** JS (contrat d'équivalence des trois
  implémentations).
- **`assets/js/`** — AudioWorklet (backend Web).

## Utilisation

```dart
final engine = AudioEngine(config: AudioEngineConfig.forProfile(CinevaAudioProfile.cinema));
engine.process(inputPlanar, channels, outputStereo, frames);
final metrics = engine.readMetrics(); // LUFS, true peak, gain, clipping
engine.setBypass(true); // A/B instantané
```

## Tests

```bash
# Cœur C : tests + benchmark + génération des goldens
cd native/cineva_dsp && make test && make bench

# Dart (golden cross-check Dart ↔ C inclus)
CINEVA_DSP_LIB=$PWD/native/cineva_dsp/build/libcineva_dsp.so dart test

# Worklet web (golden cross-check JS ↔ C, sans dépendance)
node test/web/worklet_golden_test.js
```

## Backend web (AudioWorklet)

`assets/js/cineva_audio_worklet.js` est un fichier **dual-mode** :

- chargé via `audioWorklet.addModule(...)` → s'enregistre comme processeur
  `'cineva-audio-processor'` (pipeline DSP complet, miroir du cœur C) ;
- chargé via `<script>` en contexte page → expose la glue
  `globalThis.__cinevaAudioEngine` (attach du `<video>` actif dans le graphe
  Web Audio, setParams/reset/metrics).

`WebAudioBackend` (dart:js_interop seul, aucune dépendance externe) injecte
le script puis délègue à la glue. L'asset est déclaré dans le pubspec du
package : Flutter web le sert sous
`assets/packages/cineva_audio_engine/assets/js/cineva_audio_worklet.js`
(URLs candidates gérées automatiquement).

## Équivalence C / Dart / JS

Le même tableau de paramètres + le même PCM d'entrée produisent la même
sortie (± arrondis) dans les trois implémentations — vérifié par tests
croisés sur cinq cas de référence (cinéma, night, binaural 5.1, bypass,
original).
