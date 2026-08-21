-- Multiple authorized work sites, staff skip geofence, photo + digital ID card.

alter table public.locations
  add column if not exists tipo text not null default 'oficina';

alter table public.locations
  drop constraint if exists locations_tipo_check;

alter table public.locations
  add constraint locations_tipo_check check (tipo in ('oficina', 'proyecto'));

update public.locations
set tipo = 'proyecto'
where nombre ilike '%obra%';

alter table public.profiles
  add column if not exists foto_path text,
  add column if not exists carnet_path text;

create or replace function private.guard_attendance_geofence()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_rol public.user_rol;
  inside boolean := false;
  rec record;
  dist double precision;
begin
  select p.rol into target_rol
  from public.profiles p
  where p.id = NEW.empleado_id;

  if target_rol in ('super_admin', 'supervisor') then
    NEW.dentro_geocerca := true;
    return NEW;
  end if;

  if NEW.lat is null or NEW.lng is null then
    raise exception 'GPS obligatorio para fichar';
  end if;

  for rec in
    select lat, lng, radio_metros
    from public.locations
    where activo is distinct from false
  loop
    dist := 6371000 * 2 * asin(sqrt(
      power(sin(radians((NEW.lat - rec.lat) / 2)), 2) +
      cos(radians(rec.lat)) * cos(radians(NEW.lat)) *
      power(sin(radians((NEW.lng - rec.lng) / 2)), 2)
    ));
    if dist <= rec.radio_metros then
      inside := true;
      exit;
    end if;
  end loop;

  if not inside then
    raise exception 'Fuera de los sitios autorizados';
  end if;

  NEW.dentro_geocerca := true;
  return NEW;
end;
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'personnel-files',
  'personnel-files',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do nothing;

drop policy if exists personnel_files_select on storage.objects;
drop policy if exists personnel_files_insert on storage.objects;
drop policy if exists personnel_files_update on storage.objects;
drop policy if exists personnel_files_delete on storage.objects;

create policy personnel_files_select
on storage.objects for select to authenticated
using (
  bucket_id = 'personnel-files'
  and (
    public.is_staff()
    or split_part(name, '/', 1) = auth.uid()::text
  )
);

create policy personnel_files_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'personnel-files'
  and public.is_staff()
);

create policy personnel_files_update
on storage.objects for update to authenticated
using (bucket_id = 'personnel-files' and public.is_staff())
with check (bucket_id = 'personnel-files' and public.is_staff());

create policy personnel_files_delete
on storage.objects for delete to authenticated
using (bucket_id = 'personnel-files' and public.is_staff());
