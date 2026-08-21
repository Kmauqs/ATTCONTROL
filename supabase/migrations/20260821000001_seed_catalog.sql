-- Default shift, site, Colombia holidays 2026-2027, labor settings (Ley vigente según prompt).

insert into public.locations (id, nombre, proyecto, cuadrilla, lat, lng, radio_metros)
values (
  '11111111-1111-1111-1111-111111111111',
  'Obra principal',
  'ATTCONTROL',
  'Cuadrilla 1',
  4.60971,
  -74.08175,
  250
) on conflict (id) do nothing;

insert into public.shifts (id, nombre)
values ('22222222-2222-2222-2222-222222222222', 'Jornada estándar CO')
on conflict (id) do nothing;

insert into public.labor_settings (
  id, periodo_corte, extra_diurna, extra_nocturna, recargo_nocturno,
  dominical_ordinario, extra_diurna_festivo, extra_nocturna_festivo
) values (
  '33333333-3333-3333-3333-333333333333',
  'quincenal', 0.25, 0.75, 0.35, 0.90, 1.05, 1.55
) on conflict (id) do nothing;

insert into public.holidays (fecha, nombre) values
  ('2026-01-01', 'Año Nuevo'),
  ('2026-01-12', 'Reyes Magos'),
  ('2026-03-23', 'San José'),
  ('2026-04-02', 'Jueves Santo'),
  ('2026-04-03', 'Viernes Santo'),
  ('2026-05-01', 'Día del Trabajo'),
  ('2026-05-18', 'Ascensión del Señor'),
  ('2026-06-08', 'Corpus Christi'),
  ('2026-06-15', 'Sagrado Corazón'),
  ('2026-06-29', 'San Pedro y San Pablo'),
  ('2026-07-20', 'Independencia de Colombia'),
  ('2026-08-07', 'Batalla de Boyacá'),
  ('2026-08-17', 'Asunción de la Virgen'),
  ('2026-10-12', 'Día de la Raza'),
  ('2026-11-02', 'Todos los Santos'),
  ('2026-11-16', 'Independencia de Cartagena'),
  ('2026-12-08', 'Inmaculada Concepción'),
  ('2026-12-25', 'Navidad'),
  ('2027-01-01', 'Año Nuevo'),
  ('2027-01-11', 'Reyes Magos'),
  ('2027-03-22', 'San José'),
  ('2027-03-25', 'Jueves Santo'),
  ('2027-03-26', 'Viernes Santo'),
  ('2027-05-01', 'Día del Trabajo'),
  ('2027-05-17', 'Ascensión del Señor'),
  ('2027-06-07', 'Corpus Christi'),
  ('2027-06-14', 'Sagrado Corazón'),
  ('2027-07-05', 'San Pedro y San Pablo'),
  ('2027-07-20', 'Independencia de Colombia'),
  ('2027-08-07', 'Batalla de Boyacá'),
  ('2027-08-16', 'Asunción de la Virgen'),
  ('2027-10-18', 'Día de la Raza'),
  ('2027-11-01', 'Todos los Santos'),
  ('2027-11-15', 'Independencia de Cartagena'),
  ('2027-12-08', 'Inmaculada Concepción'),
  ('2027-12-25', 'Navidad')
on conflict (fecha) do nothing;
