import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/env.dart';
import '../../core/models/models.dart';
import '../../core/utils/geofence.dart';
import '../../core/utils/labor_calc.dart';
import '../../features/attendance/domain/attendance_models.dart';
import 'local/local_db.dart';

final appRepositoryProvider = Provider<AppRepository>((ref) {
  return AppRepository(
    supabase: Env.hasSupabase ? Supabase.instance.client : null,
  );
});

class PunchResult {
  const PunchResult({
    required this.log,
    required this.message,
    required this.ok,
    this.offline = false,
  });

  final AttendanceLog log;
  final String message;
  final bool ok;
  final bool offline;
}

class AppRepository {
  AppRepository({required this.supabase});

  final SupabaseClient? supabase;
  final _uuid = const Uuid();
  final _local = LocalDb.instance;

  bool get remote => supabase != null;

  Future<UserProfile?> findProfile(String identifier) async {
    final db = await _local.db;
    final id = identifier.trim().toLowerCase();
    final rows = await db.query(
      'profiles',
      where: 'lower(documento) = ? OR lower(correo) = ?',
      whereArgs: [id, id],
      limit: 1,
    );
    if (rows.isNotEmpty) return UserProfile.fromMap(rows.first);
    if (!remote) return null;
    final byDoc = await supabase!
        .from('profiles')
        .select()
        .eq('documento', identifier.trim())
        .maybeSingle();
    if (byDoc != null) return UserProfile.fromMap(Map<String, dynamic>.from(byDoc));
    final byMail = await supabase!
        .from('profiles')
        .select()
        .ilike('correo', identifier.trim())
        .maybeSingle();
    if (byMail == null) return null;
    return UserProfile.fromMap(Map<String, dynamic>.from(byMail));
  }

  Future<UserProfile> loginLocal(String identifier, String password) async {
    if (password != Env.seedPassword) {
      throw Exception('Contraseña incorrecta');
    }
    final profile = await findProfile(identifier);
    if (profile == null) {
      throw Exception('No encontramos ese documento o correo');
    }
    if (!profile.activo) throw Exception('Usuario inactivo');
    return profile;
  }

  Future<UserProfile> loginRemote(String identifier, String password) async {
    final client = supabase!;
    final raw = identifier.trim();
    if (!raw.contains('@')) {
      await client.auth.signInWithPassword(
        email: '$raw@users.attcontrol.local',
        password: password,
      );
    } else {
      final res = await client.functions.invoke(
        'login-with-identifier',
        body: {'identifier': raw, 'password': password},
      );
      if (res.status >= 400) {
        throw Exception(
          (res.data is Map ? res.data['error'] : null) ??
              'No se pudo iniciar sesión',
        );
      }
      final data = Map<String, dynamic>.from(res.data as Map);
      final refresh = data['refresh_token'] as String?;
      if (refresh == null) {
        throw Exception('Sesión no establecida');
      }
      await client.auth.setSession(refresh);
    }
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw Exception('Sesión no establecida');
    final row =
        await client.from('profiles').select().eq('id', uid).maybeSingle();
    if (row == null) throw Exception('Perfil no encontrado');
    return UserProfile.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<UserProfile>> listPersonnel() async {
    final db = await _local.db;
    if (remote) {
      try {
        final rows = await supabase!
            .from('profiles')
            .select()
            .order('apellido');
        final list = (rows as List)
            .map((e) => UserProfile.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        for (final p in list) {
          await db.insert(
            'profiles',
            p.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        return list;
      } catch (_) {}
    }
    final rows = await db.query('profiles', orderBy: 'apellido');
    return rows.map(UserProfile.fromMap).toList();
  }

  Future<UserProfile> upsertPersonnel(UserProfile profile) async {
    final db = await _local.db;
    final map = profile.toMap();
    await db.insert('profiles', map, conflictAlgorithm: ConflictAlgorithm.replace);
    if (remote) {
      try {
        await supabase!.functions.invoke(
          'create-employee',
          body: {
            ...map,
            'activo': profile.activo,
          },
        );
      } catch (_) {
        await supabase!.from('profiles').upsert({
          ...map,
          'activo': profile.activo,
        });
      }
    }
    return profile;
  }

  Future<void> deletePersonnel(String id) async {
    final db = await _local.db;
    await db.delete('profiles', where: 'id = ?', whereArgs: [id]);
    if (remote) {
      try {
        await supabase!.from('profiles').update({'activo': false}).eq('id', id);
      } catch (_) {}
    }
  }

  Future<WorkSite?> siteFor(UserProfile profile) async {
    final db = await _local.db;
    final id = profile.locationId ?? kDefaultLocationId;
    final rows = await db.query('locations', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) return WorkSite.fromMap(rows.first);
    if (remote) {
      final row = await supabase!
          .from('locations')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row != null) return WorkSite.fromMap(Map<String, dynamic>.from(row));
    }
    return null;
  }

  Future<Shift?> shiftFor(UserProfile profile) async {
    final db = await _local.db;
    final id = profile.shiftId ?? kDefaultShiftId;
    final rows = await db.query('shifts', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) return Shift.fromMap(rows.first);
    return const Shift(
      id: kDefaultShiftId,
      nombre: 'Jornada estándar CO',
      horaEntrada: '07:00',
      horaSalida: '17:00',
      horaEntradaSabado: '08:00',
      horaSalidaSabado: '12:00',
    );
  }

  Future<LaborSettings> laborSettings() async {
    final db = await _local.db;
    final rows = await db.query('labor_settings', limit: 1);
    if (rows.isNotEmpty) return LaborSettings.fromMap(rows.first);
    return const LaborSettings();
  }

  Future<void> saveLaborSettings(LaborSettings settings) async {
    final db = await _local.db;
    await db.update('labor_settings', settings.toMap());
    if (remote) {
      await supabase!.from('labor_settings').update(settings.toMap()).neq('id', '');
    }
  }

  Future<Set<String>> holidays() async {
    final db = await _local.db;
    final rows = await db.query('holidays');
    return rows.map((e) => e['fecha'] as String).toSet();
  }

  Future<AttendanceLog?> lastToday(String empleadoId) async {
    final logs = await logsFor(empleadoId);
    final now = DateTime.now();
    final today = logs.where((l) =>
        l.markedAt.year == now.year &&
        l.markedAt.month == now.month &&
        l.markedAt.day == now.day);
    if (today.isEmpty) return null;
    return today.first;
  }

  Future<List<AttendanceLog>> logsFor(String empleadoId, {DateTime? from, DateTime? to}) async {
    final db = await _local.db;
    final rows = await db.query(
      'attendance_logs',
      where: 'empleado_id = ?',
      whereArgs: [empleadoId],
      orderBy: 'marked_at DESC',
    );
    var list = rows.map(AttendanceLog.fromMap).toList();
    if (from != null) {
      list = list.where((l) => !l.markedAt.isBefore(from)).toList();
    }
    if (to != null) {
      list = list.where((l) => !l.markedAt.isAfter(to)).toList();
    }
    return list;
  }

  Future<List<AttendanceLog>> allLogs({DateTime? from, DateTime? to}) async {
    final db = await _local.db;
    final rows = await db.query('attendance_logs', orderBy: 'marked_at DESC');
    var list = rows.map(AttendanceLog.fromMap).toList();
    if (from != null) {
      list = list.where((l) => !l.markedAt.isBefore(from)).toList();
    }
    if (to != null) {
      list = list.where((l) => !l.markedAt.isAfter(to)).toList();
    }
    return list;
  }

  Future<PunchResult> punch({
    required UserProfile actor,
    required UserProfile target,
    required double lat,
    required double lng,
    String source = 'app',
  }) async {
    final site = await siteFor(target);
    final shift = await shiftFor(target);
    final inside = site == null
        ? true
        : isInsideGeofence(
            user: GeoPoint(lat, lng),
            site: GeoPoint(site.lat, site.lng),
            radiusMeters: site.radioMetros,
          );
    final last = await lastToday(target.id);
    final kind = (last == null || last.kind == 'salida') ? 'entrada' : 'salida';
    var status = 'a_tiempo';
    final now = DateTime.now();
    if (shift != null && kind == 'entrada') {
      final saturday = now.weekday == DateTime.saturday;
      final limit = LaborCalc.parseHm(
        now,
        saturday ? shift.horaEntradaSabado : shift.horaEntrada,
      ).add(const Duration(minutes: 5));
      if (now.isAfter(limit)) status = 'tarde';
    }
    if (shift != null && kind == 'salida') {
      final saturday = now.weekday == DateTime.saturday;
      final limit = LaborCalc.parseHm(
        now,
        saturday ? shift.horaSalidaSabado : shift.horaSalida,
      );
      if (now.isBefore(limit)) status = 'salida_temprana';
    }
    if (!inside) status = 'fuera_sitio';

    final online = await _online();
    final log = AttendanceLog(
      id: _uuid.v4(),
      clientId: _uuid.v4(),
      empleadoId: target.id,
      kind: kind,
      markedAt: now,
      lat: lat,
      lng: lng,
      source: source,
      status: status,
      dentroGeocerca: inside,
      synced: online && remote,
    );

    final db = await _local.db;
    await db.insert('attendance_logs', log.toLocalMap());

    if (online && remote) {
      try {
        await supabase!.from('attendance_logs').upsert(log.toRemoteMap());
        await db.update(
          'attendance_logs',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [log.id],
        );
      } catch (_) {
        await db.update(
          'attendance_logs',
          {'synced': 0},
          where: 'id = ?',
          whereArgs: [log.id],
        );
      }
    }

    final who = actor.id == target.id ? '' : ' (${target.fullName})';
    final verb = kind == 'entrada' ? 'Entrada' : 'Salida';
    if (!inside) {
      return PunchResult(
        log: log,
        ok: false,
        message: '$verb registrada fuera del sitio asignado$who',
        offline: !online,
      );
    }
    return PunchResult(
      log: log,
      ok: true,
      message: online
          ? '$verb registrada$who'
          : '$verb guardada sin conexión$who. Se sincronizará después.',
      offline: !online,
    );
  }

  Future<void> syncPending() async {
    if (!remote) return;
    if (!await _online()) return;
    final db = await _local.db;
    final rows = await db.query('attendance_logs', where: 'synced = 0');
    for (final row in rows) {
      final log = AttendanceLog.fromMap(row);
      try {
        await supabase!.from('attendance_logs').upsert(log.toRemoteMap());
        await db.update(
          'attendance_logs',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [log.id],
        );
      } catch (_) {}
    }
  }

  Future<List<Incidencia>> incidencias({String? empleadoId}) async {
    final db = await _local.db;
    final rows = empleadoId == null
        ? await db.query('incidencias', orderBy: 'fecha_inicio DESC')
        : await db.query(
            'incidencias',
            where: 'empleado_id = ?',
            whereArgs: [empleadoId],
            orderBy: 'fecha_inicio DESC',
          );
    final people = {for (final p in await listPersonnel()) p.id: p};
    return rows.map((m) {
      final i = Incidencia.fromMap(m);
      return Incidencia(
        id: i.id,
        empleadoId: i.empleadoId,
        tipo: i.tipo,
        fechaInicio: i.fechaInicio,
        fechaFin: i.fechaFin,
        comentario: i.comentario,
        estado: i.estado,
        empleadoNombre: people[i.empleadoId]?.fullName,
      );
    }).toList();
  }

  Future<Incidencia> createIncidencia(Incidencia item) async {
    final db = await _local.db;
    await db.insert('incidencias', {
      'id': item.id,
      'empleado_id': item.empleadoId,
      'tipo': item.tipo,
      'fecha_inicio': item.fechaInicio.toIso8601String().substring(0, 10),
      'fecha_fin': item.fechaFin.toIso8601String().substring(0, 10),
      'comentario': item.comentario,
      'estado': item.estado,
    });
    if (remote) {
      try {
        await supabase!.from('incidencias').insert({
          'id': item.id,
          'empleado_id': item.empleadoId,
          'tipo': item.tipo,
          'fecha_inicio': item.fechaInicio.toIso8601String().substring(0, 10),
          'fecha_fin': item.fechaFin.toIso8601String().substring(0, 10),
          'comentario': item.comentario,
          'estado': item.estado,
        });
      } catch (_) {}
    }
    return item;
  }

  Future<void> setIncidenciaEstado(String id, String estado) async {
    final db = await _local.db;
    await db.update(
      'incidencias',
      {'estado': estado},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (remote) {
      try {
        await supabase!.from('incidencias').update({'estado': estado}).eq('id', id);
      } catch (_) {}
    }
  }

  Future<List<PresenceRow>> presenceToday() async {
    final people = (await listPersonnel()).where((p) => p.activo).toList();
    final rows = <PresenceRow>[];
    for (final p in people) {
      final last = await lastToday(p.id);
      PresenceKind kind;
      if (last == null || last.kind == 'salida') {
        kind = PresenceKind.ausente;
      } else if (last.status == 'tarde') {
        kind = PresenceKind.tarde;
      } else {
        kind = PresenceKind.presente;
      }
      rows.add(PresenceRow(profile: p, kind: kind, lastMark: last));
    }
    return rows;
  }

  Future<bool> _online() async {
    final r = await Connectivity().checkConnectivity();
    return !r.contains(ConnectivityResult.none);
  }
}
