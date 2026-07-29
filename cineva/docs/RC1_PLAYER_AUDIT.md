# Cineva — Audit RC1 Module Player

## Module audité
Lecteur vidéo

## Résultat

### État du code
**❌ Corrections nécessaires**

### Validation réelle
**❌ Validation sur appareils ou flux réels encore nécessaire**

---

## 1. Audit

### Points forts
- Le parcours de lecture est déjà riche : lecture, pause, reprise, seek, qualité, reprise progression, épisode suivant, skip intro, skip générique.
- Le lecteur est intégré au reste du produit : navigation, historique, compte, bibliothèque, Cineva Vision.
- La compatibilité logique Android TV / clavier est déjà amorcée avec `Shortcuts`, `Actions`, `Focus`.
- La logique de fallback local / réseau existe déjà, ce qui est une bonne base pour l'offline.
- Les overlays du lecteur ont été extraits dans un fichier dédié, ce qui améliore la structure.

### Points faibles
- `player_screen.dart` reste encore trop volumineux et concentre trop de responsabilités.
- La logique du player reste encore fortement couplée à l'UI et à Riverpod.
- Le multi-audio et les sous-titres reposent actuellement surtout sur les données disponibles, pas sur une détection native des pistes réellement exposées par le flux.
- Le support HLS / DASH est prêt structurellement, mais pas encore prouvé en conditions réelles.
- Le Picture-in-Picture n'est pas implémenté ni validé.

### Incohérences / points sensibles
- La logique de qualité vidéo est cohérente côté code, mais l'affichage de la qualité n'est pas encore une preuve de la qualité réellement servie par le player sans validation terrain.
- La gestion du plein écran est bonne visuellement mais doit encore être vérifiée sur appareils réels, surtout Android TV et iOS.
- Le lecteur gère l'offline en priorité via fichier local si présent, mais la robustesse dépend encore des conditions réelles de stockage et de cycle de vie OS.

### Dette technique
- `packages/widgets/lib/src/player/player_screen.dart`
- `packages/widgets/lib/src/player/player_overlays.dart`
- logique de runtime player encore trop concentrée côté écran principal
- absence d'un vrai controller / state object dédié au player

### Risques
- différences de comportement selon plateforme (`video_player` Android / iOS / desktop / TV) ;
- écart entre qualité sélectionnée et qualité réellement délivrée sur flux adaptatifs ;
- erreurs de lecture liées aux URLs expirées ou aux manifests réels ;
- Android TV / télécommande à valider finement ;
- Picture-in-Picture non traité, donc pas certifiable sur ce point.

---

## 2. Refactoring réalisé

### Réalisé dans ce lot
- Extraction de la logique de formatage dans `player_formatters.dart`.
- Extraction des widgets d'overlay et contrôles dans `player_overlays.dart`.
- Ajout d'une petite couche de politique runtime dans `player_runtime_policy.dart` pour :
  - skip intro,
  - skip générique,
  - épisode suivant,
  - clamp de seek.
- Simplification de certaines conditions du player par usage de helpers purs.

### Effet
- meilleure lisibilité ;
- meilleure testabilité ;
- premier découpage du module ;
- réduction partielle de la dette technique.

### Ce qui reste à refactoriser
- création d'un vrai `PlayerController`/`PlayerState` dédié ;
- isolation de la logique qualité / offline / retry ;
- réduction de la taille de `player_screen.dart`.

---

## 3. Validation logique

### Ce qui peut être considéré comme valide dans le code
- démarrage de lecture ;
- pause / reprise ;
- seek ;
- sauvegarde progression ;
- reprise progression ;
- changement de qualité avec tentative de conservation de position ;
- fallback local vers réseau ;
- retry manuel ;
- skip intro ;
- skip générique ;
- épisode suivant automatique avec annulation possible ;
- Android TV / clavier de base ;
- intégration Cineva Vision ;
- message d'erreur explicite.

### Ce qui nécessite impérativement une validation réelle
- comportement HLS réel ;
- comportement DASH réel ;
- conformité réelle du changement de qualité ;
- sous-titres réels ;
- multi-audio réel ;
- comportement iOS ;
- comportement Windows/macOS ;
- comportement Android TV sur vraie télécommande ;
- compatibilité Cineva Vision sur lecture longue ;
- Picture-in-Picture si implémenté plus tard.

---

## 4. Tests

### Tests ajoutés / renforcés
- `packages/widgets/test/player_formatters_test.dart`
- `packages/models/test/playback_models_test.dart`
- `packages/widgets/test/player_runtime_policy_test.dart`

### Ce que ces tests couvrent
- formatage durée / taille / ETA ;
- résolution URL playback et download ;
- règles de politique runtime (intro, crédits, next episode, clamp seek).

### Ce qui manque encore côté tests
- tests widget du player ;
- tests d'intégration navigation contenu → player ;
- tests de sauvegarde / reprise ;
- tests de changement de qualité ;
- tests des cas d'erreur du player ;
- tests Android TV / clavier.

### Checklist dédiée
- `docs/RC1_PLAYER_CHECKLIST.md`

---

## 5. Évaluation UX du lecteur (sur base code actuelle)

- **Fluidité** : **8/10**
- **Ergonomie** : **8/10**
- **Réactivité** : **8/10**
- **Lisibilité des contrôles** : **8/10**
- **Qualité des animations** : **7/10**
- **Immersion** : **8/10**
- **Stabilité perçue** : **7/10**

### Commentaire
L'expérience utilisateur est déjà crédible pour une application premium Flutter. Le gap restant vers un niveau “meilleures apps de streaming” est moins sur l'UX visible que sur la validation réelle multi-plateformes et la robustesse fine du moteur de lecture.

---

## 6. Améliorations réalistes encore possibles (sans élargir le périmètre)

### Avant RC1 finale
- découper davantage `player_screen.dart` ;
- isoler un vrai état player dédié ;
- homogénéiser encore la gestion des erreurs ;
- renforcer les tests de logique player ;
- mieux gérer les transitions plein écran selon plateforme.

### Avant Version 1.0
- vraie validation multi-stream HLS/DASH ;
- meilleure prise en charge des pistes audio/sous-titres natives si les flux les exposent ;
- Picture-in-Picture si faisable sans fragilité ;
- optimisation Android TV réelle ;
- amélioration fine du comportement desktop.

---

## 7. Décision finale

### État du code
**❌ Corrections nécessaires**

#### Points bloquants côté code
1. `player_screen.dart` trop volumineux ;
2. responsabilités encore trop concentrées ;
3. manque de tests dédiés au player state ;
4. PiP non traité.

### Validation réelle
**❌ Validation sur appareils ou flux réels encore nécessaire**

#### Points bloquants côté validation
1. HLS réel à valider ;
2. DASH réel à valider ;
3. changement de qualité à valider ;
4. multi-audio / sous-titres à valider ;
5. Android TV réel à valider ;
6. iOS / Windows / macOS à valider.

---

## Conclusion
Le lecteur est l'un des modules les plus avancés de Cineva, mais il n'est pas encore certifiable RC1.

Il est proche d'un niveau commercial sur l'UX et la logique générale, mais la validation réelle et le découpage technique doivent encore progresser avant une clôture RC1 définitive.
