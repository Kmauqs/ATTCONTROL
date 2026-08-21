-- ATTCONTROL schema: profiles, locations, shifts, attendance, incidencias, labor settings.
-- Apply with: npx supabase db push  (after linking a project) or paste in SQL Editor.

create extension if not exists "pgcrypto";

do $$ begin
  create type public.user_rol as enum (
    'super_admin', 'supervisor', 'empleado', 'asesor', 'contratista'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.attendance_kind as enum ('entrada', 'salida');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.attendance_source as enum ('app', 'qr', 'manual', 'biometric');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.attendance_status as enum (
    'a_tiempo', 'tarde', 'salida_temprana', 'fuera_sitio', 'offline_pendiente'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.incidencia_tipo as enum (
    'permiso', 'vacaciones', 'enfermedad', 'justificado', 'horas_extras'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.incidencia_estado as enum (
    'pendiente', 'aprobado', 'rechazado', 'cumplido'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.periodo_corte as enum ('semanal', 'quincenal', 'mensual');
exception when duplicate_object then null;
end $$;

create table if not exists public.departamentos (
  id uuid primary key default gen_random_uuid(),
  nombre text not null unique
);

create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  proyecto text,
  cuadrilla text,
  lat double precision not null default 4.60971,
  lng double precision not null default -74.08175,
  radio_metros integer not null default 250,
  activo boolean not null default true
);

create table if not exists public.shifts (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  hora_entrada time not null default '07:00',
  hora_salida time not null default '17:00',
  hora_entrada_sabado time not null default '08:00',
  hora_salida_sabado time not null default '12:00'
);

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  documento text not null unique,
  nombre text not null,
  apellido text not null,
  cargo text,
  correo text,
  rh text,
  eps text,
  arl text,
  rol public.user_rol not null default 'empleado',
  departamento_id uuid references public.departamentos (id),
  location_id uuid references public.locations (id),
  shift_id uuid references public.shifts (id),
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.attendance_logs (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null unique,
  empleado_id uuid not null references public.profiles (id) on delete cascade,
  kind public.attendance_kind not null,
  marked_at timestamptz not null default now(),
  lat double precision,
  lng double precision,
  source public.attendance_source not null default 'app',
  status public.attendance_status not null default 'a_tiempo',
  dentro_geocerca boolean not null default true,
  notas text,
  created_at timestamptz not null default now()
);

create index if not exists attendance_logs_empleado_marked_idx
  on public.attendance_logs (empleado_id, marked_at desc);

create table if not exists public.incidencias (
  id uuid primary key default gen_random_uuid(),
  empleado_id uuid not null references public.profiles (id) on delete cascade,
  tipo public.incidencia_tipo not null,
  fecha_inicio date not null,
  fecha_fin date not null,
  comentario text,
  estado public.incidencia_estado not null default 'pendiente',
  revisado_por uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.labor_settings (
  id uuid primary key default gen_random_uuid(),
  periodo_corte public.periodo_corte not null default 'quincenal',
  hora_entrada time not null default '07:00',
  hora_salida time not null default '17:00',
  hora_entrada_sabado time not null default '08:00',
  hora_salida_sabado time not null default '12:00',
  jornada_diurna_inicio time not null default '06:00',
  jornada_diurna_fin time not null default '19:00',
  extra_diurna numeric not null default 0.25,
  extra_nocturna numeric not null default 0.75,
  recargo_nocturno numeric not null default 0.35,
  dominical_ordinario numeric not null default 0.90,
  extra_diurna_festivo numeric not null default 1.05,
  extra_nocturna_festivo numeric not null default 1.55,
  updated_at timestamptz not null default now()
);

create table if not exists public.holidays (
  id uuid primary key default gen_random_uuid(),
  fecha date not null unique,
  nombre text not null
);

create schema if not exists private;

create or replace function private.profile_rol(uid uuid)
returns public.user_rol
language sql
stable
security definer
set search_path = public
as $$
  select rol from public.profiles where id = uid;
$$;

revoke all on function private.profile_rol(uuid) from public;
grant execute on function private.profile_rol(uuid) to authenticated;

create or replace function public.current_profile_rol()
returns public.user_rol
language sql
stable
set search_path = public
as $$
  select private.profile_rol(auth.uid());
$$;

create or replace function public.is_staff()
returns boolean
language sql
stable
set search_path = public
as $$
  select public.current_profile_rol() in ('super_admin', 'supervisor');
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
set search_path = public
as $$
  select public.current_profile_rol() = 'super_admin';
$$;

alter table public.departamentos enable row level security;
alter table public.locations enable row level security;
alter table public.shifts enable row level security;
alter table public.profiles enable row level security;
alter table public.attendance_logs enable row level security;
alter table public.incidencias enable row level security;
alter table public.labor_settings enable row level security;
alter table public.holidays enable row level security;

-- profiles
create policy profiles_select_own_or_staff on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_staff());

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy profiles_staff_write on public.profiles
  for all to authenticated
  using (public.is_staff())
  with check (public.is_staff());

-- locations / shifts / departamentos: readable by authenticated, writable by staff
create policy locations_read on public.locations for select to authenticated using (true);
create policy locations_staff on public.locations for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy shifts_read on public.shifts for select to authenticated using (true);
create policy shifts_staff on public.shifts for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy dept_read on public.departamentos for select to authenticated using (true);
create policy dept_staff on public.departamentos for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

-- attendance
create policy attendance_select on public.attendance_logs
  for select to authenticated
  using (empleado_id = auth.uid() or public.is_staff());

create policy attendance_insert_own on public.attendance_logs
  for insert to authenticated
  with check (empleado_id = auth.uid() or public.is_staff());

create policy attendance_staff_update on public.attendance_logs
  for update to authenticated
  using (public.is_staff())
  with check (public.is_staff());

-- incidencias: empleado creates own; staff sees all and updates status
create policy incidencias_select on public.incidencias
  for select to authenticated
  using (empleado_id = auth.uid() or public.is_staff());

create policy incidencias_insert_own on public.incidencias
  for insert to authenticated
  with check (
    empleado_id = auth.uid()
    and public.current_profile_rol() = 'empleado'
  );

create policy incidencias_staff_update on public.incidencias
  for update to authenticated
  using (public.is_staff())
  with check (public.is_staff());

-- labor settings / holidays
create policy labor_read on public.labor_settings for select to authenticated using (true);
create policy labor_admin on public.labor_settings for all to authenticated
  using (public.is_super_admin()) with check (public.is_super_admin());

create policy holidays_read on public.holidays for select to authenticated using (true);
create policy holidays_admin on public.holidays for all to authenticated
  using (public.is_super_admin()) with check (public.is_super_admin());

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
revoke all on all tables in schema public from anon;

do $$ begin
  alter publication supabase_realtime add table public.attendance_logs;
exception when duplicate_object then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.profiles;
exception when duplicate_object then null;
end $$;
