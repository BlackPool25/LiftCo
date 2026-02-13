-- Keep RLS enabled and add explicit, least-privilege row access for app UUID model

alter table if exists public.users enable row level security;
alter table if exists public.user_devices enable row level security;
alter table if exists public.session_members enable row level security;

-- Helper to map auth user -> app user UUID (public.users.id)
create or replace function public.current_app_user_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select u.id
  from public.users u
  where u.auth_id = auth.uid()
  limit 1;
$$;

revoke all on function public.current_app_user_id() from public;
grant execute on function public.current_app_user_id() to authenticated;

-- Users table policies
-- 1) user can always read their own profile row
DROP POLICY IF EXISTS users_select_self_profile ON public.users;
create policy users_select_self_profile
on public.users
for select
to authenticated
using (
  id = public.current_app_user_id()
);

-- 2) user can read rows for people who are joined in the same joined session
-- This enables session host/member name+age display without disabling RLS.
DROP POLICY IF EXISTS users_select_same_joined_session_member ON public.users;
create policy users_select_same_joined_session_member
on public.users
for select
to authenticated
using (
  exists (
    select 1
    from public.session_members mine
    join public.session_members theirs
      on mine.session_id = theirs.session_id
    where mine.user_id = public.current_app_user_id()
      and mine.status = 'joined'
      and theirs.user_id = users.id
      and theirs.status = 'joined'
  )
);

-- user_devices policies: users can only manage their own device rows
DROP POLICY IF EXISTS user_devices_select_own ON public.user_devices;
create policy user_devices_select_own
on public.user_devices
for select
to authenticated
using (
  user_id = public.current_app_user_id()
);

DROP POLICY IF EXISTS user_devices_insert_own ON public.user_devices;
create policy user_devices_insert_own
on public.user_devices
for insert
to authenticated
with check (
  user_id = public.current_app_user_id()
);

DROP POLICY IF EXISTS user_devices_update_own ON public.user_devices;
create policy user_devices_update_own
on public.user_devices
for update
to authenticated
using (
  user_id = public.current_app_user_id()
)
with check (
  user_id = public.current_app_user_id()
);

DROP POLICY IF EXISTS user_devices_delete_own ON public.user_devices;
create policy user_devices_delete_own
on public.user_devices
for delete
to authenticated
using (
  user_id = public.current_app_user_id()
);

-- session_members visibility for session screens (non-recursive policy)
-- Allow reading joined members for sessions that are visible in workout_sessions.
DROP POLICY IF EXISTS session_members_select_visible_sessions ON public.session_members;
create policy session_members_select_visible_sessions
on public.session_members
for select
to authenticated
using (
  status = 'joined'
  and exists (
    select 1
    from public.workout_sessions ws
    where ws.id = session_members.session_id
  )
);
