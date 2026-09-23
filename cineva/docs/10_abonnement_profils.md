# 10 — Abonnement (15 € / mois), appareils et profils du foyer

Un abonnement Cineva couvre **tout le foyer** : 15 € par mois, **5 appareils**
(téléphone, PC, TV) et **5 profils membres**. Le règlement se fait directement
auprès de l'exploitant — par carte via Revolut (`@noah_s0_xy5c`) ou en main
propre (+33 7 87 14 69 92). Aucun paiement en ligne n'est intégré ni simulé.

---

## A. Réparer la base après une suppression de table

Deux scripts SQL idempotents, à jouer dans **Supabase Studio → SQL Editor**
(compte administrateur). Rejouables sans risque : ils ne suppriment aucune
donnée.

### 1. `cineva/supabase/repair_movies.sql` — à jouer en premier

Répare les trois erreurs vues dans la console d'administration :

| Erreur | Cause | Ce que fait le script |
| --- | --- | --- |
| `42501 autorisation refusée pour la table « movies »` (Dashboard, Stats) | `GRANT … ON ALL TABLES` ne vaut que pour les tables existantes **au moment du grant** : une table recréée après coup naît sans droits | rejoue les `GRANT` **et** pose des `ALTER DEFAULT PRIVILEGES` pour que les tables futures héritent des droits |
| `42763 la colonne movies.updated_at n'existe pas` (Catalogue) | table recréée avec un DDL partiel | `CREATE TABLE IF NOT EXISTS` complet **+** `ADD COLUMN IF NOT EXISTS` sur les 26 colonnes |
| liaison films ↔ catégories perdue | `movie_categories` référence `movies(id)` avec `ON DELETE CASCADE` : elle est partie avec la table | recrée `movie_categories` (et `categories` si besoin), index compris |

Le script restaure aussi le trigger `updated_at`, l'index de lecture
`(is_published, is_featured, published_at desc)`, le RLS et les deux policies
(`movies_read_published_or_admin`, `movies_admin_write`), et place l'offre à
**5 appareils / 5 profils / 15 €** dans `app_settings.limits`.

Une requête de contrôle termine le script : `colonne_updated_at_ok` et
`table_movie_categories_ok` doivent valoir `true`, `max_appareils` doit valoir `5`.

### 2. `cineva/supabase/migration_profils_abonnement.sql` — pour les profils

Crée la table `member_profiles` et rattache les données personnelles au profil :

- `member_profiles` : `account_id` (le compte abonné), `name`, `avatar_key`,
  `color_key`, `is_kid`, `sort_order` — unicité du nom par compte ;
- **plafond de 5 profils** appliqué par un trigger (`profile_limit_reached`),
  la valeur venant de `app_settings.limits.max_profiles_per_account` ;
- un **« Profil principal »** créé pour chaque compte existant : personne ne se
  retrouve sans profil ;
- colonne `profile_id` ajoutée à `favorites`, `history`, `downloads`,
  `watch_events` — **nullable** : les anciennes versions de l'app continuent
  d'écrire, un trigger (`assign_default_member_profile`) rattache ces écritures
  au profil par défaut ;
- les lignes existantes sont rattachées à ce profil par défaut ;
- les contraintes d'unicité passent de « par compte » à « par profil »
  (`favorites_unique_per_profile`, `history_unique_per_profile`) : sans ça, le
  second membre qui aime le même film serait refusé ;
- RLS : un compte ne voit et ne modifie que ses propres profils.

**Ordre à respecter** : `repair_movies.sql` puis
`migration_profils_abonnement.sql`, puis installer le nouveau build. Un build
récent sur une base non migrée ne casse rien (les requêtes `profile_id` échouent,
sont rattrapées, et l'app retombe sur son cache local), mais les profils
afficheront « Profils indisponibles ».

## B. Changer le nombre d'appareils ou de profils

Les plafonds **techniques** vivent en base, pas dans le code :

```sql
update public.app_settings
set value_json = '{"max_devices_per_account": 5, "max_profiles_per_account": 5, "monthly_price_eur": 15}'::jsonb,
    updated_at = now()
where key = 'limits';
```

- `max_devices_per_account` est lu par `register_device()` : au-delà, la fonction
  lève `device_limit_reached`, l'app bascule sur l'écran « Limite d'appareils »
  où l'on déconnecte un appareil. Aucun rebuild nécessaire.
- `max_profiles_per_account` est lu par `enforce_member_profile_limit()`.

Les valeurs **affichées** (prix, libellés, coordonnées) sont dans
`packages/shared/lib/src/cineva_offer.dart` (`CinevaOffer`) et demandent un
rebuild. Elles ne peuvent pas venir de `app_settings` : cette table est protégée
par une policy « administration uniquement », l'app abonné ne peut pas la lire.

## C. Côté application

| Écran | Route | Contenu |
| --- | --- | --- |
| Profil → **Abonnement & paiement** | `/account/subscription` | prix, ce qui est compris, appareils x/5, profils x/5, date d'expiration, marche à suivre pour payer, téléphone et Revolut copiables d'un geste |
| Profil → **Profils du foyer** | `/account/profiles` | liste des profils, création (nom, avatar, couleur, profil enfant), modification, suppression, profil actif |
| Profil → **Appareils** | `/account/devices` | appareils connectés, déconnexion unitaire ou globale |

**Ce qui est par profil** : la liste de favoris (« Ma liste ») et la reprise de
lecture (« Reprendre »), en base comme dans le cache local de l'appareil.
Changer de profil recharge la bibliothèque — les données des autres membres ne
se mélangent pas.

**Ce qui reste par appareil** : le profil actif choisi (mémorisé localement,
chaque appareil du foyer garde le sien) et les fichiers téléchargés.

**Ce qui reste par compte** : l'abonnement, sa date d'expiration, les appareils
autorisés, les réglages de lecture.

### Supprimer un profil

La suppression est définitive et emporte les favoris et l'historique de ce
profil (cascade en base sur `profile_id`). Une feuille de confirmation le dit
explicitement avant l'action. L'abonnement et les autres profils ne bougent pas.

## D. Où est le code

| Rôle | Fichier |
| --- | --- |
| Offre, prix, coordonnées | `packages/shared/lib/src/cineva_offer.dart` |
| Modèle de profil membre | `packages/models/lib/src/member_profile_model.dart` |
| Contrat + implémentation Supabase | `packages/repositories/lib/src/member_profile_repository.dart`, `supabase_member_profile_repository.dart` |
| Profil actif partagé avec la bibliothèque | `packages/repositories/lib/src/member_profile_scope.dart` |
| Filtrage par profil (favoris, reprise) | `packages/repositories/lib/src/supabase_user_library_repository.dart` |
| Cache local par profil | `packages/services/lib/src/storage/local_preferences_service.dart` |
| Contrôleur (chargement, bascule, plafond) | `packages/widgets/lib/src/library/active_profile_controller.dart` |
| Écrans | `packages/widgets/lib/src/user/subscription_screen.dart`, `profiles_screen.dart` |
| Tests | `packages/{shared,models,repositories,widgets}/test/*profile*`, `cineva_offer_test.dart` |
