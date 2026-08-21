import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/labor_calc.dart';
import '../../../data/app_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/attendance_models.dart';

class HoursScreen extends ConsumerWidget {
  const HoursScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    if (profile == null) return const SizedBox.shrink();
    return FutureBuilder<_HoursData>(
      future: _load(ref),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              data.period.label,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Corte ${data.corte}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ...data.breakdown.asMap().entries.map(
              (e) => Card(
                child: ListTile(
                  title: Text(e.key),
                  trailing: Text(
                    '${e.value.toStringAsFixed(2)} h',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Marcas del periodo',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            ...data.logs.map(
              (l) => ListTile(
                leading: Icon(
                  l.kind == 'entrada' ? Icons.login : Icons.logout,
                  color: AppColors.forest,
                ),
                title: Text('${l.kind} · ${l.status.replaceAll('_', ' ')}'),
                subtitle:
                    Text(DateFormat('dd/MM/yyyy HH:mm').format(l.markedAt)),
                trailing: Icon(
                  l.synced ? Icons.cloud_done : Icons.cloud_off,
                  size: 18,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<_HoursData> _load(WidgetRef ref) async {
    final profile = ref.read(authControllerProvider).profile!;
    final repo = ref.read(appRepositoryProvider);
    final settings = await repo.laborSettings();
    final period = LaborCalc.periodFor(DateTime.now(), settings.periodoCorte);
    final logs = await repo.logsFor(
      profile.id,
      from: period.start,
      to: period.end,
    );
    final holidays = await repo.holidays();
    final breakdown = HourBreakdown();
    final chronological = [...logs]
      ..sort((a, b) => a.markedAt.compareTo(b.markedAt));
    for (var i = 0; i < chronological.length; i++) {
      final a = chronological[i];
      if (a.kind != 'entrada') continue;
      AttendanceLog? salida;
      for (var j = i + 1; j < chronological.length; j++) {
        if (chronological[j].kind == 'salida') {
          salida = chronological[j];
          break;
        }
      }
      if (salida == null) continue;
      final slice = LaborCalc.pairHours(
        entrada: a.markedAt,
        salida: salida.markedAt,
        settings: settings,
        holidayIso: holidays,
      );
      breakdown.ordinarias += slice.ordinarias;
      breakdown.extraDiurna += slice.extraDiurna;
      breakdown.extraNocturna += slice.extraNocturna;
      breakdown.recargoNocturno += slice.recargoNocturno;
      breakdown.dominicalOrdinario += slice.dominicalOrdinario;
      breakdown.extraDiurnaFestivo += slice.extraDiurnaFestivo;
      breakdown.extraNocturnaFestivo += slice.extraNocturnaFestivo;
    }
    return _HoursData(
      period: period,
      corte: settings.periodoCorte,
      breakdown: breakdown,
      logs: logs,
    );
  }
}

class _HoursData {
  _HoursData({
    required this.period,
    required this.corte,
    required this.breakdown,
    required this.logs,
  });
  final PayrollPeriod period;
  final String corte;
  final HourBreakdown breakdown;
  final List<AttendanceLog> logs;
}
