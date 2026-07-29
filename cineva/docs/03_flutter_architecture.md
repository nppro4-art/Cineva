# 03 — Architecture Flutter recommandée

## 1. Objectif

Construire une base Flutter moderne, premium et stable, capable de desservir plusieurs supports tout en gardant une maintenance saine.

## 2. Pile Flutter recommandée

- `flutter_riverpod` pour l'état
- `go_router` pour la navigation
- `freezed` + `json_serializable` pour les modèles
- `supabase_flutter` pour l'intégration backend
- `intl` pour la localisation
- `cached_network_image` ou équivalent pour le cache visuel
- solution de lecture vidéo à valider selon DRM / TV / offline
- `firebase_messaging` pour FCM

## 3. Découpage des packages

### `packages/theme`
Contient :
- palette ;
- thèmes clair/sombre si utile ;
- tokens d'espacement ;
- radius ;
- elevations ;
- effets verre ;
- durées et courbes d'animations.

### `packages/ui`
Composants visuels transverses :
- boutons ;
- cartes ;
- sheets ;
- app bars ;
- sections ;
- placeholders ;
- loaders premium.

### `packages/animations`
- transitions de route ;
- micro-interactions ;
- wrappers de fade/slide/scale ;
- helpers 60/120 Hz friendly.

### `packages/models`
- entités métier ;
- DTO ;
- sérialisation.

### `packages/repositories`
- contrats d'accès aux données ;
- implémentations Supabase ;
- mapping DTO vers modèles.

### `packages/services`
- auth service ;
- device service ;
- subscription service ;
- storage/media service ;
- notifications service ;
- analytics service ;
- player session service.

### `packages/shared`
- constantes ;
- utilitaires ;
- extensions ;
- résultats typés ;
- erreurs métier.

## 4. Apps cibles

## 4.1 `cineva_mobile`
Couvre :
- Android téléphone ;
- Android tablette ;
- iPhone ;
- iPad.

Navigation principale :
- Accueil
- Recherche
- Téléchargements
- Compte

## 4.2 `cineva_admin`
Priorité UX :
- desktop ;
- web si activé ;
- éventuellement tablette.

Sections :
- dashboard ;
- utilisateurs ;
- films ;
- séries ;
- accueil ;
- notifications ;
- statistiques.

## 4.3 `cineva_windows` / `cineva_macos`
Deux options possibles :
- apps dédiées ;
- ou un shell commun dérivé d'une base utilisateur desktop.

## 4.4 `cineva_android_tv`
Doit avoir :
- focus manager clair ;
- composants navigables à la télécommande ;
- panneaux horizontaux ;
- player adapté au D-pad.

## 5. Responsive + adaptive design

Breakpoints recommandés :
- `< 600` : mobile
- `600 - 1024` : tablette
- `1024 - 1440` : desktop compact
- `> 1440` : desktop large / TV selon contexte

Mais le support ne doit pas dépendre uniquement de la largeur :
- présence d'un pointeur ;
- mode TV ;
- contrôle clavier ;
- télécommande.

## 6. Navigation

### Mobile
- bottom navigation ;
- transitions douces ;
- routes profondes pour détails et player.

### Desktop
- sidebar persistante ;
- raccourcis clavier ;
- états hover.

### TV
- navigation par focus ;
- retour logique ;
- actions primaires visibles.

## 7. Performance Flutter

À faire dès le début :
- utiliser `const` partout où pertinent ;
- éviter les rebuilds massifs ;
- virtualiser les longues listes ;
- précharger affiches critiques ;
- séparer les providers par responsabilité ;
- profiler les écrans home et player.

## 8. Animations premium

Les animations doivent être :
- discrètes ;
- fluides ;
- cohérentes ;
- jamais gadget.

Base recommandée :
- 150 à 220 ms pour micro-interactions ;
- 220 à 320 ms pour transitions d'écran ;
- easing douces type cubic.

Effets cibles :
- fade ;
- slide subtil ;
- scale léger ;
- depth/parallax mesuré ;
- skeleton loading haut de gamme.

## 9. Tests

À prévoir :
- tests unitaires pour règles métier ;
- tests widget pour shell, compte, expiration abonnement ;
- tests d'intégration sur login, player, admin user flow.

## 10. Conclusion

L'architecture Flutter doit privilégier :
- modularité ;
- sobriété ;
- performance ;
- adaptation réelle aux supports ;
- indépendance entre apps ;
- mutualisation du socle quand cela a du sens.
