# cineva_desktop_video

Lecture vidéo desktop de Cineva — implémentation [media_kit](https://media-kit.org/) (libmpv)
du contrat `CinevaVideoController` défini par `cineva_widgets`.

## Pourquoi ce paquet existe

`video_player` ne fournit **aucune implémentation Windows ni Linux** : l'exécutable
Cineva démarrait, affichait l'interface, mais ne pouvait lire aucune vidéo. Plutôt
que de dupliquer le lecteur, le moteur est injecté au démarrage :

| Cible                        | Moteur        | Paquet              |
| ---------------------------- | ------------- | ------------------- |
| Android (`cineva_mobile`, `cineva_admin`) | `video_player` (ExoPlayer) | `cineva_widgets` |
| iOS                          | `video_player` (AVPlayer) | `cineva_widgets` |
| Windows / Linux / macOS      | `media_kit` (libmpv) | **ce paquet** |

Les APK n'embarquent donc aucune bibliothèque native supplémentaire.

## Utilisation

Une ligne dans `main()`, avant `runApp` :

```dart
import 'package:cineva_desktop_video/cineva_desktop_video.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  installDesktopVideoPlayback();
  runApp(const CinevaApp());
}
```

`installDesktopVideoPlayback()` :

1. charge les bibliothèques natives (`MediaKit.ensureInitialized()`) ;
2. remplace la fabrique de `CinevaVideoControllers` par `desktopVideoControllerFactory`.

L'appel est **sans effet sur une cible non desktop** — libmpv n'y est jamais chargé.

## Ce qui est préservé

Le lecteur (`PlayerScreen`) n'a pas été réécrit : il consomme le même état
normalisé, quelle que soit la cible.

- contrôles Cineva (barre dorée, gestes, feuilles qualité / audio / sous-titres) : la
  surface media_kit est créée avec `controls: NoVideoControls` ;
- reprise de lecture : `initialize()` attend que la durée soit connue (8 s max) pour
  que le calcul de position et des segments à sauter reste exact ;
- tampon : media_kit expose une position de tampon plutôt que des plages — la plage
  affichée est `[position, position + tampon]`, dérivée de valeurs réellement
  rapportées, jamais simulée ;
- cycle de vie : `wakelock`, `pauseUponEnteringBackgroundMode` et
  `resumeUponEnteringForegroundMode` sont désactivés, `PlayerScreen` gérant déjà la
  mise en pause et la reprise ;
- volume : Cineva normalise en `0.0 → 1.0`, libmpv attend `0 → 100` — conversion
  bornée et testée (`mediaKitVolumeFromNormalized` / `normalizedVolumeFromMediaKit`).

## Tests

`test/desktop_video_playback_test.dart` est volontairement exempt de code natif :
il valide les conversions de volume, l'injection de la fabrique et l'inertie d'un
contrôleur jamais initialisé (`Player` et `VideoController` sont créés au plus tard,
dans `initialize()`).
