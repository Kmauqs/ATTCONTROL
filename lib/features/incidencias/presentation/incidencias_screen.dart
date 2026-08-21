import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/app_repository.dart';
import '../../attendance/domain/attendance_models.dart';
import '../../auth/presentation/auth_controller.dart';

class IncidenciasScreen extends ConsumerStatefulWidget {
  const IncidenciasScreen({super.key});

  @override
  ConsumerState<IncidenciasScreen> createState() => _IncidenciasScreenState();
}

class _IncidenciasScreenState extends ConsumerState<IncidenciasScreen> {
  List<Incidencia> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) return;
    final items = await ref.read(appRepositoryProvider).incidencias(
          empleadoId: profile.rol.isStaff ? null : profile.id,
        );
    if (mounted) setState(() => _items = items);
  }

  Future<void> _create() async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null || !profile.rol.canRequestLeave) return;
    final tipo = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in ['permiso', 'vacaciones', 'enfermedad', 'justificado'])
            ListTile(
              title: Text(t),
              onTap: () => Navigator.pop(context, t),
            ),
        ],
      ),
    );
    if (tipo == null || !mounted) return;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (range == null) return;
    await ref.read(appRepositoryProvider).createIncidencia(
          Incidencia(
            id: const Uuid().v4(),
            empleadoId: profile.id,
            tipo: tipo,
            fechaInicio: range.start,
            fechaFin: range.end,
            estado: 'pendiente',
          ),
        );
    await _load();
  }

  Color _color(String estado) => switch (estado) {
        'aprobado' => AppColors.ok,
        'rechazado' => AppColors.late,
        'cumplido' => Colors.blueGrey,
        _ => Colors.orange,
      };

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    final canCreate = profile?.rol.canRequestLeave ?? false;
    return Scaffold(
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _create,
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Solicitar'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          itemCount: _items.length,
          itemBuilder: (context, i) {
            final item = _items[i];
            return Card(
              child: ListTile(
                title: Text(
                  '${item.tipo} · ${item.empleadoNombre ?? ''}',
                ),
                subtitle: Text(
                  '${DateFormat('dd/MM/yyyy').format(item.fechaInicio)} – ${DateFormat('dd/MM/yyyy').format(item.fechaFin)}\n${item.comentario ?? ''}',
                ),
                isThreeLine: true,
                trailing: Chip(
                  label: Text(item.estado),
                  backgroundColor: _color(item.estado).withValues(alpha: 0.15),
                ),
                onTap: profile?.rol.isStaff == true
                    ? () async {
                        final next = await showModalBottomSheet<String>(
                          context: context,
                          builder: (context) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final e in [
                                'aprobado',
                                'rechazado',
                                'cumplido',
                                'pendiente',
                              ])
                                ListTile(
                                  title: Text('Marcar $e'),
                                  onTap: () => Navigator.pop(context, e),
                                ),
                            ],
                          ),
                        );
                        if (next != null) {
                          await ref
                              .read(appRepositoryProvider)
                              .setIncidenciaEstado(item.id, next);
                          await _load();
                        }
                      }
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}
