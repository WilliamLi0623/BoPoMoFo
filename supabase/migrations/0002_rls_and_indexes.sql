create index learning_events_user_occurred_event
  on public.learning_events (user_id, occurred_at, event_id);
create index learning_events_user_uploaded
  on public.learning_events (user_id, uploaded_at);
create index devices_user_id on public.devices (user_id);
create index skill_snapshots_user_due on public.skill_snapshots (user_id, due_at);
create index confusion_edges_user_id on public.confusion_edges (user_id);

alter table public.profiles enable row level security;
alter table public.devices enable row level security;
alter table public.learning_events enable row level security;
alter table public.skill_snapshots enable row level security;
alter table public.confusion_edges enable row level security;
alter table public.user_settings enable row level security;
alter table public.sync_state enable row level security;

create policy profiles_owner_all on public.profiles
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy devices_owner_all on public.devices
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy learning_events_owner_select on public.learning_events
  for select to authenticated using (auth.uid() = user_id);
create policy learning_events_owner_insert on public.learning_events
  for insert to authenticated with check (auth.uid() = user_id);
create policy skill_snapshots_owner_all on public.skill_snapshots
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy confusion_edges_owner_all on public.confusion_edges
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy user_settings_owner_all on public.user_settings
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy sync_state_owner_all on public.sync_state
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

revoke all on public.profiles, public.devices, public.learning_events,
  public.skill_snapshots, public.confusion_edges, public.user_settings,
  public.sync_state from anon;
revoke all privileges on table public.learning_events from public, anon, authenticated;
grant select, insert on table public.learning_events to authenticated;
grant select, insert, update, delete on public.profiles, public.devices,
  public.skill_snapshots, public.confusion_edges, public.user_settings,
  public.sync_state to authenticated;
