-- ============================================================================
-- Cineva — réparation des colonnes NOT NULL héritées (movies / series)
-- ----------------------------------------------------------------------------
-- À jouer quand l'enregistrement d'une fiche échoue avec :
--
--   23502  null value in column "sources" of relation "movies"
--          violates not-null constraint
--
-- Cause : la table `movies` (ou `series`) de votre projet Supabase contient une
-- colonne qui n'est pas dans `supabase/schema.sql` — elle provient d'un schéma
-- plus ancien ou d'un autre projet. Elle est déclarée NOT NULL **sans valeur
-- par défaut**, donc toute insertion qui ne la renseigne pas est refusée.
-- L'application Cineva ne l'écrit pas : elle ne peut pas deviner son contenu.
--
-- Ce script ne supprime AUCUNE colonne et ne modifie AUCUNE donnée : il pose
-- simplement une valeur par défaut adaptée au type (ou, pour un type exotique,
-- rend la colonne optionnelle). Il est rejouable sans risque.
--
-- Ordre conseillé : `repair_movies.sql` (tables + droits) →
--                   `repair_not_null_columns.sql` (ce script) →
--                   `migration_profils_abonnement.sql`.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. État des lieux : colonnes exigées par la base mais jamais écrites par
--    l'application. Vide = rien à réparer.
-- ---------------------------------------------------------------------------
select c.table_name  as table_concernee,
       c.column_name as colonne,
       c.data_type   as type,
       'NOT NULL sans défaut' as probleme
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name in ('movies', 'series')
  and c.is_nullable = 'NO'
  and c.column_default is null
  and c.column_name not in (
    -- colonnes gérées par l'application (supabase/schema.sql)
    'id', 'title', 'original_title', 'synopsis', 'poster_path', 'backdrop_path',
    'logo_path', 'trailer_path', 'video_path', 'release_year', 'duration_minutes',
    'age_rating', 'director_name', 'cast_names', 'genres', 'countries',
    'audio_languages', 'subtitles', 'metadata', 'intro_end_seconds',
    'credits_start_seconds', 'skip_segments', 'is_featured', 'is_published',
    'published_at', 'created_at', 'updated_at'
  )
order by c.table_name, c.ordinal_position;

-- ---------------------------------------------------------------------------
-- 2. Réparation : valeur par défaut selon le type (aucune donnée touchée).
-- ---------------------------------------------------------------------------
do $$
declare
  col record;
  def text;
begin
  for col in
    select c.table_name, c.column_name, c.data_type
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name in ('movies', 'series')
      and c.is_nullable = 'NO'
      and c.column_default is null
      and c.column_name not in (
        'id', 'title', 'original_title', 'synopsis', 'poster_path', 'backdrop_path',
        'logo_path', 'trailer_path', 'video_path', 'release_year', 'duration_minutes',
        'age_rating', 'director_name', 'cast_names', 'genres', 'countries',
        'audio_languages', 'subtitles', 'metadata', 'intro_end_seconds',
        'credits_start_seconds', 'skip_segments', 'is_featured', 'is_published',
        'published_at', 'created_at', 'updated_at'
      )
  loop
    def := case
      when col.data_type in ('jsonb', 'json')                            then '''[]''::jsonb'
      when col.data_type = 'ARRAY'                                       then '''{}'''
      when col.data_type in ('text', 'character varying', 'character')    then ''''''
      when col.data_type in ('integer', 'bigint', 'smallint', 'numeric',
                             'real', 'double precision')                 then '0'
      when col.data_type = 'boolean'                                     then 'false'
      when col.data_type = 'uuid'                                        then 'gen_random_uuid()'
      when col.data_type like 'timestamp%'                               then 'now()'
      else null
    end;

    if def is null then
      -- Type exotique (enum, géométrie…) : on ne devine pas de valeur, on rend
      -- simplement la colonne optionnelle. Contrairement plus souple : aucune
      -- lecture ni écriture existante n'est cassée.
      execute format('alter table public.%I alter column %I drop not null',
                     col.table_name, col.column_name);
      raise notice '%.% (%) : colonne rendue optionnelle',
                   col.table_name, col.column_name, col.data_type;
    else
      execute format('alter table public.%I alter column %I set default %s',
                     col.table_name, col.column_name, def);
      raise notice '%.% (%) : valeur par défaut % posée',
                   col.table_name, col.column_name, col.data_type, def;
    end if;
  end loop;
end
$$;

-- ---------------------------------------------------------------------------
-- 3. Vérification : ne doivent rester que les colonnes réellement obligatoires
--    et gérées par l'application (id, title, created_at, updated_at).
-- ---------------------------------------------------------------------------
select c.table_name, c.column_name, c.data_type, c.column_default
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name in ('movies', 'series')
  and c.is_nullable = 'NO'
  and c.column_default is null
order by c.table_name, c.ordinal_position;

-- ---------------------------------------------------------------------------
-- 4. Ce script ne touche PAS aux droits : c'est le rôle de
--    `supabase/repair_movies.sql` (GRANT + droits par défaut + tables
--    manquantes). Si l'app abonné n'affiche rien alors que la fiche est
--    enregistrée et publiée, jouez-le en entier, puis
--    `supabase/migration_profils_abonnement.sql`.
-- ---------------------------------------------------------------------------
