# Cineva — Audit RC1 Quality

## Contexte

Feature Freeze maintenu.

Objectif : transformer Cineva en Release Candidate 1 stable, testable et maintenable.

Limitation de l'audit : l'environnement actuel ne permet pas d'exécuter `flutter analyze`, `flutter test` ni les builds natifs. Cet audit repose donc sur une inspection statique approfondie du dépôt et des flux fonctionnels déjà implémentés.

---

## 1. Points excellents

### Architecture générale
- Monorepo cohérent avec séparation `apps/`, `packages/`, `supabase/`.
- Découpage en packages fonctionnels pertinent : `models`, `repositories`, `services`, `widgets`, `theme`, `ui`.
- La logique métier critique a déjà été largement déplacée hors de l'UI.
- Le backend Supabase, les Edge Functions et le stockage sont déjà intégrés dans l'architecture cible.

### Application utilisateur
- Parcours principal crédible : Home, Recherche, Fiche contenu, Compte, Paramètres.
- Le produit fonctionne avec données dynamiques et fallback demo.
- Cineva Vision est intégré comme système transverse réel et non simple mock.
- Le lecteur est bien avancé : reprise, overlay, changement qualité logique, épisodes suivants, contrôles gestuels.

### Admin
- Gestion utilisateurs solide.
- Gestion abonnements solide.
- Catalogue devenu un vrai CMS exploitable.
- Éditeur d'accueil réel.
- Notifications administrables.

### Backend / Supabase
- RLS présente sur la majorité des tables critiques.
- Fonctions SQL métier déjà en place pour abonnements et appareils.
- Edge Function admin-user-management en place pour éviter d'exposer la service role côté client.

---

## 2. Points à améliorer

### Priorité critique
1. Le lecteur n'est pas encore validé sur de vrais flux HLS/DASH multi-qualités.
2. Le changement multi-audio / sous-titres est UI-first ; la validation réelle dépend des capacités du player et des flux.
3. Les téléchargements sont avancés mais ne sont pas encore au niveau d'un gestionnaire natif background complet.
4. Le pipeline FCM serveur existe mais doit être validé bout-en-bout en environnement réel.
5. `app_settings` est la seule table métier sans RLS activée dans le schéma actuel.
6. Les agrégations statistiques Admin se font encore beaucoup côté client / repository.

### Priorité importante
1. Plusieurs fichiers sont très volumineux et nuisent à la maintenabilité.
2. Duplications d'extensions `IterableFirstOrNullX` dans plusieurs fichiers.
3. Les providers sont centralisés dans un seul fichier `providers.dart`, créant du couplage.
4. Certains écrans Admin (catalogue) ont une logique UI + orchestration trop dense.
5. Les fonctions Edge utilisent des CORS larges (`*`) et peu de validation d'entrée.
6. Le nettoyage des tokens invalides FCM est amorcé mais pas complètement industrialisé.

### Priorité mineure
1. Quelques messages d'erreur pourraient être encore plus normalisés.
2. Certaines micro-interactions et états vides pourraient être harmonisés.
3. Les thèmes clair/sombre doivent encore être validés plus largement sur tous les écrans.

---

## 3. Dette technique

### Dette technique significative
- `packages/widgets/lib/src/admin/catalog_screen.dart`
- `packages/widgets/lib/src/player/player_screen.dart`
- `packages/repositories/lib/src/supabase_admin_repository.dart`
- `packages/repositories/lib/src/supabase_catalog_repository.dart`
- `packages/repositories/lib/src/supabase_user_library_repository.dart`
- `packages/widgets/lib/src/user/content_detail_screen.dart`
- `packages/widgets/lib/src/user/home_screen.dart`
- `packages/widgets/lib/src/vision/cineva_vision_settings_screen.dart`

### Dette technique structurelle
- duplication des helpers d'itération ;
- logique player encore trop concentrée ;
- logique downloads encore trop couplée au stockage local ;
- logique admin catalogue trop monolithique ;
- pas encore de couche QA automatisée d'intégration suffisamment dense.

---

## 4. Fichiers à refactoriser

### Critiques
- `packages/widgets/lib/src/player/player_screen.dart`
  - trop de responsabilités : lifecycle, player, gestes, erreurs, qualité, offline, navigation.
- `packages/widgets/lib/src/admin/catalog_screen.dart`
  - trop grand ; plusieurs formulaires et dialogues dans un seul fichier.
- `packages/repositories/lib/src/supabase_admin_repository.dart`
  - repository énorme, mélange plusieurs domaines admin.

### Importants
- `packages/repositories/lib/src/supabase_catalog_repository.dart`
  - logique catalogue + parsing + fallback demo + mapping trop concentrés.
- `packages/repositories/lib/src/supabase_user_library_repository.dart`
  - offline + persistance + sync + fallback réunis.
- `packages/widgets/lib/src/app/providers.dart`
  - point central dense ; bonne cible pour découpage par domaine.

---

## 5. Risques

### Techniques
- comportement du player selon plateforme réelle ;
- compatibilité réelle HLS/DASH ;
- différences Android / iOS / desktop / TV ;
- background download dépendant du cycle de vie OS ;
- notifications dépendantes des credentials réels et de Firebase ;
- absence de scheduler documenté pour `process-scheduled-notifications`.

### Fonctionnels
- multi-audio / sous-titres peut ne pas correspondre au rendu réel sans flux compatibles ;
- fichiers offline manquants / corrompus à gérer plus durement ;
- expérience Android TV à valider en navigation réelle.

### Publication
- pas encore de validation builds release ;
- pas encore de signatures / icônes / splash finaux ;
- pas encore de campagne QA multi-appareils complète.

---

## 6. Plan d'action ordonné

### RC1
1. Finaliser / valider Player.
2. Finaliser / valider Téléchargements.
3. Finaliser / valider Notifications.
4. Corriger les points critiques de sécurité (RLS `app_settings`, validation Edge Functions).
5. Démarrer la campagne de validation réelle par plateforme.

### RC2 si nécessaire
1. Corriger les anomalies découvertes sur appareils réels.
2. Durcir offline / notifications / TV.
3. Optimiser les écrans lourds et les repos volumineux.

### Version 1.0
1. Phase RC1 Quality complète.
2. Optimisation globale.
3. QA exhaustive.
4. Préparation release et publication.

---

## 7. Synthèse

Cineva n'est plus dans une phase de construction, mais dans une phase de fiabilisation.

Le projet a déjà un niveau très supérieur à un simple prototype :
- architecture exploitable ;
- parcours utilisateur crédible ;
- administration réelle ;
- backend cohérent.

Les prochains gains de qualité proviendront principalement :
- de la validation réelle sur appareils ;
- du refactoring des fichiers trop volumineux ;
- du durcissement player / downloads / notifications ;
- de la campagne QA et de la préparation release.
