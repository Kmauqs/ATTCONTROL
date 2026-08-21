-- Service role / SQL editor (auth.uid() is null) must still seed and create users.

create or replace function private.guard_profile_privileges()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_rol public.user_rol;
begin
  if auth.uid() is null then
    return NEW;
  end if;
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
