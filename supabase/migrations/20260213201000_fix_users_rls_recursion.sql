begin;

alter table if exists public.users enable row level security;

-- Remove recursive/legacy policies that can recurse via users lookups

drop policy if exists users_select_same_joined_session_member on public.users;
drop policy if exists users_select_self_profile on public.users;
drop policy if exists users_select_own on public.users;
drop policy if exists users_insert_own on public.users;
drop policy if exists users_update_own on public.users;

-- Non-recursive, deterministic policies based on auth_id
create policy users_select_self_profile
on public.users
for select
to authenticated
using (auth.uid() = auth_id);

create policy users_insert_self_profile
on public.users
for insert
to authenticated
with check (auth.uid() = auth_id);

create policy users_update_self_profile
on public.users
for update
to authenticated
using (auth.uid() = auth_id)
with check (auth.uid() = auth_id);

commit;
