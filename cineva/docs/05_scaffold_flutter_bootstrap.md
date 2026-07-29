# 05 — Scaffold Flutter réel et bootstrap natif

## Ce qui a été généré dans le dépôt

Le monorepo contient maintenant un **scaffold Flutter réel côté code Dart** :

- `pubspec.yaml` pour chaque application ;
- packages partagés ;
- thème premium Cineva ;
- composants UI réutilisables ;
- shell mobile ;
- shell admin ;
- shell desktop ;
- shell Android TV ;
- shell web.

## Limitation de l'environnement Arena

Dans cet environnement, le **SDK Flutter n'est pas installé**.

Conséquence :
- j'ai pu générer toute la structure Dart du monorepo ;
- mais je n'ai pas pu exécuter `flutter create` pour produire automatiquement les dossiers natifs :
  - `android/`
  - `ios/`
  - `macos/`
  - `windows/`
  - `web/`

## Solution fournie

Le script suivant a été ajouté :

```bash
scripts/bootstrap_flutter_targets.sh
```

Ce script :

1. crée temporairement de vrais projets Flutter ;
2. génère les cibles natives adaptées à chaque app ;
3. copie ces cibles dans le monorepo ;
4. préserve votre code Dart actuel.

## Commandes à exécuter localement

Depuis la racine du dossier `cineva/` :

```bash
chmod +x scripts/bootstrap_flutter_targets.sh
./scripts/bootstrap_flutter_targets.sh
```

Puis :

```bash
dart pub global activate melos
melos bootstrap
melos run pub:get
melos run analyze
```

## Cibles prévues par app

### `cineva_mobile`
- Android
- iOS

### `cineva_admin`
- Windows
- macOS
- Web

### `cineva_windows`
- Windows

### `cineva_macos`
- macOS

### `cineva_android_tv`
- Android

### `cineva_web`
- Web

## État du scaffold

### Déjà en place
- design tokens ;
- widgets premium ;
- bottom navigation mobile ;
- dashboard admin ;
- shell desktop ;
- shell TV ;
- organisation monorepo.

### Étape suivante recommandée
- brancher `supabase_flutter` ;
- ajouter la configuration d'environnement ;
- implémenter auth ;
- implémenter abonnement ;
- implémenter appareil unique ;
- afficher l'écran abonnement expiré.
