# Cineva Audio Engine — Architecture technique

> Moteur de traitement audio temps réel propriétaire de Cineva.
> Ce document décrit l'architecture retenue, le pipeline DSP, les profils,
> l'intégration player/UI et les contraintes par plateforme.

---

## 1. Vision

Le Cineva Audio Engine est une **vraie chaîne de traitement audio par blocs**,
indépendante de l'UI Flutter :

```
Source vidéo (player existant)
        │  (audio décodé)
        ▼
  PCM flottant (planar, par blocs)
        ▼
┌───────────────────────────────────────────────────┐
│                CINEVA AUDIO ENGINE                │
│                                                   │
│  ChannelMapper ─► Loudness ─► ParamEQ ─► DRC      │
│       ─► Dialogue ─► Bass ─► Spatial ─► Room      │
│       ─► Limiter                                  │
└───────────────────────────────────────────────────┘
        ▼
  Sortie audio plateforme
```

Le moteur ne prétend reproduire ni Dolby Atmos ni aucune technologie sous
licence : il s'agit du **systde traitement audio propre de Cineva**, conçu et
implémenté dans ce dépôt.

## 2. Implémentations du cœur DSP

Le pipeline existe en **trois implémentations strictement équivalentes**,
vérifiées par des tests croisés sur des signaux dorés (golden tests) :

| Implémentation | Rôle | Validation |
|---|---|---|
| `native/cineva_dsp` (C99) | cœur production natif (Android, Windows, macOS, Linux) via FFI | suite de tests C + benchmark (gcc) |
| `lib/src/dsp/` (Dart pur) | référence + fallback + tests | tests Dart, sorties comparées au cœur C |
| `assets/js/cineva_audio_worklet.js` | backend Web (AudioWorklet) | tests Node, sorties comparées au cœur C |

Les paramètres transitent par un **tableau de doubles versionné**
(`CinevaDspParamLayout`, 128 slots, version 1). Toute valeur est clampée et
nettoyée (pas de NaN/Inf possible) dans les trois implémentations. Le contrat
d'équivalence est : même tableau de paramètres + même PCM d'entrée ⇒ même PCM
de sortie (± tolérance float).

## 3. Pipeline (ordre exact)

1. **ChannelMapper** — normalise la disposition d'entrée (mono, stéréo, quad,
   5.1, 7.1) vers le bus moteur. Downmix ITU-R BS.775 (LFE contrôlé séparément)
   utilisé quand la spatialisation est désactivée ; sinon les canaux sont
   conservés jusqu'au SpatialProcessor.
2. **LoudnessNormalizer** — mesure ITU-R BS.1770-4 : pondération K (2 biquads),
   blocs 400 ms / recouvrement 75 %, double gate (−70 LUFS absolu, −10 LU
   relatif), loudness intégrée adaptative (mémoire ~30 s). Gain cible vers
   `targetLufs`, borné (`maxGainDb`) et lissé (pente max `adaptRateDbPerSec`)
   pour ne jamais pomper. Gèle le gain pendant le silence.
3. **ParametricEQ** — 6 bandes biquad RBJ (transposed DF2T, coefficients
   interpolés lors des changements) : sub-bass (lowshelf 45 Hz), bass (peak
   90 Hz), low-mid (peak 300 Hz), mid (peak 1.2 kHz), high-mid (peak 3.5 kHz),
   treble (highshelf 10 kHz). Gain ±15 dB, fréquence et Q ajustables à chaud.
4. **DynamicRangeProcessor** — compresseur feedforward stéréo-linké : threshold,
   ratio, soft knee (largeur 0–24 dB), attack, release, makeup, mix (compression
   parallèle pour le mode Night).
5. **DialogueEnhancer** — décomposition M/S : boost de présence (1,2–4,5 kHz)
   sur le mid (max +4 dB), atténuation légère du bas-médian qui masque les
   voix (200–350 Hz, max −2 dB), réduction subtile du side dans la bande de
   présence (meilleure séparation voix/ambiance). Sur source multicanale :
   boost de présence + renforcement du routage du canal centre, piloté par
   l'intensité. Jamais de boost brutal des médiums.
6. **BassProcessor** — crossover Linkwitz-Riley 4ᵉ ordre (60–120 Hz), shelf
   sub-bass contrôlé, extension harmonique douce pour petits haut-parleurs
   (mode « small speaker »), fusion LFE, **limiteur de bande** bas avant
   recombinaison, recombinaison phase-alignée.
7. **SpatialProcessor** — deux chemins :
   - source multicanale → stéréo/casque : downmix **binaural** (ILD par filtres
     shelf, ITD par délai fractionnaire allpass, coloration frontale/arrière,
     indice de pinna) par position de canal (L/R ±30°, C 0°, Ls/Rs ±105°,
     Lb/Rb ±140°) ;
   - source stéréo : élargisseur M/S contrôlé + crossfeed casque optionnel
     (copie controlatérale retardée 0,25 ms, filtrée, −6…−10 dB).
   Une source stéréo n'est **jamais** upmixée artificiellement.
8. **RoomProcessor** — réflexions précoces uniquement (8 taps, 4–38 ms,
   gains −14…−26 dB, ping-pong stéréo, filtrage passe-bas), mix wet 0–15 %.
   Jamais de réverbération de salle de bain.
9. **Limiter** — limiteur true-peak lookahead : détection de crête sur-échantillonnée
   ×4 (polyphase Catmull-Rom), lookahead 5 ms, release 80–200 ms, plafond
   −0,5…−1 dBTP. Nettoyage final NaN/Inf + clamp ±1 + compteur de clipping.

Tous les modules sont désactivables ; `masterEnable = 0` = bypass bit-exact
(comparaison A/B instantanée).

## 4. Profils

| Profil | Loudness cible | DRC | Dialogue | Bass | Spatial | Room | Limiter |
|---|---|---|---|---|---|---|---|
| 🎬 Cinema | −18 LUFS | léger (−28 dB, 2:1, knee 6) | 35 % | 55 % | binaural, largeur 100 % | 8 % | −0,5 dBTP |
| 🎧 Immersif | −17 LUFS | léger | 30 % | 45 % | binaural + crossfeed, 130 % | 10 % | −1 dBTP |
| 📺 TV | −16 LUFS | standard (−24 dB, 2.5:1) | 65 % | 30 % + mode petit HP | élargissement 105 % | 4 % | −1 dBTP |
| 🌙 Night | −15 LUFS | fort (−34 dB, 4:1, mix 30 %) | 55 % | 25 % | 100 % discret | 3 % | −1 dBTP |
| 🎵 Original | bypass | bypass | bypass | bypass | bypass | 0 % | bypass |

## 5. Intégration player / plateformes

- **Web (cineva_web)** — backend réel : l'élément `<video>` créé par
  `video_player` est routé dans le graphe Web Audio
  (`MediaElementAudioSourceNode → AudioWorkletNode → destination`). Le
  DSP s'exécute dans le worklet ; les paramètres sont poussés par messages
  (tableau versionné) ; le bypass A/B est immatériel (le worklet recopie le
  signal sec).
- **Android / Android TV / Windows / macOS** — le cœur C est prêt (FFI), mais
  `video_player` n'expose pas le PCM (ExoPlayer/AVPlayer rendent l'audio
  nativement ; non supporté sous Windows). L'abstraction
  `CinevaAudioBackend` + registre de capacités est en place : quand le player
  évoluera vers un accès PCM (build ExoPlayer custom avec `AudioProcessor`,
  ou player desktop), le branchement ne touchera ni la config, ni l'UI, ni le
  cœur DSP. En attendant, l'UI affiche « non disponible sur ce build ».
- **Aucune fausse implémentation** : un backend déclare ses capacités
  (`AudioBackendCapabilities`) ; si le traitement n'est pas réellement actif,
  l'UI ne prétend pas le contraire.

### Réglages utilisateur (V1 — implémenté)

- `CinevaAudioSettings` (package `models`) : profil, curseurs dialogue/bass,
  dynamique, loudness, sortie, A/B, réglages avancés (EQ 6 bandes, crossover,
  shelf sub-bass, room, plafond limiteur). Persisté dans le blob local
  `cineva.app_settings` (clé `audioSettings`) — pas de colonne Supabase en V1.
- `AudioEngineController` (`cineva_widgets`) : pont réglages →
  `AudioEngineConfig` (profil de base + overrides utilisateur, sans jamais
  réactiver un étage que le profil désactive), pousse le tableau versionné
  de 128 doubles au backend, gère attach/detach et A/B immatériel.
- Écrans `/settings/audio` et `/settings/audio/advanced` ; pill d'état +
  toggle A/B dans les commandes du player (affichées seulement si le backend
  est réellement disponible).

## 6. Performance / temps réel

- Traitement **par blocs** (taille libre, état continu), aucune allocation ni
  verrou dans `process()` (cœur C), paramètres lissés (anti-zipper).
- Le thread UI ne fait que : config, UI, messages. Le DSP tourne dans la
  couche audio (worklet / natif).
- Benchmark inclus (`native/…/benchmark` + `tool/benchmark.dart`) : mesure du
  temps CPU par bloc et du débit temps réel (×temps réel) sur 48 k/96 k,
  stéréo et 5.1.

## 7. Évolutions prévues (hors V1)

HRTF mesurée par salarié·e/personnalisée, correction de salle, calibration
casque/HP, détection intelligente des dialogues, profils automatiques,
traitement IA — l'architecture (paramètres versionnés, backends, pipeline
modulaire) est conçue pour ces ajouts sans réécriture.
