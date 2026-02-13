begin;

alter table public.users
  add constraint users_contact_required
  check (email is not null or phone_number is not null) not valid;

update public.users u
set auth_id = matched.auth_id
from (
  select
    u2.id as user_id,
    coalesce(
      u2.auth_id,
      (
        select a.id
        from auth.users a
        where a.id = u2.id
           or (u2.email is not null and a.email = u2.email)
           or (u2.phone_number is not null and a.phone = u2.phone_number)
        order by
          case
            when a.id = u2.id then 0
            when u2.email is not null and a.email = u2.email then 1
            when u2.phone_number is not null and a.phone = u2.phone_number then 2
            else 3
          end
        limit 1
      )
    ) as auth_id
  from public.users u2
) matched
where u.id = matched.user_id
  and u.auth_id is null
  and matched.auth_id is not null;

update public.session_members sm
set user_id = u.auth_id
from public.users u
where sm.user_id = u.id
  and u.auth_id is not null
  and u.id <> u.auth_id;

update public.workout_sessions ws
set host_user_id = u.auth_id
from public.users u
where ws.host_user_id = u.id
  and u.auth_id is not null
  and u.id <> u.auth_id;

update public.user_devices ud
set user_id = u.auth_id
from public.users u
where ud.user_id = u.id
  and u.auth_id is not null
  and u.id <> u.auth_id;

update public.users
set id = auth_id
where auth_id is not null
  and id <> auth_id;

alter table public.users
  add constraint users_id_matches_auth_id
  check (id = auth_id) not valid;

create or replace function public.ensure_users_identity_consistency()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  resolved_auth_id uuid;
begin
  resolved_auth_id := new.auth_id;

  if resolved_auth_id is null then
    select a.id
    into resolved_auth_id
    from auth.users a
    where a.id = new.id
       or (new.email is not null and a.email = new.email)
       or (new.phone_number is not null and a.phone = new.phone_number)
    order by
      case
        when a.id = new.id then 0
        when new.email is not null and a.email = new.email then 1
        when new.phone_number is not null and a.phone = new.phone_number then 2
        else 3
      end
    limit 1;
  end if;

  if resolved_auth_id is not null then
    new.auth_id := resolved_auth_id;
    new.id := resolved_auth_id;
  end if;

  if new.email is null and new.phone_number is null then
    raise exception 'Either email or phone_number is required';
  end if;

  return new;
end;
$$;

drop trigger if exists users_ensure_identity_consistency on public.users;
create trigger users_ensure_identity_consistency
before insert or update on public.users
for each row
execute function public.ensure_users_identity_consistency();

alter table public.users validate constraint users_contact_required;
alter table public.users validate constraint users_id_matches_auth_id;

commit;
