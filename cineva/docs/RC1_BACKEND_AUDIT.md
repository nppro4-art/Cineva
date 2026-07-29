# Cineva — Audit Backend RC1

## Module audité
Backend Supabase

## Périmètre
- Schéma SQL principal
- Tables, contraintes, clés étrangères
- RLS et policies
- Edge Functions
- Repositories Supabase côté client

## Résultat
**❌ Backend NON VALIDÉ RC1**

Le backend est structurellement avancé et proche d'un niveau production sur plusieurs aspects, mais il reste des éléments bloquants avant de pouvoir le certifier RC1 :
- absence de validation réelle des migrations sur un environnement peuplé ;
- absence de tests d'intégration backend automatisés ;
- plusieurs repositories Supabase restent trop volumineux ;
- les Edge Functions existent mais ne sont pas encore prouvées en conditions réelles ;
- la performance réelle des requêtes n'a pas encore été mesurée sur une base significative.

---

## 1. Points excellents

### Schéma général
- Le modèle de données couvre bien les domaines clés : utilisateurs, appareils, abonnements, films, séries, saisons, épisodes, favoris, historique, téléchargements, notifications.
- Les relations principales sont déjà correctement modélisées avec des clés étrangères explicites.
- Les fonctions SQL critiques existent déjà pour les appareils et abonnements.

### Sécurité générale
- La majorité des tables métier sont déjà protégées par RLS.
- Les opérations critiques ne reposent pas uniquement sur le client Flutter.
- Le rôle admin est déjà central dans les contrôles d'accès.
- Les Edge Functions admin passent déjà par un contrôle du rôle avant exécution.

### Évolutivité
- Le schéma est suffisamment modulaire pour supporter l'évolution de Cineva.
- Les repositories backend sont déjà séparés par domaine fonctionnel (session, catalogue, user library, admin, settings).

---

## 2. Corrections et refactorings réalisés dans ce lot

### SQL / RLS / index
- Activation RLS sur `app_settings`.
- Ajout d'une policy admin-only sur `app_settings`.
- Ajout d'index sur les zones critiques :
  - profils
  - devices
  - subscriptions
  - subscription_events
  - movies
  - series
  - seasons
  - episodes
  - home_sections
  - home_section_items
  - favorites
  - history
  - downloads
  - notifications
  - watch_events

### Edge Functions
- `admin-user-management`
  - validation minimale des entrées ;
  - validation email / uuid / rôle / statut ;
  - validation date optionnelle.
- `send-fcm-notification`
  - validation de `title`, `body`, `userId`, `scheduledAt` ;
  - nettoyage des tokens invalides FCM.
- `process-scheduled-notifications`
  - ajout d'un `CRON_SECRET` obligatoire ;
  - rejet si le header de sécurité est absent ;
  - nettoyage des tokens invalides.

### Repositories Supabase
- création de `supabase_support.dart` pour centraliser :
  - mapping `AppUser` ;
  - mapping `DeviceModel` ;
  - mapping `AppSettingsModel` ;
  - helpers JSON / listes / dates.
- refactoring partiel de :
  - `supabase_session_repository.dart`
  - `supabase_admin_repository.dart`
  - `supabase_catalog_repository.dart`
  - `supabase_user_library_repository.dart`
- réduction de certaines duplications backend.

---

## 3. Points critiques (à corriger avant RC1)

### Critique 1 — Absence de validation réelle des migrations
Le schéma est devenu conséquent (1000+ lignes). Sans exécution automatisée des migrations sur une base propre et une base déjà peuplée, le risque de divergence entre environnement théorique et réel reste élevé.

### Critique 2 — Repositories backend encore trop massifs
Les fichiers suivants sont trop gros pour un backend RC1 serein :
- `supabase_admin_repository.dart`
- `supabase_catalog_repository.dart`
- `supabase_user_library_repository.dart`

Ils mélangent encore :
- requêtes,
- mapping,
- règles métier locales,
- stratégies de fallback.

### Critique 3 — Pas de tests d'intégration backend
Il n'existe pas encore de validation automatisée couvrant :
- les policies RLS ;
- les fonctions SQL ;
- les Edge Functions ;
- les scénarios admin critiques.

### Critique 4 — Notifications programmées non prouvées en conditions réelles
La fonction existe, mais elle dépend :
- d'un secret cron correctement configuré ;
- d'un scheduler externe / Supabase Cron ;
- de la bonne configuration Firebase.

Sans validation réelle, ce n'est pas certifiable RC1.

---

## 4. Points importants (à corriger avant Version 1.0)

### Important 1 — Mesure réelle des performances SQL absente
Les index ajoutés améliorent la trajectoire, mais il manque encore :
- des `EXPLAIN ANALYZE` réels ;
- une mesure sur volume réaliste ;
- une validation de latence sur les requêtes lourdes.

### Important 2 — Observabilité backend limitée
Il manque une vraie stratégie de journalisation / diagnostic pour :
- Edge Functions ;
- notifications ;
- téléchargements ;
- erreurs player liées aux URLs signées.

### Important 3 — Règles et contraintes supplémentaires possibles
Le schéma fonctionne, mais certaines validations métiers pourraient être renforcées :
- cohérence `scheduled_at/status` dans notifications ;
- cohérence `downloaded_bytes <= total_bytes` ;
- validation métier plus stricte sur home sections.

---

## 5. Points mineurs (optimisations futures)
- découpage plus fin des mappers et DTO côté repositories ;
- centralisation des helpers `firstOrNull` ;
- amélioration du typage des payloads JSON ;
- homogénéisation du parsing des métadonnées.

---

## 6. Dette technique backend restante

### Dette majeure
- `packages/repositories/lib/src/supabase_admin_repository.dart`
- `packages/repositories/lib/src/supabase_catalog_repository.dart`
- `packages/repositories/lib/src/supabase_user_library_repository.dart`

### Dette moyenne
- `packages/repositories/lib/src/supabase_app_settings_repository.dart`
- `packages/repositories/lib/src/supabase_session_repository.dart`
- `supabase/schema.sql`

---

## 7. Fichiers à refactoriser

### Priorité haute
1. `packages/repositories/lib/src/supabase_admin_repository.dart`
   - trop de responsabilités ;
   - domaine admin trop large dans un seul fichier.

2. `packages/repositories/lib/src/supabase_catalog_repository.dart`
   - mélange fallback demo, requêtes, mapping, logique de détail.

3. `packages/repositories/lib/src/supabase_user_library_repository.dart`
   - mélange sync Supabase, fallback local, offline, téléchargements.

### Priorité moyenne
4. `packages/repositories/lib/src/supabase_app_settings_repository.dart`
5. `packages/repositories/lib/src/supabase_session_repository.dart`
6. `supabase/schema.sql`
   - il faudra le faire évoluer vers une vraie stratégie de migrations versionnées.

---

## 8. Sécurité — analyse

### Points forts
- RLS maintenant présente sur toutes les tables métier principales.
- Les fonctions admin sont derrière vérification de rôle.
- L'usage de la service role reste côté Edge Functions.

### Risques critiques restants
- nécessité de valider réellement les policies RLS sur une base peuplée ;
- nécessité de vérifier que les Edge Functions ne sont pas exposées sans la bonne configuration d'environnement ;
- nécessité de valider la sécurité effective de `process-scheduled-notifications` avec `CRON_SECRET` réel.

### Risques importants
- certaines validations d'entrée côté Edge Functions restent minimales ;
- les payloads JSON restent partiellement libres ;
- la politique de gestion des tokens push invalides doit être vérifiée en prod.

---

## 9. Performance — analyse

### Améliorations faites
- ajout d'index ciblés.

### Goulots potentiels restants
- agrégations statistiques Admin faites côté repository ;
- requêtes catalogue pouvant devenir coûteuses à grand volume ;
- lecture répétée des métadonnées JSON ;
- certaines requêtes restent peu paginées.

### Optimisations les plus rentables
1. mesurer les requêtes stats / catalogue sur base peuplée ;
2. déplacer certaines agrégations côté SQL / vues / fonctions ;
3. introduire pagination côté admin pour les listes volumineuses.

---

## 10. Décision finale RC1

### ❌ Backend NON VALIDÉ RC1

#### Éléments bloquants précis
1. Pas encore de validation réelle des migrations.
2. Pas encore de campagne de test RLS / Edge Functions.
3. Pas encore de validation réelle du pipeline notifications programmé.
4. Repositories backend centraux encore trop massifs.
5. Pas encore de preuve de performance réelle sur volume de données réaliste.

---

## 11. Prochaines actions recommandées

### Pour valider le backend RC1
1. Exécuter le schéma et les fonctions sur un projet Supabase propre.
2. Lancer un jeu de données réaliste.
3. Tester les policies RLS table par table.
4. Tester les Edge Functions avec rôles admin / non-admin.
5. Mesurer les requêtes les plus lourdes.
6. Refactoriser les 3 gros repositories backend.

Une fois ces points traités, le backend pourra être réévalué pour une décision **VALIDÉ RC1**.
