# Supabase — Cineva

Ce dossier contient la base initiale du backend Supabase pour Cineva.

## Fichiers

- `schema.sql` : schéma SQL initial avec tables, fonctions métier et policies RLS.

## Mise en place recommandée

1. Créer un projet Supabase.
2. Ouvrir l'éditeur SQL.
3. Exécuter le contenu de `schema.sql`.
4. Créer les buckets Storage privés :
   - `avatars`
   - `posters`
   - `backdrops`
   - `trailers`
   - `movies`
   - `episodes`
   - `subtitles`
5. Créer le premier utilisateur admin.
6. Mettre son rôle `profiles.role = 'admin'`.

## Règles importantes

- ne pas exposer les vidéos en public ;
- utiliser des URLs signées de courte durée ;
- garder les opérations sensibles dans des fonctions serveur ;
- centraliser les vérifications d'abonnement et d'appareil côté backend.

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
