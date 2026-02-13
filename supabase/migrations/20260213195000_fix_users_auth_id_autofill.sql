begin;

update public.users u
set auth_id = a.id
from auth.users a
where u.auth_id is null
  and (
    u.id = a.id
    or (u.email is not null and a.email is not null and lower(u.email) = lower(a.email))
    or (u.phone_number is not null and a.phone is not null and u.phone_number = a.phone)
  );

create or replace function public.ensure_users_auth_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.auth_id is null then
    new.auth_id := auth.uid();
  end if;

  if new.auth_id is null and new.id is not null then
    if exists (
      select 1
      from auth.users a
      where a.id = new.id
    ) then
      new.auth_id := new.id;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists users_set_auth_id_before_write on public.users;
create trigger users_set_auth_id_before_write
before insert or update of auth_id, id
on public.users
for each row
execute function public.ensure_users_auth_id();

commit;
