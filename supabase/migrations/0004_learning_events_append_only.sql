-- Supabase's default table grants may include UPDATE, DELETE, and TRUNCATE.
-- Revoke them for existing installations that already applied 0002.
revoke all privileges on table public.learning_events from public, anon, authenticated;
grant select, insert on table public.learning_events to authenticated;
