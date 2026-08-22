-- Catalogs for crews and richer work-site records.

create table if not exists public.cuadrillas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null unique,
  activo boolean not null default true
);

alter table public.cuadrillas enable row level security;

drop policy if exists cuadrillas_read on public.cuadrillas;
drop policy if exists cuadrillas_staff on public.cuadrillas;

create policy cuadrillas_read on public.cuadrillas
  for select to authenticated using (true);

create policy cuadrillas_staff on public.cuadrillas
  for all to authenticated
  using (public.is_staff())
  with check (public.is_staff());

alter table public.locations
  add column if not exists direccion text,
  add column if not exists cliente text,
  add column if not exists contrato text;
