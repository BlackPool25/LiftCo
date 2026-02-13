begin;

alter table if exists public.users enable row level security;

-- Hard reset ALL users policies to remove any hidden/legacy recursive policy names
DO $$
DECLARE
  policy_record record;
BEGIN
  FOR policy_record IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'users'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.users', policy_record.policyname);
  END LOOP;
END $$;

-- Recreate minimal non-recursive policies
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
