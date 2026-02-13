begin;

update public.users u
set auth_id = a.id
from auth.users a
where u.auth_id is null
  and (
    (u.email is not null and a.email is not null and lower(a.email) = lower(u.email))
    or (u.phone_number is not null and a.phone = u.phone_number)
  );

create unique index if not exists users_auth_id_unique_idx
  on public.users(auth_id)
  where auth_id is not null;

alter table public.users
  drop constraint if exists users_email_or_phone_required;

alter table public.users
  add constraint users_email_or_phone_required
  check (email is not null or phone_number is not null);

alter table public.users
  drop constraint if exists users_auth_id_required;

alter table public.users
  add constraint users_auth_id_required
  check (auth_id is not null)
  not valid;

create unique index if not exists user_devices_user_token_unique_idx
  on public.user_devices(user_id, fcm_token);

commit;
