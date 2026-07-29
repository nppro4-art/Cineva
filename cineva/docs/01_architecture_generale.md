# 01 — Architecture générale Cineva

## 1. Objectif

Concevoir une plateforme de streaming premium avec deux produits indépendants :

- **App Utilisateur**
- **App Admin**

Le tout dans un **monorepo** afin de centraliser :

- la logique métier partagée ;
- le design system ;
- les services ;
- les modèles ;
- les conventions de build et de qualité.

## 2. Principes structurants

### 2.1 Produit commercial, pas prototype
Le projet doit être pensé comme un vrai produit de long terme :

- architecture modulaire ;
- découpage explicite ;
- sécurité forte ;
- maintenance facilitée ;
- absence de logique sensible purement cliente.

### 2.2 Adaptation réelle par appareil
Chaque support doit avoir une UX dédiée.

#### Téléphone
- bottom navigation ;
- gestes ;
- grandes cartes ;
- focus sur fluidité verticale.

#### Tablette
- 2 à 3 colonnes ;
- plus de contenu visible ;
- side panels éventuels.

#### PC Windows / macOS
- sidebar permanente ;
- hover ;
- densité plus élevée ;
- raccourcis clavier ;
- multitâche plus confortable.

#### Android TV
- focus states explicites ;
- navigation D-pad ;
- grandes affiches ;
- actions simplifiées.

## 3. Monorepo cible

```text
apps/
  cineva_mobile/      -> app utilisateur mobile/tablette
  cineva_admin/       -> app admin indépendante
  cineva_windows/     -> shell PC Windows si app distincte
  cineva_macos/       -> shell PC macOS si app distincte
  cineva_android_tv/  -> shell TV dédié
  cineva_web/         -> optionnel, surtout admin ou landing

packages/
  ui/                 -> composants premium de base
  theme/              -> palette, tokens, typographies, elevations
  animations/         -> transitions, micro-interactions, helpers
  widgets/            -> composants métier réutilisables
  models/             -> entités et DTOs
  repositories/       -> contrats et implémentations data
  services/           -> API, auth, player, notifications, storage
  shared/             -> utilitaires transverses
```

## 4. Organisation logique Flutter

Architecture recommandée : **feature-first + couches claires**.

Pour une feature type :

```text
features/home/
  data/
    datasources/
    dto/
    repositories/
  domain/
    entities/
    usecases/
  presentation/
    controllers/
    views/
    widgets/
```

## 5. Séparation des responsabilités

### Côté client Flutter
Responsable de :
- rendu UI ;
- animation ;
- navigation ;
- état local ;
- expérience offline limitée ;
- lecture de données autorisées.

### Côté serveur / Supabase
Responsable de :
- auth ;
- autorisations ;
- validation abonnement ;
- gestion appareil unique ;
- génération d'URL signées ;
- notifications push ;
- statistiques consolidées ;
- tâches planifiées.

## 6. Design system

### Direction visuelle
- noir profond ;
- blanc cassé ;
- violet électrique ;
- grands rayons de bordure ;
- glassmorphism discret ;
- hiérarchie très nette ;
- peu de texte.

### Tokens à prévoir
- couleurs de base ;
- couleurs de surface ;
- gradients ;
- radius ;
- ombres ;
- blur ;
- spacing ;
- vitesses d'animation ;
- courbes d'easing.

## 7. Performance

Le projet doit être optimisé dès la fondation :

- lazy loading ;
- pagination ;
- cache d'images ;
- cache de métadonnées ;
- réutilisation des widgets ;
- limitation des rebuilds ;
- préchargement intelligent ;
- mesures de performance sur les écrans critiques.

## 8. Gouvernance qualité

À mettre en place dès le départ :

- `flutter analyze` sans erreurs ;
- conventions de nommage ;
- architecture documentée ;
- dossiers explicites ;
- tests unitaires sur la logique critique ;
- tests widget sur parcours essentiels ;
- scripts de build standardisés.

## 9. Conclusion

Cette architecture permet :

- de mutualiser le socle ;
- de conserver des interfaces spécifiques ;
- de sécuriser les flux métier ;
- d'évoluer vers une vraie plateforme commerciale.
