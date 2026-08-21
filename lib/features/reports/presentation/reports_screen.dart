import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../data/app_repository.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTimeRange? _range;
  String? _proyecto;
  String? _cuadrilla;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  Future<(List<Map<String, String>>, String)> _rows() async {
    final repo = ref.read(appRepositoryProvider);
    final logs = await repo.allLogs(from: _range?.start, to: _range?.end);
    final people = {for (final p in await repo.listPersonnel()) p.id: p};
    final sites = <String, String>{};
    final rows = <Map<String, String>>[];
    for (final log in logs) {
      final p = people[log.empleadoId];
      if (p == null) continue;
      final site = await repo.siteFor(p);
      if (_proyecto != null &&
          _proyecto!.isNotEmpty &&
          site?.proyecto != _proyecto) {
        continue;
      }
      if (_cuadrilla != null &&
          _cuadrilla!.isNotEmpty &&
          site?.cuadrilla != _cuadrilla) {
        continue;
      }
      sites[p.id] = site?.nombre ?? '';
      rows.add({
        'documento': p.documento,
        'nombre': p.fullName,
        'cargo': p.cargo ?? '',
        'proyecto': site?.proyecto ?? '',
        'cuadrilla': site?.cuadrilla ?? '',
        'tipo': log.kind,
        'fecha': DateFormat('dd/MM/yyyy HH:mm').format(log.markedAt),
        'estado': log.status,
        'gps': log.lat == null ? '' : '${log.lat},${log.lng}',
      });
    }
    return (rows, sites.toString());
  }

  Future<void> _csv() async {
    final (rows, _) = await _rows();
    final buf = StringBuffer(
      'documento,nombre,cargo,proyecto,cuadrilla,tipo,fecha,estado,gps\n',
    );
    for (final r in rows) {
      buf.writeln(
        r.values.map((v) => '"${v.replaceAll('"', '""')}"').join(','),
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/asistencia_attcontrol.csv');
    await file.writeAsString(buf.toString());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV guardado en ${file.path}')),
    );
  }

  Future<void> _pdf() async {
    final (rows, _) = await _rows();
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Text(
            'ATTCONTROL — Reporte de asistencia',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Documento',
              'Nombre',
              'Cargo',
              'Proyecto',
              'Cuadrilla',
              'Tipo',
              'Fecha',
              'Estado',
            ],
            data: [
              for (final r in rows)
                [
                  r['documento'],
                  r['nombre'],
                  r['cargo'],
                  r['proyecto'],
                  r['cuadrilla'],
                  r['tipo'],
                  r['fecha'],
                  r['estado'],
                ],
            ],
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Reportes',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        ListTile(
          title: const Text('Rango de fechas'),
          subtitle: Text(
            _range == null
                ? 'Todo el histórico local'
                : '${DateFormat('dd/MM/yyyy').format(_range!.start)} – ${DateFormat('dd/MM/yyyy').format(_range!.end)}',
          ),
          trailing: const Icon(Icons.date_range),
          onTap: _pickRange,
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Proyecto (opcional)'),
          onChanged: (v) => _proyecto = v.trim(),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(labelText: 'Cuadrilla (opcional)'),
          onChanged: (v) => _cuadrilla = v.trim(),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _pdf,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Exportar PDF'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _csv,
          icon: const Icon(Icons.table_view),
          label: const Text('Exportar Excel/CSV'),
        ),
        const SizedBox(height: 16),
        const Text(
          'El CSV se abre en Excel. Filtra por fecha, proyecto o cuadrilla antes de exportar.',
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}
