begin;

create extension if not exists pgtap with schema extensions;
select plan(27);

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', 'a@example.test', '', now(), now(), now()),
  ('22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated', 'b@example.test', '', now(), now(), now());

insert into public.profiles (user_id, display_name) values
  ('11111111-1111-4111-8111-111111111111', 'A'),
  ('22222222-2222-4222-8222-222222222222', 'B');
insert into public.devices (device_id, user_id) values
  ('device-a', '11111111-1111-4111-8111-111111111111'),
  ('device-b', '22222222-2222-4222-8222-222222222222');
insert into public.learning_events (event_id, user_id, device_id, item_id, skill, occurred_at, correct, latency_ms, hint_count, retry_count)
values
  ('event-a', '11111111-1111-4111-8111-111111111111', 'device-a', 'ㄅ', 'recognition', now(), true, 400, 0, 0),
  ('event-b', '22222222-2222-4222-8222-222222222222', 'device-b', 'ㄆ', 'recognition', now(), true, 450, 0, 0);
insert into public.skill_snapshots (user_id, item_id, skill, stability, difficulty, due_at)
values ('11111111-1111-4111-8111-111111111111', 'ㄅ', 'recognition', 1, 5, now()),
       ('22222222-2222-4222-8222-222222222222', 'ㄆ', 'recognition', 1, 5, now());
insert into public.confusion_edges (user_id, expected, response, exposure_count, error_count)
values ('11111111-1111-4111-8111-111111111111', 'ㄅ', 'ㄆ', 1, 1),
       ('22222222-2222-4222-8222-222222222222', 'ㄆ', 'ㄅ', 1, 1);
insert into public.user_settings (user_id, key, value)
values ('11111111-1111-4111-8111-111111111111', 'theme', 'dark'),
       ('22222222-2222-4222-8222-222222222222', 'theme', 'light');
insert into public.sync_state (user_id, key, value)
values ('11111111-1111-4111-8111-111111111111', 'events', ''),
       ('22222222-2222-4222-8222-222222222222', 'events', '');

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select ok(has_table_privilege('authenticated', 'public.learning_events', 'SELECT'), 'authenticated can select events');
select ok(has_table_privilege('authenticated', 'public.learning_events', 'INSERT'), 'authenticated can insert events');
select ok(
  not has_table_privilege('authenticated', 'public.learning_events', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.learning_events', 'DELETE')
  and not has_table_privilege('authenticated', 'public.learning_events', 'TRUNCATE')
  and not has_table_privilege('authenticated', 'public.learning_events', 'REFERENCES')
  and not has_table_privilege('authenticated', 'public.learning_events', 'TRIGGER'),
  'authenticated has no update, delete, or administrative privileges on events'
);
select ok(
  not has_table_privilege('anon', 'public.learning_events', 'SELECT')
  and not has_table_privilege('anon', 'public.learning_events', 'INSERT')
  and not has_table_privilege('anon', 'public.learning_events', 'UPDATE')
  and not has_table_privilege('anon', 'public.learning_events', 'DELETE')
  and not has_table_privilege('anon', 'public.learning_events', 'TRUNCATE')
  and not has_table_privilege('anon', 'public.learning_events', 'REFERENCES')
  and not has_table_privilege('anon', 'public.learning_events', 'TRIGGER'),
  'anon has no event table privileges'
);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);

select is((select count(*)::int from public.profiles), 1, 'A sees only A profile');
select is((select count(*)::int from public.devices), 1, 'A sees only A device');
select is((select count(*)::int from public.learning_events), 1, 'A sees only A events');
select is((select count(*)::int from public.skill_snapshots), 1, 'A sees only A snapshots');
select is((select count(*)::int from public.confusion_edges), 1, 'A sees only A confusion edges');
select is((select count(*)::int from public.user_settings), 1, 'A sees only A settings');
select is((select count(*)::int from public.sync_state), 1, 'A sees only A sync state');
select lives_ok($$insert into public.user_settings (user_id, key, value) values ('11111111-1111-4111-8111-111111111111', 'font_scale', 'large')$$, 'A inserts own row');
select throws_ok($$insert into public.user_settings (user_id, key, value) values ('22222222-2222-4222-8222-222222222222', 'stolen', 'yes')$$, '42501', null, 'A cannot insert for B');
select lives_ok($$insert into public.learning_events (event_id, user_id, device_id, item_id, skill, occurred_at, correct, latency_ms, hint_count, retry_count) values ('event-c', '11111111-1111-4111-8111-111111111111', 'device-a', 'a', 'recognition', now(), true, 400, 0, 0)$$, 'A inserts own learning event');
select throws_ok($$insert into public.learning_events (event_id, user_id, device_id, item_id, skill, occurred_at, correct, latency_ms, hint_count, retry_count) values ('event-d', '22222222-2222-4222-8222-222222222222', 'device-b', 'b', 'recognition', now(), true, 450, 0, 0)$$, '42501', null, 'A cannot insert event for B');
select throws_ok($$update public.learning_events set item_id = 'stolen' where event_id = 'event-b'$$, '42501', null, 'A cannot update B row');
select throws_ok($$update public.learning_events set user_id = '22222222-2222-4222-8222-222222222222' where event_id = 'event-a'$$, '42501', null, 'A cannot transfer own row to B');
select throws_ok($$delete from public.learning_events where event_id = 'event-b'$$, '42501', null, 'A cannot delete B row');
select throws_ok($$update public.learning_events set item_id = 'edited' where event_id = 'event-a'$$, '42501', null, 'A cannot mutate own event');
select throws_ok($$delete from public.learning_events where event_id = 'event-a'$$, '42501', null, 'A cannot delete own event');
select is((select count(*)::int from public.learning_events where event_id = 'event-a'), 1, 'A can still read own event');
select is((select count(*)::int from public.user_settings where key = 'font_scale'), 1, 'A can read inserted own setting');
select lives_ok($$update public.profiles set display_name = 'A updated' where user_id = '11111111-1111-4111-8111-111111111111'$$, 'A updates own profile');
select is((select count(*)::int from public.user_settings where user_id = '22222222-2222-4222-8222-222222222222'), 0, 'A cannot see B settings');
select lives_ok('select public.delete_own_account()', 'A can delete the authenticated account');

reset role;
select ok(
  not exists (select 1 from auth.users where id = '11111111-1111-4111-8111-111111111111')
  and exists (select 1 from auth.users where id = '22222222-2222-4222-8222-222222222222'),
  'deletion removes A but does not affect B'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claims', '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}', true);
select is((select count(*)::int from public.learning_events), 1, 'B independently sees only B events');

select * from finish();
rollback;
