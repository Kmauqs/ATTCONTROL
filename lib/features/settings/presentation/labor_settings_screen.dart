import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/app_repository.dart';
import 'catalog_section.dart';

class LaborSettingsScreen extends ConsumerStatefulWidget {
  const LaborSettingsScreen({super.key});

  @override
  ConsumerState<LaborSettingsScreen> createState() =>
      _LaborSettingsScreenState();
}

class _LaborSettingsScreenState extends ConsumerState<LaborSettingsScreen> {
  LaborSettings _s = const LaborSettings();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ref.read(appRepositoryProvider).laborSettings();
    if (mounted) {
      setState(() {
        _s = s;
        _loaded = true;
      });
    }
  }

  Future<void> _save() async {
    await ref.read(appRepositoryProvider).saveLaborSettings(_s);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calendario laboral guardado')),
      );
    }
  }

  Future<void> _pick(String which) async {
    final current = switch (which) {
      'in' => _s.horaEntrada,
      'out' => _s.horaSalida,
      'sin' => _s.horaEntradaSabado,
      _ => _s.horaSalidaSabado,
    };
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (picked == null) return;
    final v =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      _s = LaborSettings(
        periodoCorte: _s.periodoCorte,
        horaEntrada: which == 'in' ? v : _s.horaEntrada,
        horaSalida: which == 'out' ? v : _s.horaSalida,
        horaEntradaSabado: which == 'sin' ? v : _s.horaEntradaSabado,
        horaSalidaSabado: which == 'sout' ? v : _s.horaSalidaSabado,
        extraDiurna: _s.extraDiurna,
        extraNocturna: _s.extraNocturna,
        recargoNocturno: _s.recargoNocturno,
        dominicalOrdinario: _s.dominicalOrdinario,
        extraDiurnaFestivo: _s.extraDiurnaFestivo,
        extraNocturnaFestivo: _s.extraNocturnaFestivo,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Calendario y recargos (Colombia)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _s.periodoCorte,
          decoration:
              const InputDecoration(labelText: 'Periodo de corte salarial'),
          items: const [
            DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
            DropdownMenuItem(value: 'quincenal', child: Text('Quincenal')),
            DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
          ],
          onChanged: (v) => setState(() {
            _s = LaborSettings(
              periodoCorte: v ?? _s.periodoCorte,
              horaEntrada: _s.horaEntrada,
              horaSalida: _s.horaSalida,
              horaEntradaSabado: _s.horaEntradaSabado,
              horaSalidaSabado: _s.horaSalidaSabado,
              extraDiurna: _s.extraDiurna,
              extraNocturna: _s.extraNocturna,
              recargoNocturno: _s.recargoNocturno,
              dominicalOrdinario: _s.dominicalOrdinario,
              extraDiurnaFestivo: _s.extraDiurnaFestivo,
              extraNocturnaFestivo: _s.extraNocturnaFestivo,
            );
          }),
        ),
        ListTile(
          title: const Text('Entrada lun-vie'),
          trailing: Text(_s.horaEntrada),
          onTap: () => _pick('in'),
        ),
        ListTile(
          title: const Text('Salida lun-vie'),
          trailing: Text(_s.horaSalida),
          onTap: () => _pick('out'),
        ),
        ListTile(
          title: const Text('Entrada sábado'),
          trailing: Text(_s.horaEntradaSabado),
          onTap: () => _pick('sin'),
        ),
        ListTile(
          title: const Text('Salida sábado'),
          trailing: Text(_s.horaSalidaSabado),
          onTap: () => _pick('sout'),
        ),
        const Divider(height: 32),
        const Text('Jornada diurna 6:00 – 19:00 · nocturna 19:00 – 6:00'),
        _pct('Hora extra diurna', _s.extraDiurna),
        _pct('Hora extra nocturna', _s.extraNocturna),
        _pct('Recargo nocturno', _s.recargoNocturno),
        _pct('Dominical/festivo', _s.dominicalOrdinario),
        _pct('Extra diurna festivo', _s.extraDiurnaFestivo),
        _pct('Extra nocturna festivo', _s.extraNocturnaFestivo),
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: const Text('Guardar ajustes')),
        const Divider(height: 40),
        Card(
          child: ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Localizaciones'),
            subtitle: const Text('Oficinas y proyectos con GPS'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/sites'),
          ),
        ),
        const SizedBox(height: 20),
        CatalogSection(
          title: 'Cuadrillas',
          hint: 'Equipos de trabajo que se asignan a una localización.',
          table: 'cuadrillas',
          repo: ref.read(appRepositoryProvider),
        ),
        const SizedBox(height: 20),
        CatalogSection(
          title: 'Departamentos',
          hint: 'Áreas de la empresa para organizar el personal.',
          table: 'departamentos',
          repo: ref.read(appRepositoryProvider),
        ),
        const SizedBox(height: 12),
        const Text(
          'Festivos de Colombia 2026 están precargados para el cálculo de recargos.',
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }

  Widget _pct(String label, double v) {
    return ListTile(
      title: Text(label),
      subtitle: Text('${(v * 100).toStringAsFixed(0)}% recargo'),
      trailing: const Icon(Icons.percent, color: AppColors.forest),
    );
  }
}
