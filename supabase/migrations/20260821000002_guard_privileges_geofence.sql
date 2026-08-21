-- Prevent privilege escalation: own-row updates cannot change rol/activo/documento.
-- Only Super Admin may assign super_admin. Supervisors cannot change their own rol.

create or replace function private.guard_profile_privileges()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_rol public.user_rol;
begin
  actor_rol := private.profile_rol(auth.uid());

  if TG_OP = 'UPDATE' then
    if NEW.rol is distinct from OLD.rol
       or NEW.activo is distinct from OLD.activo
       or NEW.documento is distinct from OLD.documento then
      if auth.uid() = OLD.id then
        raise exception 'No puedes cambiar rol, documento ni estado de tu propio perfil';
      end if;
      if actor_rol is null or actor_rol not in ('super_admin', 'supervisor') then
        raise exception 'No autorizado a cambiar rol, documento o estado';
      end if;
      if NEW.rol is distinct from OLD.rol
         and NEW.rol = 'super_admin'
         and actor_rol is distinct from 'super_admin' then
        raise exception 'Solo Super Admin puede asignar ese rol';
      end if;
      if actor_rol = 'supervisor'
         and OLD.rol = 'super_admin'
         and NEW.rol is distinct from OLD.rol then
        raise exception 'Un supervisor no puede modificar un Super Admin';
      end if;
    end if;
  end if;

  if TG_OP = 'INSERT' then
    if NEW.rol = 'super_admin' and actor_rol is distinct from 'super_admin' then
      raise exception 'Solo Super Admin puede crear un Super Admin';
    end if;
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_guard_profile_privileges on public.profiles;
create trigger trg_guard_profile_privileges
  before insert or update on public.profiles
  for each row execute function private.guard_profile_privileges();

-- Reject attendance punches outside the assigned geofence (server-side).
create or replace function private.guard_attendance_geofence()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  site_lat double precision;
  site_lng double precision;
  site_radio integer;
  dist double precision;
begin
  select l.lat, l.lng, l.radio_metros
    into site_lat, site_lng, site_radio
  from public.profiles p
  left join public.locations l on l.id = coalesce(
    p.location_id,
    '11111111-1111-1111-1111-111111111111'::uuid
  )
  where p.id = NEW.empleado_id;

  if site_lat is null or site_lng is null or site_radio is null then
    raise exception 'No hay sitio asignado para fichar';
  end if;
  if NEW.lat is null or NEW.lng is null then
    raise exception 'GPS obligatorio para fichar';
  end if;

  dist := 6371000 * 2 * asin(sqrt(
    power(sin(radians((NEW.lat - site_lat) / 2)), 2) +
    cos(radians(site_lat)) * cos(radians(NEW.lat)) *
    power(sin(radians((NEW.lng - site_lng) / 2)), 2)
  ));

  if dist > site_radio then
    raise exception 'Fuera del sitio asignado (%.0f m)', dist;
  end if;

  NEW.dentro_geocerca := true;
  return NEW;
end;
$$;

drop trigger if exists trg_guard_attendance_geofence on public.attendance_logs;
create trigger trg_guard_attendance_geofence
  before insert or update on public.attendance_logs
  for each row execute function private.guard_attendance_geofence();
