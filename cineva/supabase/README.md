# Supabase — Cineva

Ce dossier contient la base initiale du backend Supabase pour Cineva.

## Fichiers

- `schema.sql` : schéma SQL initial avec tables, fonctions métier et policies RLS.
- `seed_demo_catalog.sql` : catalogue de démonstration (**ne pas exécuter en production** — le contenu réel se gère depuis l'app admin).

## Mise en place recommandée

1. Créer un projet Supabase.
2. Ouvrir l'éditeur SQL.
3. Exécuter le contenu de `schema.sql` (ré-exécutable : chaque trigger / policy est précédé d'un `drop … if exists`).
4. Créer les buckets Storage privés :
   - `avatars`
   - `posters`
   - `backdrops`
   - `trailers`
   - `movies`
   - `episodes`
   - `subtitles`
5. Créer le premier utilisateur via l'application (inscription Auth).
6. **Promouvoir le premier admin** dans l'éditeur SQL :

```sql
update public.profiles
set role = 'admin'
where email = 'vous@exemple.com';
```

Le trigger `handle_new_auth_user` force toujours `role = 'user'` à la création (les clients ne peuvent plus s'auto-promouvoir via `raw_user_meta_data`). Seule une mise à jour SQL (ou une Edge Function `service_role`) peut attribuer le rôle admin.

## Durcissement & grants

- **Faille admin fermée** : le rôle applicatif n'est plus lu depuis les métadonnées Auth à l'inscription.
- **Grants** en fin de `schema.sql` : `anon` / `authenticated` / `service_role` reçoivent `usage` sur `public`, CRUD sur les tables et `execute` sur les fonctions. La sécurité ligne par ligne reste assurée par le **RLS** et les **policies**.
- Les projets Supabase créés depuis 2024 n'accordent plus ces droits par défaut — sans les grants, l'app obtient « permission denied for table ».

## Règles importantes

- ne pas exposer les vidéos en public ;
- utiliser des URLs signées de courte durée ;
- garder les opérations sensibles dans des fonctions serveur ;
- centraliser les vérifications d'abonnement et d'appareil côté backend ;
- ne pas exécuter `seed_demo_catalog.sql` sur un backend de production.

## Étape suivante recommandée

Créer les migrations versionnées, les seeds et les Edge Functions associées aux actions suivantes :

- `register-device`
- `remove-device`
- `validate-access`
- `extend-subscription`
- `set-expiration`
- `suspend-user`
- `reactivate-user`
- `create-signed-media-url`
- `send-broadcast-notification`
