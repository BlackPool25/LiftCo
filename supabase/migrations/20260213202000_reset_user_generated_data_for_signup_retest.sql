begin;

-- User-generated runtime data only (preserve reference/config data like gyms)
delete from public.user_devices;
delete from public.session_members;
delete from public.workout_sessions;
delete from public.users;

-- Clear auth users so signup can be tested from a true blank state
-- (auth identities/sessions/tokens are removed via auth schema relations)
delete from auth.users;

commit;
