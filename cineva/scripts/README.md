# Scripts de build Cineva

Ces scripts documentent les commandes cibles pour compiler les différentes variantes du projet.

> Important : les apps Flutter réelles doivent exister dans `apps/` avec leurs `pubspec.yaml` avant d'exécuter les builds.

## Scripts inclus

- `bootstrap_flutter_targets.sh`
- `build_android.sh`
- `build_ios.sh`
- `build_windows.sh`
- `build_macos.sh`
- `build_android_tv.sh`

## Bootstrap initial recommandé

Avant le premier build sur une machine équipée de Flutter :

```bash
./scripts/bootstrap_flutter_targets.sh
```

Ce script génère les dossiers natifs Flutter manquants pour chaque app du monorepo sans écraser le code Dart déjà présent.

## Convention

- `cineva_mobile` pour Android/iOS mobile
- `cineva_windows` pour Windows
- `cineva_macos` pour macOS
- `cineva_android_tv` pour Android TV

## Pré-requis

- Flutter SDK installé
- Android SDK pour Android / TV
- Xcode pour iOS / macOS
- Visual Studio Build Tools pour Windows
- dépendances résolues via `flutter pub get`

## Recommandation monorepo

Après création réelle des apps, lancer idéalement :

```bash
melos bootstrap
melos run pub:get
melos run analyze
```

## Remarque

Ces scripts sont volontairement explicites afin de servir de base de documentation et de standardisation CI/CD.
