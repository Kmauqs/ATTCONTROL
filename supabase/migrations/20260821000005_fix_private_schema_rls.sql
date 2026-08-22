-- Login failed after Auth succeeded: SELECT on profiles evaluates
-- public.is_staff() -> private.profile_rol(), and authenticated has
-- EXECUTE on the function but no USAGE on schema private (SQLSTATE 42501).
-- Resolve roles in public security-definer helpers so the client never
-- enters schema private.

revoke all on function private.profile_rol(uuid) from public;
revoke all on function private.profile_rol(uuid) from anon;
revoke all on function private.profile_rol(uuid) from authenticated;

create or replace function public.current_profile_rol()
returns public.user_rol
language sql
stable
security definer
set search_path = public
as $$
  select rol from public.profiles where id = auth.uid();
$$;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and rol in ('super_admin', 'supervisor')
  );
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and rol = 'super_admin'
  );
$$;

revoke all on function public.current_profile_rol() from public;
revoke all on function public.is_staff() from public;
revoke all on function public.is_super_admin() from public;

grant execute on function public.current_profile_rol() to authenticated;
grant execute on function public.is_staff() to authenticated;
grant execute on function public.is_super_admin() to authenticated;
