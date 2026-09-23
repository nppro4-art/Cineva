-- =============================================================================
-- MIGRATION — Profils membres (5 profils pour un abonnement) + offre 15 €/mois
-- =============================================================================
-- Un abonnement Cineva = 15 €/mois, 5 appareils, 5 profils. Chaque membre du
-- foyer a son profil : ses favoris, sa reprise de lecture et ses téléchargements
-- à lui, sur le même compte et le même abonnement.
--
-- Idempotent : rejouable sans risque, ne supprime aucune donnée.
-- Rétrocompatible : les lignes existantes (et les anciennes versions de l'app)
-- continuent d'écrire — un trigger rattache automatiquement les écritures sans
-- profil au profil par défaut du compte.
--
-- Prérequis : avoir joué `repair_movies.sql` (fonctions is_admin/set_updated_at,
-- droits par défaut, réglage `limits` à 5 appareils / 5 profils / 15 €).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Réglages métier (lus par les fonctions ci-dessous et par la console admin)
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

create or replace function public.get_max_profiles_per_account()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select (value_json ->> 'max_profiles_per_account')::integer
      from public.app_settings
      where key = 'limits'
    ),
    5
  );
$$;

-- -----------------------------------------------------------------------------
-- 2. Table des profils membres
-- -----------------------------------------------------------------------------
create table if not exists public.member_profiles (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  avatar_key text not null default 'popcorn',
  color_key text not null default 'gold',
  is_kid boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (account_id, name)
);

create index if not exists idx_member_profiles_account
  on public.member_profiles (account_id, sort_order);

drop trigger if exists trg_member_profiles_updated_at on public.member_profiles;
create trigger trg_member_profiles_updated_at
before update on public.member_profiles
for each row execute function public.set_updated_at();

-- Plafond : 5 profils par abonnement (valeur pilotée par app_settings).
create or replace function public.enforce_member_profile_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_max integer;
  v_count integer;
begin
  v_max := public.get_max_profiles_per_account();
  select count(*) into v_count
  from public.member_profiles
  where account_id = new.account_id;

  if v_count >= v_max then
    raise exception 'profile_limit_reached: % profils maximum pour cet abonnement', v_max
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_member_profiles_limit on public.member_profiles;
create trigger trg_member_profiles_limit
before insert on public.member_profiles
for each row execute function public.enforce_member_profile_limit();

-- -----------------------------------------------------------------------------
-- 3. Un profil par défaut pour chaque compte existant
--    (aucun compte ne se retrouve sans profil après la migration)
-- -----------------------------------------------------------------------------
insert into public.member_profiles (account_id, name, avatar_key, color_key, sort_order)
select p.id, 'Profil principal', 'popcorn', 'gold', 0
from public.profiles p
where not exists (
  select 1 from public.member_profiles mp where mp.account_id = p.id
);

-- -----------------------------------------------------------------------------
-- 4. Rattachement des données personnelles au profil
--    Colonne NULLABLE : les anciennes versions de l'app continuent d'écrire,
--    le trigger complète avec le profil par défaut du compte.
-- -----------------------------------------------------------------------------
alter table public.favorites    add column if not exists profile_id uuid references public.member_profiles(id) on delete cascade;
alter table public.history      add column if not exists profile_id uuid references public.member_profiles(id) on delete cascade;
alter table public.downloads    add column if not exists profile_id uuid references public.member_profiles(id) on delete cascade;
alter table public.watch_events add column if not exists profile_id uuid references public.member_profiles(id) on delete set null;

create or replace function public.assign_default_member_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.profile_id is null and new.user_id is not null then
    select mp.id into new.profile_id
    from public.member_profiles mp
    where mp.account_id = new.user_id
    order by mp.sort_order, mp.created_at
    limit 1;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_favorites_default_profile on public.favorites;
create trigger trg_favorites_default_profile
before insert on public.favorites
for each row execute function public.assign_default_member_profile();

drop trigger if exists trg_history_default_profile on public.history;
create trigger trg_history_default_profile
before insert on public.history
for each row execute function public.assign_default_member_profile();

drop trigger if exists trg_downloads_default_profile on public.downloads;
create trigger trg_downloads_default_profile
before insert on public.downloads
for each row execute function public.assign_default_member_profile();

drop trigger if exists trg_watch_events_default_profile on public.watch_events;
create trigger trg_watch_events_default_profile
before insert on public.watch_events
for each row execute function public.assign_default_member_profile();

-- Rattachement des lignes existantes au profil par défaut de leur compte.
--
-- Sous-requête corrélée dans le SET (et PAS `update ... from lateral (...)`) :
-- dans un UPDATE, la table cible ne fait pas partie de la from_list, donc un
-- item LATERAL n'a pas le droit de la référencer — PostgreSQL refuse avec
-- « 42P10 invalid reference to FROM-clause entry for table "t" ».
-- Le `exists` évite d'écrire NULL sur les lignes d'un compte sans profil.
update public.favorites t
set profile_id = (
  select mp.id
  from public.member_profiles mp
  where mp.account_id = t.user_id
  order by mp.sort_order, mp.created_at
  limit 1
)
where t.profile_id is null
  and exists (
    select 1 from public.member_profiles mp2 where mp2.account_id = t.user_id
  );

update public.history t
set profile_id = (
  select mp.id
  from public.member_profiles mp
  where mp.account_id = t.user_id
  order by mp.sort_order, mp.created_at
  limit 1
)
where t.profile_id is null
  and exists (
    select 1 from public.member_profiles mp2 where mp2.account_id = t.user_id
  );

update public.downloads t
set profile_id = (
  select mp.id
  from public.member_profiles mp
  where mp.account_id = t.user_id
  order by mp.sort_order, mp.created_at
  limit 1
)
where t.profile_id is null
  and exists (
    select 1 from public.member_profiles mp2 where mp2.account_id = t.user_id
  );

-- -----------------------------------------------------------------------------
-- 5. Unicités par profil (deux membres peuvent aimer le même film)
--    L'ancienne unicité « par compte » est remplacée, pas simplement ajoutée :
--    sans ça, le second profil qui aime le même film serait refusé.
-- -----------------------------------------------------------------------------
-- L'ancienne unicité « par compte » porte un nom auto-généré par PostgreSQL
-- (`favorites_user_id_content_type_content_id_key`) qui peut différer si la
-- table a été recréée à la main. On la supprime donc **par ses colonnes**, pas
-- par son nom : une vieille contrainte oubliée empêcherait deux profils du même
-- foyer d'aimer le même film, sans message d'erreur pour le dire.
do $$
declare
  legacy record;
begin
  for legacy in
    select rel.relname as table_name, con.conname as constraint_name
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and con.contype = 'u'
      and rel.relname in ('favorites', 'history')
      and (
        select array_agg(a.attname::text order by a.attname::text)
        from unnest(con.conkey) as k(attnum)
        join pg_attribute a on a.attrelid = con.conrelid and a.attnum = k.attnum
      ) = array['content_id', 'content_type', 'user_id']
  loop
    execute format('alter table public.%I drop constraint %I',
                   legacy.table_name, legacy.constraint_name);
  end loop;
end;
$$;

alter table public.favorites drop constraint if exists favorites_unique_per_profile;
alter table public.favorites
  add constraint favorites_unique_per_profile unique (user_id, profile_id, content_type, content_id);

alter table public.history drop constraint if exists history_unique_per_profile;
alter table public.history
  add constraint history_unique_per_profile unique (user_id, profile_id, content_type, content_id);

create index if not exists idx_favorites_profile on public.favorites (profile_id);
create index if not exists idx_history_profile on public.history (profile_id, last_watched_at desc);
create index if not exists idx_downloads_profile on public.downloads (profile_id);

-- -----------------------------------------------------------------------------
-- 6. RLS : chaque compte ne voit que ses profils (et l'administration)
-- -----------------------------------------------------------------------------
alter table public.member_profiles enable row level security;

drop policy if exists "member_profiles_owner_or_admin" on public.member_profiles;
create policy "member_profiles_owner_or_admin"
on public.member_profiles
for all
using (account_id = auth.uid() or public.is_admin())
with check (account_id = auth.uid() or public.is_admin());

-- favorites / history / downloads / watch_events gardent leurs policies
-- existantes (`*_self_or_admin` : le compte lit et écrit ses propres lignes).
-- Le filtrage par membre se fait sur `profile_id`, côté application : aucune
-- policy supplémentaire, donc aucun risque de couper un accès en place.

-- -----------------------------------------------------------------------------
-- 7. Droits (au cas où les « default privileges » n'auraient pas été joués)
-- -----------------------------------------------------------------------------
grant select, insert, update, delete
  on public.member_profiles, public.favorites, public.history, public.downloads, public.watch_events
  to anon, authenticated, service_role;

grant execute
  on function public.get_max_profiles_per_account(),
     public.enforce_member_profile_limit(),
     public.assign_default_member_profile()
  to anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 8. Contrôle
-- -----------------------------------------------------------------------------
select
  (select count(*) from public.member_profiles)                                   as profils_crees,
  (select public.get_max_profiles_per_account())                                  as max_profils,
  (select (value_json ->> 'max_devices_per_account')::int
     from public.app_settings where key = 'limits')                               as max_appareils,
  (select count(*) from public.favorites where profile_id is null)                as favoris_non_rattaches,
  (select count(*) from public.history where profile_id is null)                  as historique_non_rattache,
  (select count(*)
     from pg_constraint con
     join pg_class rel on rel.oid = con.conrelid
     join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and con.contype = 'u'
      and rel.relname in ('favorites', 'history')
      and (
        select array_agg(a.attname::text order by a.attname::text)
        from unnest(con.conkey) as k(attnum)
        join pg_attribute a on a.attrelid = con.conrelid and a.attnum = k.attnum
      ) = array['content_id', 'content_type', 'user_id'])                        as anciennes_unicites_restantes;
