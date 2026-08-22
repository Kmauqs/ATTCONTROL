import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/app_repository.dart';
import '../../attendance/domain/attendance_models.dart';
import '../../auth/presentation/auth_controller.dart';

class PunchMapScreen extends ConsumerStatefulWidget {
  const PunchMapScreen({super.key});

  @override
  ConsumerState<PunchMapScreen> createState() => _PunchMapScreenState();
}

class _PunchMapScreenState extends ConsumerState<PunchMapScreen> {
  final _map = MapController();
  List<AttendanceLog> _logs = [];
  Map<String, String> _names = {};
  bool _loading = true;
  int _days = 1;
  AttendanceLog? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final actor = ref.read(authControllerProvider).profile;
    if (actor == null || !actor.rol.isStaff) return;
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: _days - 1));
    final repo = ref.read(appRepositoryProvider);
    final logs = await repo.allLogs(from: from);
    final people = await repo.listPersonnel();
    if (!mounted) return;
    setState(() {
      _logs = logs
          .where((l) => l.kind == 'entrada' && l.lat != null && l.lng != null)
          .toList();
      _names = {for (final p in people) p.id: p.fullName};
      _loading = false;
      _selected = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  void _fit() {
    try {
      final points = [
        for (final l in _logs) LatLng(l.lat!, l.lng!),
      ];
      if (points.isEmpty) return;
      if (points.length == 1) {
        _map.move(points.first, 16);
        return;
      }
      _map.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(48),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    const bogota = LatLng(4.60971, -74.08175);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Hoy'),
                selected: _days == 1,
                onSelected: (_) {
                  setState(() {
                    _days = 1;
                    _loading = true;
                  });
                  _load();
                },
              ),
              ChoiceChip(
                label: const Text('7 días'),
                selected: _days == 7,
                onSelected: (_) {
                  setState(() {
                    _days = 7;
                    _loading = true;
                  });
                  _load();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _logs.isEmpty
                  ? bogota
                  : LatLng(_logs.first.lat!, _logs.first.lng!),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.attcontrol.attcontrol',
                maxNativeZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  for (final log in _logs)
                    Marker(
                      point: LatLng(log.lat!, log.lng!),
                      width: 36,
                      height: 36,
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = log),
                        child: Icon(
                          Icons.location_on,
                          color: log == _selected
                              ? AppColors.late
                              : AppColors.forest,
                          size: 36,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_selected != null)
          Material(
            elevation: 8,
            child: ListTile(
              leading: const Icon(Icons.fingerprint, color: AppColors.forest),
              title: Text(_names[_selected!.empleadoId] ?? 'Personal'),
              subtitle: Text(
                'Entrada · ${DateFormat('d MMM HH:mm', 'es').format(_selected!.markedAt)}',
              ),
              trailing: IconButton(
                onPressed: () => setState(() => _selected = null),
                icon: const Icon(Icons.close),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _logs.isEmpty
                  ? 'No hay ingresos con GPS en este periodo.'
                  : '${_logs.length} ingresos con ubicación',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
      ],
    );
  }
}
