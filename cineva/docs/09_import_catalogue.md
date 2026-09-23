# 09 — Alimenter le catalogue depuis la console d'administration

Trois voies d'import coexistent dans **Catalogue → Films** (et **Séries** pour les
deux premières). Toutes écrivent dans les vraies tables Supabase via
`AdminRepository.saveMovie` / `saveSeries` : aucune donnée de démonstration.

| Voie | Ce que vous fournissez | Ce qui est rempli automatiquement | Bouton |
| --- | --- | --- | --- |
| **Lien TMDB** | un lien ou un id TMDB | titre, synopsis, affiches, note, casting, réalisateur, bande-annonce | « Importer (TMDB) » |
| **URL vidéo** | l'URL de **votre** fichier vidéo | titre pré-rempli depuis le nom du fichier + fiche TMDB choisie parmi les candidats | « Importer une URL vidéo » |
| **Internet Archive** | une source (collection, élément, mots-clés) | lots de films du domaine public : affiche, synopsis, année, durée, résolution, licence, **fichier MP4 direct** | « Importer (Archive.org) » |

---

## A. Import par URL vidéo (votre fichier, vos droits)

Cas d'usage : vous hébergez le fichier (stockage Supabase, CDN, votre serveur) et
vous ne voulez pas saisir la fiche à la main.

1. Collez l'URL : `https://cdn.mon-site.fr/films/inception.2010.1080p.mp4`.
2. Le titre est déduit du nom de fichier (`inception`) et l'année détectée (`2010`).
   Le champ reste modifiable — **rien n'est envoyé à TMDB sans que vous le voyiez**.
3. « Chercher sur TMDB » renvoie une liste de candidats (affiche, année, note,
   amorce de synopsis). Vous cliquez sur la bonne fiche.

   La recherche est **tolérante** : le titre saisi est d'abord nettoyé (année
   retirée du texte et transformée en filtre, entités HTML comme `&gt;`,
   guillemets, balises de copie `1080p.WEB-DL.x264-VOSTFR`, ponctuation finale),
   puis TMDB est interrogé du plus précis au plus large jusqu'à obtenir des
   fiches :

   | Ordre | Requête |
   | --- | --- |
   | 1 | titre complet + année, en français |
   | 2 | titre complet sans année, en français |
   | 3 | titre court (avant la virgule) + année, puis sans année |
   | 4 | titre sans accents |
   | 5 | titre complet puis titre court, sur la fiche anglaise (`en-US`) |

   « Vaiana, la legende du bout du monde (2026) » trouve donc la fiche même sans
   accents, même si l'année est fausse, et même si TMDB n'indexe que « Vaiana ».
   Les virgules et apostrophes internes sont conservées (elles font partie des
   titres français), et un mot de langue n'est retiré qu'en **fin** de titre :
   « The French Dispatch » reste intact.
4. L'éditeur de catalogue s'ouvre pré-rempli, **URL vidéo déjà en place**. Vous
   complétez (catégories, langues, publication) et enregistrez.

Nom de fichier non exploitable (empreinte, UUID, `master.m3u8`) : le champ titre
reste vide et un bouton **« Créer sans TMDB »** ouvre l'éditeur avec l'URL vidéo
seule. Aucune fiche fantaisiste n'est produite.

Formats lus : MP4/H.264 et HLS sur Android (`video_player`/ExoPlayer), et les
mêmes plus MKV/HEVC sur Windows (`media_kit`/libmpv — cf. `08_build_release.md`).

## B. Import en masse depuis Internet Archive

Internet Archive héberge des milliers de longs-métrages **librement diffusables**
avec leurs fichiers vidéo directs. C'est la seule source externe que Cineva
énumère automatiquement.

Sources acceptées :

```
https://archive.org/details/feature_films      ← collection, énumérée
https://archive.org/details/sex_madness        ← élément unique
collection:feature_films                       ← syntaxe courte
night of the living dead                       ← mots-clés (limités aux films)
```

Déroulé : énumération via `/advancedsearch.php`, puis passage de chaque candidat
dans `/metadata/<id>` pour vérifier la présence d'un **MP4 réel**. Les éléments
sans MP4 (MPEG2, Ogg Theora — illisibles sur ExoPlayer) sont écartés, jamais
remplacés par une URL devinée. L'affiche vient de `/services/img/<id>`, la durée
du fichier vidéo lui-même.

Réglages de la boîte de dialogue :

- **12 / 24 / 48** candidats par parcours ;
- **« Ne garder que les licences explicitement ouvertes »** : filtre sur
  `licenseurl` / `rights` (domaine public, Creative Commons) ;
- **catégorie** de destination commune au lot ;
- **« Publier immédiatement »** — désactivé par défaut : l'import crée des
  **brouillons** à relire, comme le flux TMDB.

Chaque fiche importée garde sa provenance dans `metadata` : `source`,
`archive_identifier`, `archive_item_url`, `archive_license`,
`archive_license_open`, et `archive_subtitle_url` quand un `.srt` existe.

### Vérification des droits avant publication

« Gratuit » ne veut pas dire « libre ». Avant de publier un lot :

1. la **licence affichée** sur la fiche doit être explicite (domaine public, CC) ;
2. en cas de doute, ouvrir `archive_item_url` et lire la mention de droits de
   l'élément ;
3. « Licence non précisée » = vous vérifiez, ou vous ne publiez pas.

## C. Ce que Cineva ne fait pas, et ne fera pas

Aucune de ces voies n'aspire un site tiers : pas de parcours de site de streaming,
pas d'extraction de lecteur embarqué, pas de magnets ni de torrents, pas de
téléchargement de flux protégés, pas de contournement d'anti-bot.

Raisons, dans l'ordre :

- **droit** : rediffuser une œuvre protégée sans autorisation est de la contrefaçon
  (3 ans / 300 000 € en France). Héberger l'index, c'est l'endosser ;
- **technique** : ces sources sont instables par construction (domaines qui
  tournent, lecteurs qui changent, liens qui meurent). Un catalogue bâti dessus
  se vide tout seul ;
- **exposition** : le backend Supabase, les clés et l'APK signé portent votre nom.

`ArchiveOrgReference.tryParse` renvoie `null` pour toute URL qui n'est pas
`archive.org` : la limite est écrite dans le code, et un test la vérifie.

Pour ajouter un film récent ou une série sous licence, la voie est un **accord de
distribution** : le fichier ou le flux vous est fourni, vous le collez dans
« Importer une URL vidéo » (voie A), ou vous l'uploadez dans le bucket Storage
depuis l'éditeur de catalogue.

## D. Où est le code

| Rôle | Fichier |
| --- | --- |
| Client Internet Archive (énumération, fiche, choix du MP4, licence) | `packages/repositories/lib/src/archive/archive_org_client.dart` |
| Titre déduit d'une URL vidéo | `packages/repositories/lib/src/tmdb/media_url_title_hint.dart` |
| Recherche de candidats TMDB | `packages/repositories/lib/src/tmdb/tmdb_client.dart` (`searchTitles`, `_searchOnce`, `parseSearchResults`) |
| Nettoyage du titre + tentatives de recherche | `packages/repositories/lib/src/tmdb/tmdb_search_plan.dart` (`buildTmdbQueryPlan`, `sanitizeTmdbTitle`, `extractTmdbYear`, `shortTmdbTitle`, `stripTmdbAccents`) |
| Contrat d'import côté admin | `packages/repositories/lib/src/admin_repository.dart` (`searchTmdbTitles`) |
| Boîte de dialogue « URL vidéo » | `packages/widgets/lib/src/admin/catalog_media_url_import.dart` |
| Boîte de dialogue « Archive.org » | `packages/widgets/lib/src/admin/catalog_archive_import.dart` |
| Tests (hors réseau) | `packages/repositories/test/{archive_org_client,media_url_title_hint,tmdb_search}_test.dart` |

Les analyses réseau sont isolées dans `ArchiveOrgClient` / `TmdbClient` ; les
parseurs sont `static` et testés sur des réponses réelles tronquées, sans aucun
appel réseau en CI.

---

## Dépannage : « je remplis la fiche, rien ne s’enregistre »

Un film n’est visible dans l’app abonné que si **trois** conditions sont réunies.
Elles sont indépendantes : la fiche peut être en base sans être publiée, et
publiée sans être sur l’accueil.

| # | Condition | Où la vérifier |
|---|-----------|----------------|
| 1 | Les tables et les droits existent (`movies`, `movie_categories`, GRANT `authenticated`) | SQL Editor — `supabase/repair_movies.sql` |
| 2 | La fiche est **publiée** (interrupteur « Publier ce contenu ») | Admin → Catalogue → Films, colonne/badge « Publié » |
| 3 | La fiche figure dans une **section d’accueil** | Admin → Catalogue → onglet « Accueil » (ou `supabase/seed_demo_catalog.sql`) |

Sans la condition 3, l’accueil de l’app affiche son état vide : le film reste
trouvable par la **Recherche**, mais n’apparaît sur aucun rail.

### Comportement de l’application (depuis `binaries-16`)

* La boîte de dialogue **reste ouverte** pendant l’enregistrement ; le bouton
  « Enregistrer » se transforme en indicateur de progression et « Annuler » est
  désactivé tant que le travail n’est pas terminé.
* En cas d’échec, l’erreur s’affiche **dans la boîte de dialogue**, avec une
  explication en clair pour les codes PostgreSQL usuels (`42P01` table absente,
  `42501` droits refusés, `42703` colonne manquante, `23502` colonne exigée par
  une base plus ancienne, `23505` doublon, `23503` référence introuvable,
  `PGRST301` session expirée).
* La fiche enregistrée mais dont les **catégories** n’ont pas pu être liées
  (table de liaison absente) n’est plus un échec : le film est bien en base, un
  avertissement explique quoi jouer pour rétablir les liaisons. La liste du
  catalogue se charge même sans table de liaison (catégories vides).
* Le message de succès distingue « Film enregistré et publié. » de
  « Film enregistré — non publié : il reste invisible dans l’app… ».

### Diagnostic SQL (SQL Editor, 10 secondes)

```sql
-- 1. Tables présentes ? (une erreur « relation does not exist » ici = table manquante)
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('movies','series','categories','movie_categories',
                     'series_categories','home_sections','home_section_items')
order by table_name;

-- 2. Droits de lecture du rôle abonné sur les films ? (0 ligne = GRANT absent)
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'movies'
  and privilege_type = 'SELECT';

-- 3. Contenu réellement publié ?
select count(*) as films,
       count(*) filter (where is_published) as films_publies
from public.movies;

-- 4. Accueil alimenté ?
select (select count(*) from public.home_sections)      as sections,
       (select count(*) from public.home_section_items) as elements;
```

Si l’étape 1 ou 2 est incomplète : rejouer **en entier**
`supabase/repair_movies.sql`, puis `supabase/migration_profils_abonnement.sql`.

### Base plus ancienne que l’application (erreur `23502`)

Symptôme : tout est rempli, et l’enregistrement répond

```
null value in column "sources" of relation "movies" violates not-null constraint (23502)
```

La table `movies` du projet contient une colonne qui **n’est pas** dans
`supabase/schema.sql` (ici `sources`), héritée d’un schéma plus ancien ou d’un
autre projet, déclarée `NOT NULL` **sans valeur par défaut**. L’application ne
l’écrit pas — elle ne peut pas deviner son contenu — et Postgres refuse donc
l’insertion. Rien à voir avec les champs laissés vides : seul `title` est
obligatoire, toutes les autres colonnes de l’application sont nullable ou ont un
défaut.

Deux réponses, complémentaires :

* **en base (recommandé)** — `supabase/repair_not_null_columns.sql` : pose une
  valeur par défaut adaptée au type de chaque colonne concernée (ou la rend
  optionnelle si le type est exotique). Aucune colonne supprimée, aucune donnée
  modifiée, script rejouable.
* **dans l’application** — l’upsert est tolérant : sur `23502`, la colonne est
  initialisée avec une valeur neutre de la forme observée sur une ligne
  existante (liste jsonb, objet, texte, nombre, booléen) et un avertissement le
  signale. La fiche est donc enregistrée même avant d’avoir joué le script.

Le même mécanisme fonctionne en sens inverse (`42703`) : une colonne du payload
que la base ne connaît pas encore est retirée et l’écriture retentée.
