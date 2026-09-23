-- =============================================================================
-- REPAIR — table `movies` supprimée / recréée incomplète
-- =============================================================================
-- Symptômes couverts :
--   * 42501 « autorisation refusée pour la table movies »  (Dashboard, Stats)
--   * 42763 « la colonne movies.updated_at n'existe pas »  (Catalogue)
--
-- Ce script est IDEMPOTENT : vous pouvez le rejouer sans risque. Il ne supprime
-- AUCUNE donnée (create table if not exists + add column if not exists).
--
-- Où l'exécuter : Supabase Studio → SQL Editor → coller → Run.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Fonctions dont dépendent les triggers et les policies
-- -----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_admin(p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = coalesce(p_user_id, auth.uid())
      and role = 'admin'
  );
$$;

-- -----------------------------------------------------------------------------
-- 1. La table (créée si absente ; ne fait rien si elle existe déjà)
-- -----------------------------------------------------------------------------
create table if not exists public.movies (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  original_title text,
  synopsis text,
  poster_path text,
  backdrop_path text,
  trailer_path text,
  video_path text,
  release_year integer,
  duration_minutes integer,
  age_rating text,
  director_name text,
  cast_names text[] not null default '{}',
  genres text[] not null default '{}',
  countries text[] not null default '{}',
  audio_languages text[] not null default '{}',
  subtitles jsonb not null default '[]'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  intro_end_seconds integer,
  credits_start_seconds integer,
  skip_segments jsonb not null default '[]'::jsonb,
  is_featured boolean not null default false,
  is_published boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- 2. Colonnes manquantes (cas d'une table recréée à la main, sans updated_at)
-- -----------------------------------------------------------------------------
alter table public.movies add column if not exists title text not null default '';
alter table public.movies add column if not exists original_title text;
alter table public.movies add column if not exists synopsis text;
alter table public.movies add column if not exists poster_path text;
alter table public.movies add column if not exists backdrop_path text;
alter table public.movies add column if not exists trailer_path text;
alter table public.movies add column if not exists video_path text;
alter table public.movies add column if not exists release_year integer;
alter table public.movies add column if not exists duration_minutes integer;
alter table public.movies add column if not exists age_rating text;
alter table public.movies add column if not exists director_name text;
alter table public.movies add column if not exists cast_names text[] not null default '{}';
alter table public.movies add column if not exists genres text[] not null default '{}';
alter table public.movies add column if not exists countries text[] not null default '{}';
alter table public.movies add column if not exists audio_languages text[] not null default '{}';
alter table public.movies add column if not exists subtitles jsonb not null default '[]'::jsonb;
alter table public.movies add column if not exists metadata jsonb not null default '{}'::jsonb;
alter table public.movies add column if not exists intro_end_seconds integer;
alter table public.movies add column if not exists credits_start_seconds integer;
alter table public.movies add column if not exists skip_segments jsonb not null default '[]'::jsonb;
alter table public.movies add column if not exists is_featured boolean not null default false;
alter table public.movies add column if not exists is_published boolean not null default false;
alter table public.movies add column if not exists published_at timestamptz;
alter table public.movies add column if not exists created_at timestamptz not null default now();
alter table public.movies add column if not exists updated_at timestamptz not null default now();

-- `title` est NOT NULL sans défaut dans le schéma d'origine : on retire le
-- défaut temporaire ajouté ci-dessus pour les tables déjà peuplées.
alter table public.movies alter column title drop default;

-- -----------------------------------------------------------------------------
-- 3. Table de liaison films ↔ catégories (supprimée en cascade avec movies)
-- -----------------------------------------------------------------------------
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  category_type text not null default 'generic'
    check (category_type in ('generic', 'genre', 'curation', 'home')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Colonnes manquantes si la table a été recréée à la main (nulles ou à défaut,
-- donc sans risque sur une table déjà peuplée).
alter table public.categories add column if not exists name text;
alter table public.categories add column if not exists slug text;
alter table public.categories add column if not exists category_type text not null default 'generic';
alter table public.categories add column if not exists created_at timestamptz not null default now();
alter table public.categories add column if not exists updated_at timestamptz not null default now();

drop trigger if exists trg_categories_updated_at on public.categories;
create trigger trg_categories_updated_at
before update on public.categories
for each row execute function public.set_updated_at();

create table if not exists public.movie_categories (
  id uuid primary key default gen_random_uuid(),
  movie_id uuid not null references public.movies(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  unique (movie_id, category_id)
);

create index if not exists idx_movie_categories_movie on public.movie_categories (movie_id);
create index if not exists idx_movie_categories_category on public.movie_categories (category_id);

-- -----------------------------------------------------------------------------
-- 4. Trigger `updated_at` + index de lecture
-- -----------------------------------------------------------------------------
drop trigger if exists trg_movies_updated_at on public.movies;
create trigger trg_movies_updated_at
before update on public.movies
for each row execute function public.set_updated_at();

create index if not exists idx_movies_published_featured
  on public.movies (is_published, is_featured, published_at desc);

-- -----------------------------------------------------------------------------
-- 5. RLS + policies (identiques au schéma d'origine)
-- -----------------------------------------------------------------------------
alter table public.movies enable row level security;
alter table public.movie_categories enable row level security;
alter table public.categories enable row level security;

drop policy if exists "movies_read_published_or_admin" on public.movies;
create policy "movies_read_published_or_admin"
on public.movies
for select
using ((is_published = true and auth.uid() is not null) or public.is_admin());

drop policy if exists "movies_admin_write" on public.movies;
create policy "movies_admin_write"
on public.movies
for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "categories_read_authenticated" on public.categories;
create policy "categories_read_authenticated"
on public.categories
for select
using (auth.uid() is not null);

-- Nettoyage d'une éventuelle policy fantôme créée par une version précédente
-- de ce script (elle référençait une colonne is_enabled qui n'existe pas).
drop policy if exists "categories_read_enabled_or_admin" on public.categories;

drop policy if exists "categories_admin_write" on public.categories;
create policy "categories_admin_write"
on public.categories
for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "movie_categories_read_authenticated" on public.movie_categories;
create policy "movie_categories_read_authenticated"
on public.movie_categories
for select
using (auth.uid() is not null);

drop policy if exists "movie_categories_admin_write" on public.movie_categories;
create policy "movie_categories_admin_write"
on public.movie_categories
for all
using (public.is_admin())
with check (public.is_admin());

-- -----------------------------------------------------------------------------
-- 6. DROITS — la cause des erreurs 42501
--    `grant ... on all tables` ne vaut que pour les tables existantes AU MOMENT
--    du grant : toute table recréée après coup perd ses droits. D'où l'ajout
--    des « default privileges » pour que ça ne se reproduise plus.
-- -----------------------------------------------------------------------------
grant usage on schema public to anon, authenticated, service_role;

grant select, insert, update, delete
  on all tables in schema public
  to anon, authenticated, service_role;

grant usage, select
  on all sequences in schema public
  to anon, authenticated, service_role;

grant execute
  on all functions in schema public
  to anon, authenticated, service_role;

-- Les prochaines tables créées par postgres hériteront automatiquement des droits.
alter default privileges for role postgres in schema public
  grant select, insert, update, delete on tables to anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  grant usage, select on sequences to anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  grant execute on functions to anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 7. Offre : 5 appareils par abonnement (la limite était à 1 par défaut)
--    C'est cette valeur que lit register_device() avant de lever
--    « device_limit_reached » — l'écran « Limite d'appareils » de l'app suit.
-- -----------------------------------------------------------------------------
insert into public.app_settings (key, value_json, description)
values (
  'limits',
  '{"max_devices_per_account": 5, "max_profiles_per_account": 5, "monthly_price_eur": 15}'::jsonb,
  'Réglages métier globaux pour Cineva : 15 €/mois, 5 appareils, 5 profils.'
)
on conflict (key) do update
set value_json = excluded.value_json,
    description = excluded.description,
    updated_at = now();

-- -----------------------------------------------------------------------------
-- 8. Contrôle — tout doit renvoyer true / 5
-- -----------------------------------------------------------------------------
select
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'movies' and column_name = 'updated_at'
  ) as colonne_updated_at_ok,
  exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'movie_categories'
  ) as table_movie_categories_ok,
  (select (value_json ->> 'max_devices_per_account')::int from public.app_settings where key = 'limits') as max_appareils,
  (select count(*) from public.movies) as films_en_base;
