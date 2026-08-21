import '../models/models.dart';

class HourBreakdown {
  double ordinarias = 0;
  double extraDiurna = 0;
  double extraNocturna = 0;
  double recargoNocturno = 0;
  double dominicalOrdinario = 0;
  double extraDiurnaFestivo = 0;
  double extraNocturnaFestivo = 0;

  double get totalHoras =>
      ordinarias +
      extraDiurna +
      extraNocturna +
      recargoNocturno +
      dominicalOrdinario +
      extraDiurnaFestivo +
      extraNocturnaFestivo;

  Map<String, double> asMap() => {
        'Ordinarias': ordinarias,
        'Extra diurna (25%)': extraDiurna,
        'Extra nocturna (75%)': extraNocturna,
        'Recargo nocturno (35%)': recargoNocturno,
        'Dominical/festivo (90%)': dominicalOrdinario,
        'Extra diurna festivo (105%)': extraDiurnaFestivo,
        'Extra nocturna festivo (155%)': extraNocturnaFestivo,
      };
}

class PayrollPeriod {
  const PayrollPeriod(this.start, this.end, this.label);
  final DateTime start;
  final DateTime end;
  final String label;
}

class LaborCalc {
  static DateTime parseHm(DateTime day, String hm) {
    final p = hm.split(':');
    final h = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p.length > 1 ? p[1] : '0') ?? 0;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  static bool isNight(DateTime t) {
    final minutes = t.hour * 60 + t.minute;
    return minutes >= 19 * 60 || minutes < 6 * 60;
  }

  static PayrollPeriod periodFor(DateTime day, String corte) {
    final d = DateTime(day.year, day.month, day.day);
    switch (corte) {
      case 'semanal':
        final monday = d.subtract(Duration(days: (d.weekday + 6) % 7));
        final end = monday.add(const Duration(days: 6, hours: 23, minutes: 59));
        return PayrollPeriod(monday, end, 'Semana ${_fmt(monday)}');
      case 'mensual':
        final start = DateTime(d.year, d.month, 1);
        final end = DateTime(d.year, d.month + 1, 0, 23, 59);
        return PayrollPeriod(start, end, '${_month(d.month)} ${d.year}');
      default:
        if (d.day <= 15) {
          final start = DateTime(d.year, d.month, 1);
          final end = DateTime(d.year, d.month, 15, 23, 59);
          return PayrollPeriod(start, end, '1–15 ${_month(d.month)}');
        }
        final start = DateTime(d.year, d.month, 16);
        final end = DateTime(d.year, d.month + 1, 0, 23, 59);
        return PayrollPeriod(start, end, '16–fin ${_month(d.month)}');
    }
  }

  static HourBreakdown pairHours({
    required DateTime entrada,
    required DateTime salida,
    required LaborSettings settings,
    required Set<String> holidayIso,
  }) {
    final out = HourBreakdown();
    if (!salida.isAfter(entrada)) return out;
    final day = DateTime(entrada.year, entrada.month, entrada.day);
    final saturday = day.weekday == DateTime.saturday;
    final sunday = day.weekday == DateTime.sunday;
    final iso = _iso(day);
    final holiday = holidayIso.contains(iso);
    final festive = sunday || holiday;

    final shiftStart = parseHm(
      day,
      saturday ? settings.horaEntradaSabado : settings.horaEntrada,
    );
    final shiftEnd = parseHm(
      day,
      saturday ? settings.horaSalidaSabado : settings.horaSalida,
    );

    var cursor = entrada;
    while (cursor.isBefore(salida)) {
      final next = cursor.add(const Duration(minutes: 15));
      final sliceEnd = next.isAfter(salida) ? salida : next;
      final hours =
          sliceEnd.difference(cursor).inMinutes / 60.0;
      final night = isNight(cursor);
      final extra = cursor.isBefore(shiftStart) || !cursor.isBefore(shiftEnd);

      if (festive) {
        if (extra && night) {
          out.extraNocturnaFestivo += hours;
        } else if (extra) {
          out.extraDiurnaFestivo += hours;
        } else {
          out.dominicalOrdinario += hours;
        }
      } else if (extra && night) {
        out.extraNocturna += hours;
      } else if (extra) {
        out.extraDiurna += hours;
      } else if (night) {
        out.recargoNocturno += hours;
      } else {
        out.ordinarias += hours;
      }
      cursor = sliceEnd;
    }
    return out;
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _fmt(DateTime d) => '${d.day}/${d.month}';

  static String _month(int m) {
    const names = [
      '',
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return names[m];
  }
}
