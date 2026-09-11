begin;

create extension if not exists pgcrypto;
create extension if not exists citext;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.app_settings (
  key text primary key,
  value_json jsonb not null default '{}'::jsonb,
  description text,
  updated_at timestamptz not null default now()
);

insert into public.app_settings (key, value_json, description)
values (
  'limits',
  '{"max_devices_per_account": 1}'::jsonb,
  'Réglages métier globaux pour Cineva.'
)
on conflict (key) do nothing;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email citext not null unique,
  full_name text,
  avatar_path text,
  role text not null default 'user' check (role in ('user', 'admin')),
  status text not null default 'active' check (status in ('active', 'suspended', 'deleted')),
  subscription_expires_at timestamptz,
  subscription_suspended boolean not null default false,
  preferred_language text not null default 'fr',
  video_quality text not null default 'auto' check (video_quality in ('auto', 'low', 'medium', 'high', 'ultra')),
  subtitles_enabled boolean not null default true,
  autoplay_enabled boolean not null default true,
  notifications_enabled boolean not null default true,
  dark_mode boolean not null default true,
  theme_mode text not null default 'dark' check (theme_mode in ('dark', 'light', 'system')),
  privacy_settings jsonb not null default '{"personalizedRecommendations": true, "shareWatchHistoryAcrossDevices": true, "analyticsEnabled": true, "publicProfile": false}'::jsonb,
  notification_preferences jsonb not null default '{"enabled": true, "newContent": true, "downloads": true, "subscriptionReminders": true, "productUpdates": false}'::jsonb,
  vision_profile text not null default 'standard' check (vision_profile in ('standard', 'cinema', 'oled', 'ultra', 'aiBeta', 'custom')),
  vision_options jsonb not null default '{"smartSharpness": false, "enhancedColors": false, "dynamicContrast": false, "noiseReduction": false, "advancedSmoothness": false, "optimizedHdr": false, "aiEnhancement": false, "autoRecommended": true}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  device_fingerprint text not null,
  device_name text,
  platform text not null,
  app_version text,
  push_token text,
  push_token_updated_at timestamptz,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, device_fingerprint)
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  starts_at timestamptz not null default now(),
  expires_at timestamptz not null,
  status text not null default 'active' check (status in ('active', 'expired', 'suspended', 'cancelled')),
  source text not null default 'manual_admin',
  note text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.subscription_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  admin_id uuid references public.profiles(id),
  event_type text not null check (event_type in ('add_months', 'set_expiration', 'suspend', 'reactivate', 'manual_fix')),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  category_type text not null default 'generic' check (category_type in ('generic', 'genre', 'curation', 'home')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

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
  -- Sauts de temps du lecteur (intro, générique, segments à passer).
  intro_end_seconds integer,
  credits_start_seconds integer,
  skip_segments jsonb not null default '[]'::jsonb,
  is_featured boolean not null default false,
  is_published boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.series (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  original_title text,
  synopsis text,
  poster_path text,
  backdrop_path text,
  trailer_path text,
  release_year integer,
  age_rating text,
  director_name text,
  cast_names text[] not null default '{}',
  genres text[] not null default '{}',
  countries text[] not null default '{}',
  metadata jsonb not null default '{}'::jsonb,
  is_featured boolean not null default false,
  is_published boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.seasons (
  id uuid primary key default gen_random_uuid(),
  series_id uuid not null references public.series(id) on delete cascade,
  season_number integer not null,
  title text,
  synopsis text,
  poster_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (series_id, season_number)
);

create table if not exists public.episodes (
  id uuid primary key default gen_random_uuid(),
  series_id uuid not null references public.series(id) on delete cascade,
  season_id uuid not null references public.seasons(id) on delete cascade,
  episode_number integer not null,
  title text not null,
  synopsis text,
  thumbnail_path text,
  video_path text,
  duration_minutes integer,
  audio_languages text[] not null default '{}',
  subtitles jsonb not null default '[]'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  -- Segments à passer pendant la lecture (intro/générique restent en metadata).
  skip_segments jsonb not null default '[]'::jsonb,
  is_published boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (season_id, episode_number)
);

create table if not exists public.movie_categories (
  id uuid primary key default gen_random_uuid(),
  movie_id uuid not null references public.movies(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  unique (movie_id, category_id)
);

create table if not exists public.series_categories (
  id uuid primary key default gen_random_uuid(),
  series_id uuid not null references public.series(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  unique (series_id, category_id)
);

create table if not exists public.home_sections (
  id uuid primary key default gen_random_uuid(),
  section_key text not null unique,
  title text not null,
  layout_type text not null check (layout_type in ('hero', 'rail', 'grid', 'continue_watching', 'my_list')),
  sort_order integer not null default 0,
  is_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.home_section_items (
  id uuid primary key default gen_random_uuid(),
  home_section_id uuid not null references public.home_sections(id) on delete cascade,
  content_type text not null check (content_type in ('movie', 'series')),
  content_id uuid not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (home_section_id, content_type, content_id)
);

create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  content_type text not null check (content_type in ('movie', 'series')),
  content_id uuid not null,
  created_at timestamptz not null default now(),
  unique (user_id, content_type, content_id)
);

create table if not exists public.history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  content_type text not null check (content_type in ('movie', 'episode', 'series')),
  content_id uuid not null,
  current_position_seconds integer not null default 0,
  total_duration_seconds integer not null default 0,
  progress_percent numeric(5,2) not null default 0,
  is_completed boolean not null default false,
  last_watched_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, content_type, content_id)
);

create table if not exists public.downloads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  content_type text not null check (content_type in ('movie', 'episode', 'series')),
  content_id uuid not null,
  local_device_fingerprint text not null,
  status text not null default 'queued' check (status in ('queued', 'downloading', 'paused', 'completed', 'failed', 'deleted', 'expired')),
  progress_percent numeric(5,2) not null default 0,
  downloaded_bytes integer not null default 0,
  total_bytes integer not null default 0,
  local_file_path text,
  license_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  payload jsonb not null default '{}'::jsonb,
  channel text not null default 'general',
  status text not null default 'draft' check (status in ('draft', 'scheduled', 'sent', 'failed', 'cancelled')),
  scheduled_at timestamptz,
  sent_at timestamptz,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.admin_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  admin_id uuid not null references public.profiles(id) on delete cascade,
  note text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.watch_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  content_type text not null check (content_type in ('movie', 'episode')),
  content_id uuid not null,
  event_name text not null check (event_name in ('play', 'pause', 'resume', 'seek', 'complete', 'download_start', 'download_complete')),
  event_value integer,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    email,
    full_name,
    role,
    status,
    preferred_language,
    video_quality,
    subtitles_enabled,
    autoplay_enabled,
    notifications_enabled,
    dark_mode,
    theme_mode,
    privacy_settings,
    notification_preferences,
    vision_profile,
    vision_options
  ) values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', 'Utilisateur Cineva'),
    'user',
    'active',
    'fr',
    'auto',
    true,
    true,
    true,
    true,
    'dark',
    '{"personalizedRecommendations": true, "shareWatchHistoryAcrossDevices": true, "analyticsEnabled": true, "publicProfile": false}'::jsonb,
    '{"enabled": true, "newContent": true, "downloads": true, "subscriptionReminders": true, "productUpdates": false}'::jsonb,
    'standard',
    '{"smartSharpness": false, "enhancedColors": false, "dynamicContrast": false, "noiseReduction": false, "advancedSmoothness": false, "optimizedHdr": false, "aiEnhancement": false, "autoRecommended": true}'::jsonb
  )
  on conflict (id) do update
  set email = excluded.email,
      full_name = excluded.full_name,
      updated_at = now();

  return new;
end;
$$;

create or replace function public.handle_auth_user_updated()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set email = coalesce(new.email, profiles.email),
      full_name = coalesce(new.raw_user_meta_data ->> 'full_name', profiles.full_name),
      updated_at = now()
  where id = new.id;

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

create or replace function public.has_active_subscription(p_user_id uuid default auth.uid())
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
      and (
        role = 'admin'
        or (
          status = 'active'
          and subscription_suspended = false
          and subscription_expires_at is not null
          and subscription_expires_at > now()
        )
      )
  );
$$;

create or replace function public.get_max_devices_per_account()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select (value_json ->> 'max_devices_per_account')::integer
      from public.app_settings
      where key = 'limits'
    ),
    1
  );
$$;

create or replace function public.register_device(
  p_device_fingerprint text,
  p_device_name text,
  p_platform text,
  p_app_version text default null
)
returns public.devices
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_device public.devices;
  v_limit integer;
  v_count integer;
begin
  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select *
  into v_device
  from public.devices
  where user_id = v_user_id
    and device_fingerprint = p_device_fingerprint
  limit 1;

  if found then
    update public.devices
    set device_name = coalesce(p_device_name, device_name),
        platform = coalesce(p_platform, platform),
        app_version = coalesce(p_app_version, app_version),
        is_active = true,
        last_seen_at = now(),
        updated_at = now()
    where id = v_device.id
    returning * into v_device;

    return v_device;
  end if;

  v_limit := public.get_max_devices_per_account();

  select count(*)
  into v_count
  from public.devices
  where user_id = v_user_id
    and is_active = true;

  if v_count >= v_limit then
    raise exception 'DEVICE_LIMIT_REACHED';
  end if;

  insert into public.devices (
    user_id,
    device_fingerprint,
    device_name,
    platform,
    app_version,
    is_active,
    last_seen_at
  ) values (
    v_user_id,
    p_device_fingerprint,
    p_device_name,
    p_platform,
    p_app_version,
    true,
    now()
  )
  returning * into v_device;

  return v_device;
end;
$$;

create or replace function public.remove_device(p_device_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_owner uuid;
begin
  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select user_id into v_owner
  from public.devices
  where id = p_device_id;

  if v_owner is null then
    return;
  end if;

  if v_owner <> v_user_id and not public.is_admin(v_user_id) then
    raise exception 'NOT_AUTHORIZED';
  end if;

  delete from public.devices
  where id = p_device_id;
end;
$$;

create or replace function public.disconnect_all_devices(p_target_user_id uuid default auth.uid())
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_target_user_id <> v_user_id and not public.is_admin(v_user_id) then
    raise exception 'NOT_AUTHORIZED';
  end if;

  delete from public.devices
  where user_id = p_target_user_id;
end;
$$;

create or replace function public.sync_profile_subscription_expiration(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_latest_expiration timestamptz;
begin
  select max(expires_at)
  into v_latest_expiration
  from public.subscriptions
  where user_id = p_user_id
    and status in ('active', 'expired', 'suspended');

  update public.profiles
  set subscription_expires_at = v_latest_expiration,
      updated_at = now()
  where id = p_user_id;
end;
$$;

create or replace function public.extend_subscription_months(
  p_user_id uuid,
  p_months integer,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid := auth.uid();
  v_base timestamptz;
  v_new_expiration timestamptz;
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'NOT_AUTHORIZED';
  end if;

  select greatest(coalesce(subscription_expires_at, now()), now())
  into v_base
  from public.profiles
  where id = p_user_id;

  v_new_expiration := v_base + make_interval(months => p_months);

  insert into public.subscriptions (
    user_id,
    starts_at,
    expires_at,
    status,
    source,
    note,
    created_by
  ) values (
    p_user_id,
    now(),
    v_new_expiration,
    'active',
    'manual_admin',
    p_note,
    v_admin_id
  );

  update public.profiles
  set subscription_expires_at = v_new_expiration,
      subscription_suspended = false,
      status = 'active',
      updated_at = now()
  where id = p_user_id;

  insert into public.subscription_events (user_id, admin_id, event_type, payload)
  values (
    p_user_id,
    v_admin_id,
    'add_months',
    jsonb_build_object('months', p_months, 'new_expiration', v_new_expiration, 'note', p_note)
  );
end;
$$;

create or replace function public.set_subscription_expiration(
  p_user_id uuid,
  p_expires_at timestamptz,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid := auth.uid();
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'NOT_AUTHORIZED';
  end if;

  update public.profiles
  set subscription_expires_at = p_expires_at,
      subscription_suspended = false,
      status = case when p_expires_at > now() then 'active' else 'suspended' end,
      updated_at = now()
  where id = p_user_id;

  insert into public.subscription_events (user_id, admin_id, event_type, payload)
  values (
    p_user_id,
    v_admin_id,
    'set_expiration',
    jsonb_build_object('expires_at', p_expires_at, 'note', p_note)
  );
end;
$$;

create or replace function public.suspend_user_subscription(
  p_user_id uuid,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid := auth.uid();
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'NOT_AUTHORIZED';
  end if;

  update public.profiles
  set subscription_suspended = true,
      status = 'suspended',
      updated_at = now()
  where id = p_user_id;

  insert into public.subscription_events (user_id, admin_id, event_type, payload)
  values (
    p_user_id,
    v_admin_id,
    'suspend',
    jsonb_build_object('note', p_note)
  );
end;
$$;

create or replace function public.reactivate_user_subscription(
  p_user_id uuid,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid := auth.uid();
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'NOT_AUTHORIZED';
  end if;

  update public.profiles
  set subscription_suspended = false,
      status = case
        when subscription_expires_at is not null and subscription_expires_at > now() then 'active'
        else 'suspended'
      end,
      updated_at = now()
  where id = p_user_id;

  insert into public.subscription_events (user_id, admin_id, event_type, payload)
  values (
    p_user_id,
    v_admin_id,
    'reactivate',
    jsonb_build_object('note', p_note)
  );
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists trg_devices_updated_at on public.devices;
create trigger trg_devices_updated_at
before update on public.devices
for each row execute function public.set_updated_at();

drop trigger if exists trg_subscriptions_updated_at on public.subscriptions;
create trigger trg_subscriptions_updated_at
before update on public.subscriptions
for each row execute function public.set_updated_at();

drop trigger if exists trg_categories_updated_at on public.categories;
create trigger trg_categories_updated_at
before update on public.categories
for each row execute function public.set_updated_at();

drop trigger if exists trg_movies_updated_at on public.movies;
create trigger trg_movies_updated_at
before update on public.movies
for each row execute function public.set_updated_at();

drop trigger if exists trg_series_updated_at on public.series;
create trigger trg_series_updated_at
before update on public.series
for each row execute function public.set_updated_at();

drop trigger if exists trg_seasons_updated_at on public.seasons;
create trigger trg_seasons_updated_at
before update on public.seasons
for each row execute function public.set_updated_at();

drop trigger if exists trg_episodes_updated_at on public.episodes;
create trigger trg_episodes_updated_at
before update on public.episodes
for each row execute function public.set_updated_at();

drop trigger if exists trg_home_sections_updated_at on public.home_sections;
create trigger trg_home_sections_updated_at
before update on public.home_sections
for each row execute function public.set_updated_at();

drop trigger if exists trg_history_updated_at on public.history;
create trigger trg_history_updated_at
before update on public.history
for each row execute function public.set_updated_at();

drop trigger if exists trg_downloads_updated_at on public.downloads;
create trigger trg_downloads_updated_at
before update on public.downloads
for each row execute function public.set_updated_at();

drop trigger if exists trg_notifications_updated_at on public.notifications;
create trigger trg_notifications_updated_at
before update on public.notifications
for each row execute function public.set_updated_at();

drop trigger if exists trg_admin_notes_updated_at on public.admin_notes;
create trigger trg_admin_notes_updated_at
before update on public.admin_notes
for each row execute function public.set_updated_at();

create index if not exists idx_profiles_role_status_expiration
  on public.profiles (role, status, subscription_expires_at);
create index if not exists idx_devices_user_last_seen
  on public.devices (user_id, last_seen_at desc);
create index if not exists idx_devices_push_token
  on public.devices (push_token)
  where push_token is not null;
create index if not exists idx_subscriptions_user_expires_status
  on public.subscriptions (user_id, expires_at desc, status);
create index if not exists idx_subscription_events_user_created
  on public.subscription_events (user_id, created_at desc);
create index if not exists idx_movies_published_featured
  on public.movies (is_published, is_featured, published_at desc);
create index if not exists idx_series_published_featured
  on public.series (is_published, is_featured, published_at desc);
create index if not exists idx_seasons_series_number
  on public.seasons (series_id, season_number);
create index if not exists idx_episodes_season_number
  on public.episodes (season_id, episode_number);
create index if not exists idx_episodes_series_published
  on public.episodes (series_id, is_published, published_at desc);
create index if not exists idx_home_sections_order
  on public.home_sections (sort_order, is_enabled);
create index if not exists idx_home_section_items_section_order
  on public.home_section_items (home_section_id, sort_order);
create index if not exists idx_favorites_user_created
  on public.favorites (user_id, created_at desc);
create index if not exists idx_history_user_watched
  on public.history (user_id, last_watched_at desc);
create index if not exists idx_downloads_user_status_updated
  on public.downloads (user_id, status, updated_at desc);
create index if not exists idx_notifications_status_schedule
  on public.notifications (status, scheduled_at, created_at desc);
create index if not exists idx_watch_events_user_created
  on public.watch_events (user_id, created_at desc);
create index if not exists idx_watch_events_content_created
  on public.watch_events (content_type, content_id, created_at desc);

alter table public.app_settings enable row level security;
alter table public.profiles enable row level security;
alter table public.devices enable row level security;
alter table public.subscriptions enable row level security;
alter table public.subscription_events enable row level security;
alter table public.categories enable row level security;
alter table public.movies enable row level security;
alter table public.series enable row level security;
alter table public.seasons enable row level security;
alter table public.episodes enable row level security;
alter table public.movie_categories enable row level security;
alter table public.series_categories enable row level security;
alter table public.home_sections enable row level security;
alter table public.home_section_items enable row level security;
alter table public.favorites enable row level security;
alter table public.history enable row level security;
alter table public.downloads enable row level security;
alter table public.notifications enable row level security;
alter table public.admin_notes enable row level security;
alter table public.watch_events enable row level security;

drop policy if exists "app_settings_admin_only" on public.app_settings;
create policy "app_settings_admin_only"
on public.app_settings
for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "profiles_select_self_or_admin" on public.profiles;
create policy "profiles_select_self_or_admin"
on public.profiles
for select
using (id = auth.uid() or public.is_admin());

drop policy if exists "profiles_insert_self_or_admin" on public.profiles;
create policy "profiles_insert_self_or_admin"
on public.profiles
for insert
with check (id = auth.uid() or public.is_admin());

drop policy if exists "profiles_update_self_or_admin" on public.profiles;
create policy "profiles_update_self_or_admin"
on public.profiles
for update
using (id = auth.uid() or public.is_admin())
with check (id = auth.uid() or public.is_admin());

drop policy if exists "devices_select_self_or_admin" on public.devices;
create policy "devices_select_self_or_admin"
on public.devices
for select
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "devices_insert_self_or_admin" on public.devices;
create policy "devices_insert_self_or_admin"
on public.devices
for insert
with check (user_id = auth.uid() or public.is_admin());

drop policy if exists "devices_update_self_or_admin" on public.devices;
create policy "devices_update_self_or_admin"
on public.devices
for update
using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

drop policy if exists "devices_delete_self_or_admin" on public.devices;
create policy "devices_delete_self_or_admin"
on public.devices
for delete
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "subscriptions_select_self_or_admin" on public.subscriptions;
create policy "subscriptions_select_self_or_admin"
on public.subscriptions
for select
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "subscriptions_admin_write" on public.subscriptions;
create policy "subscriptions_admin_write"
on public.subscriptions
for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "subscription_events_select_self_or_admin" on public.subscription_events;
create policy "subscription_events_select_self_or_admin"
on public.subscription_events
for select
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "subscription_events_admin_insert" on public.subscription_events;
create policy "subscription_events_admin_insert"
on public.subscription_events
for insert
with check (public.is_admin());

drop policy if exists "categories_read_authenticated" on public.categories;
create policy "categories_read_authenticated"
on public.categories
for select
using (auth.uid() is not null);

drop policy if exists "categories_admin_write" on public.categories;
create policy "categories_admin_write"
on public.categories
for all
using (public.is_admin())
with check (public.is_admin());

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

drop policy if exists "series_read_published_or_admin" on public.series;
create policy "series_read_published_or_admin"
on public.series
for select
using ((is_published = true and auth.uid() is not null) or public.is_admin());

drop policy if exists "series_admin_write" on public.series;
create policy "series_admin_write"
on public.series
for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "seasons_read_published_or_admin" on public.seasons;
create policy "seasons_read_published_or_admin"
on public.seasons
for select
using (auth.uid() is not null or public.is_admin());

drop policy if exists "seasons_admin_write" on public.seasons;
create policy "seasons_admin_write"
on public.seasons
for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "episodes_read_published_or_admin" on public.episodes;
create policy "episodes_read_published_or_admin"
on public.episodes
for select
using ((is_published = true and auth.uid() is not null) or public.is_admin());

drop policy if exists "episodes_admin_write" on public.episodes;
create policy "episodes_admin_write"
on public.episodes
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

drop policy if exists "series_categories_read_authenticated" on public.series_categories;
create policy "series_categories_read_authenticated"
on public.series_categories
for select
using (auth.uid() is not null);

drop policy if exists "series_categories_admin_write" on public.series_categories;
create policy "series_categories_admin_write"
on public.series_categories
for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "home_sections_read_enabled_or_admin" on public.home_sections;
create policy "home_sections_read_enabled_or_admin"
on public.home_sections
for select
using ((is_enabled = true and auth.uid() is not null) or public.is_admin());

drop policy if exists "home_sections_admin_write" on public.home_sections;
create policy "home_sections_admin_write"
on public.home_sections
for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "home_section_items_read_authenticated" on public.home_section_items;
create policy "home_section_items_read_authenticated"
on public.home_section_items
for select
using (auth.uid() is not null);

drop policy if exists "home_section_items_admin_write" on public.home_section_items;
create policy "home_section_items_admin_write"
on public.home_section_items
for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "favorites_self_or_admin" on public.favorites;
create policy "favorites_self_or_admin"
on public.favorites
for all
using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

drop policy if exists "history_self_or_admin" on public.history;
create policy "history_self_or_admin"
on public.history
for all
using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

drop policy if exists "downloads_self_or_admin" on public.downloads;
create policy "downloads_self_or_admin"
on public.downloads
for all
using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

drop policy if exists "notifications_select_self_or_admin_or_broadcast" on public.notifications;
create policy "notifications_select_self_or_admin_or_broadcast"
on public.notifications
for select
using (user_id = auth.uid() or user_id is null or public.is_admin());

drop policy if exists "notifications_admin_write" on public.notifications;
create policy "notifications_admin_write"
on public.notifications
for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "admin_notes_admin_only" on public.admin_notes;
create policy "admin_notes_admin_only"
on public.admin_notes
for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "watch_events_insert_self_or_admin" on public.watch_events;
create policy "watch_events_insert_self_or_admin"
on public.watch_events
for insert
with check (user_id = auth.uid() or public.is_admin());

drop policy if exists "watch_events_select_self_or_admin" on public.watch_events;
create policy "watch_events_select_self_or_admin"
on public.watch_events
for select
using (user_id = auth.uid() or public.is_admin());

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
after update on auth.users
for each row execute function public.handle_auth_user_updated();

comment on function public.register_device(text, text, text, text) is 'Enregistre un appareil en respectant la limite serveur.';
comment on function public.extend_subscription_months(uuid, integer, text) is 'Ajoute des mois côté admin et journalise l’action.';
comment on function public.set_subscription_expiration(uuid, timestamptz, text) is 'Modifie la date d’expiration côté admin.';
comment on function public.suspend_user_subscription(uuid, text) is 'Suspend un abonnement utilisateur.';
comment on function public.reactivate_user_subscription(uuid, text) is 'Réactive un abonnement utilisateur.';
comment on function public.handle_new_auth_user() is 'Crée automatiquement le profil applicatif lors de la création d’un utilisateur Auth.';
comment on function public.handle_auth_user_updated() is 'Synchronise les champs principaux du profil lors des mises à jour Auth.';

-- Migration incrémentale (idempotente) pour les bases existantes :
-- colonnes de sauts de temps du lecteur (intro / générique / segments).
-- À exécuter dans le SQL Editor Supabase des projets antérieurs au schéma.
alter table public.movies
  add column if not exists intro_end_seconds int,
  add column if not exists credits_start_seconds int,
  add column if not exists skip_segments jsonb not null default '[]'::jsonb;
alter table public.episodes
  add column if not exists skip_segments jsonb not null default '[]'::jsonb;

commit;

-- Notes complémentaires :
-- 1. Les buckets Storage doivent rester privés pour les médias sensibles.
-- 2. Les URLs de streaming doivent être générées via une fonction serveur avec durée courte.
-- 3. Pour une production exigeante, ajouter des migrations séparées, des seeds et des tests SQL.

-- Droits d'accès pour les rôles applicatifs Supabase
-- (la sécurité ligne par ligne reste assurée par le RLS et les policies)
grant usage on schema public to anon, authenticated, service_role;
grant select, insert, update, delete
  on all tables in schema public
  to anon, authenticated, service_role;
grant execute
  on all functions in schema public
  to anon, authenticated, service_role;
