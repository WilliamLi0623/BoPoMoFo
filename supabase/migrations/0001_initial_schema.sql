create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz
);

create table public.devices (
  device_id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null default 'unknown',
  app_version text not null default 'unknown',
  last_sync_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.learning_events (
  event_id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  item_id text not null,
  skill text not null,
  occurred_at timestamptz not null,
  correct boolean not null,
  latency_ms integer not null default 0 check (latency_ms >= 0),
  hint_count integer not null default 0 check (hint_count >= 0),
  retry_count integer not null default 0 check (retry_count >= 0),
  response text,
  uploaded_at timestamptz not null default now(),
  event_type text not null default 'review',
  rating text,
  content_version text not null default '1',
  algorithm_version text not null default 'fsrs-lite-v1',
  created_at timestamptz not null default now()
);

create table public.skill_snapshots (
  snapshot_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null,
  skill text not null,
  stability double precision not null default 0,
  difficulty double precision not null default 5,
  last_review_at timestamptz,
  due_at timestamptz not null,
  algorithm_version text not null default 'fsrs-lite-v1',
  content_version text not null default '1',
  updated_at timestamptz not null default now(),
  unique (user_id, item_id, skill)
);

create table public.confusion_edges (
  edge_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  expected text not null,
  response text not null,
  exposure_count integer not null default 0 check (exposure_count >= 0),
  error_count integer not null default 0 check (error_count >= 0),
  updated_at timestamptz not null default now(),
  unique (user_id, expected, response)
);

create table public.user_settings (
  user_id uuid not null references auth.users(id) on delete cascade,
  key text not null,
  value text not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);

create table public.sync_state (
  user_id uuid not null references auth.users(id) on delete cascade,
  key text not null,
  value text not null default '',
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);
