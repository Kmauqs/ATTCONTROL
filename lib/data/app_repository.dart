import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/env.dart';
import '../../core/models/models.dart';
import '../../core/utils/geofence.dart';
import '../../core/utils/labor_calc.dart';
import '../../core/utils/passwords.dart';
import '../../features/attendance/domain/attendance_models.dart';
import 'local/local_db.dart';

final appRepositoryProvider = Provider<AppRepository>((ref) {
  return AppRepository(
    supabase: Env.hasSupabase ? Supabase.instance.client : null,
  );
});

class PunchResult {
  const PunchResult({
    this.log,
    required this.message,
    required this.ok,
    this.offline = false,
  });

  final AttendanceLog? log;
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

  Future<UserProfile?> profileById(String id) async {
    if (remote) {
      try {
        final row =
            await supabase!.from('profiles').select().eq('id', id).maybeSingle();
        if (row != null) {
          return UserProfile.fromMap(Map<String, dynamic>.from(row));
        }
      } catch (_) {}
    }
    final db = await _local.db;
    final rows = await db.query('profiles', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return UserProfile.fromMap(rows.first);
  }

  Future<UserProfile> loginLocal(String identifier, String password) async {
    final db = await _local.db;
    final id = identifier.trim().toLowerCase();
    final rows = await db.query(
      'profiles',
      where: 'lower(documento) = ? OR lower(correo) = ?',
      whereArgs: [id, id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw Exception('No encontramos ese documento o correo');
    }
    final row = rows.first;
    final profile = UserProfile.fromMap(row);
    if (!profile.activo) throw Exception('Usuario inactivo');
    final stored = row['password_hash'] as String?;
    if (stored != null && stored.isNotEmpty) {
      if (stored != hashLocalPassword(password, profile.id)) {
        throw Exception('Contraseña incorrecta');
      }
      return profile;
    }
    if (!Env.hasSupabase && password == Env.seedPassword) {
      return profile;
    }
    throw Exception('Pide a tu supervisor que asigne una contraseña');
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

  Future<UserProfile> upsertPersonnel(
    UserProfile profile, {
    String? password,
  }) async {
    final db = await _local.db;
    var saved = profile;
    final isNew = profile.id.isEmpty;
    if (remote) {
      final res = await supabase!.functions.invoke(
        'create-employee',
        body: {
          if (!isNew) 'id': profile.id,
          'documento': profile.documento,
          'nombre': profile.nombre,
          'apellido': profile.apellido,
          'cargo': profile.cargo,
          'correo': profile.correo,
          'rh': profile.rh,
          'eps': profile.eps,
          'arl': profile.arl,
          'rol': profile.rol.dbValue,
          'activo': profile.activo,
          'location_id': profile.locationId,
          'shift_id': profile.shiftId,
          if (password != null && password.isNotEmpty) 'password': password,
        },
      );
      if (res.status >= 400) {
        final err = res.data is Map ? res.data['error'] : null;
        throw Exception(err ?? 'No se pudo guardar el personal');
      }
      final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      final id = data['id'] as String? ?? profile.id;
      if (id.isEmpty) {
        throw Exception('No se pudo crear la cuenta de acceso');
      }
      saved = UserProfile(
        id: id,
        documento: profile.documento,
        nombre: profile.nombre,
        apellido: profile.apellido,
        cargo: profile.cargo,
        correo: profile.correo,
        rh: profile.rh,
        eps: profile.eps,
        arl: profile.arl,
        rol: profile.rol,
        locationId: profile.locationId,
        shiftId: profile.shiftId,
        activo: profile.activo,
        fotoPath: profile.fotoPath,
        carnetPath: profile.carnetPath,
      );
      if (!isNew && profile.id.isNotEmpty && profile.id != saved.id) {
        await db.delete('profiles', where: 'id = ?', whereArgs: [profile.id]);
      }
    } else if (isNew) {
      saved = UserProfile(
        id: _uuid.v4(),
        documento: profile.documento,
        nombre: profile.nombre,
        apellido: profile.apellido,
        cargo: profile.cargo,
        correo: profile.correo,
        rh: profile.rh,
        eps: profile.eps,
        arl: profile.arl,
        rol: profile.rol,
        locationId: profile.locationId,
        shiftId: profile.shiftId,
        activo: profile.activo,
        fotoPath: profile.fotoPath,
        carnetPath: profile.carnetPath,
      );
    }
    final map = saved.toMap();
    if (password != null && password.isNotEmpty) {
      map['password_hash'] = hashLocalPassword(password, saved.id);
    } else {
      final prev = await db.query(
        'profiles',
        columns: ['password_hash'],
        where: 'id = ?',
        whereArgs: [saved.id],
      );
      if (prev.isNotEmpty && prev.first['password_hash'] != null) {
        map['password_hash'] = prev.first['password_hash'];
      }
    }
    await db.insert('profiles', map, conflictAlgorithm: ConflictAlgorithm.replace);
    return saved;
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
      try {
        final row = await supabase!
            .from('locations')
            .select()
            .eq('id', id)
            .maybeSingle();
        if (row != null) return WorkSite.fromMap(Map<String, dynamic>.from(row));
      } catch (_) {}
    }
    return null;
  }

  Future<List<WorkSite>> listSites({bool onlyActive = true}) async {
    if (remote && await _online()) {
      try {
        final rows = onlyActive
            ? await supabase!
                .from('locations')
                .select()
                .eq('activo', true)
                .order('nombre')
            : await supabase!.from('locations').select().order('nombre');
        final list = (rows as List)
            .map((e) => WorkSite.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        final db = await _local.db;
        for (final site in list) {
          await db.insert(
            'locations',
            site.toLocalMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        return list;
      } catch (_) {}
    }
    final db = await _local.db;
    final rows = onlyActive
        ? await db.query('locations', where: 'activo IS NULL OR activo = 1')
        : await db.query('locations', orderBy: 'nombre');
    return rows.map(WorkSite.fromMap).toList();
  }

  Future<WorkSite> upsertSite(WorkSite site) async {
    final db = await _local.db;
    await db.insert(
      'locations',
      site.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (remote) {
      await supabase!.from('locations').upsert(site.toRemoteMap());
    }
    return site;
  }

  Future<void> setSiteActive(String id, bool activo) async {
    final db = await _local.db;
    await db.update(
      'locations',
      {'activo': activo ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (remote) {
      await supabase!.from('locations').update({'activo': activo}).eq('id', id);
    }
  }

  Future<String?> signedFileUrl(String? path) async {
    if (path == null || path.isEmpty || !remote) return null;
    try {
      return await supabase!.storage
          .from('personnel-files')
          .createSignedUrl(path, 60 * 60);
    } catch (_) {
      return null;
    }
  }

  Future<UserProfile> uploadPersonnelFile({
    required UserProfile profile,
    required String kind,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (!remote) {
      throw Exception('Necesitas conexión para cargar la foto o el carnet');
    }
    final ext = contentType.contains('pdf') ? 'pdf' : 'jpg';
    final path = '${profile.id}/$kind.$ext';
    await supabase!.storage.from('personnel-files').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    final field = kind == 'carnet' ? 'carnet_path' : 'foto_path';
    await supabase!.from('profiles').update({field: path}).eq('id', profile.id);
    final updated = profile.copyWith(
      fotoPath: kind == 'foto' ? path : profile.fotoPath,
      carnetPath: kind == 'carnet' ? path : profile.carnetPath,
    );
    final db = await _local.db;
    await db.update(
      'profiles',
      {field: path},
      where: 'id = ?',
      whereArgs: [profile.id],
    );
    return updated;
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
    if (remote && await _online()) {
      try {
        final rows = await supabase!.from('labor_settings').select().limit(1);
        if (rows.isNotEmpty) {
          final settings =
              LaborSettings.fromMap(Map<String, dynamic>.from(rows.first));
          final db = await _local.db;
          await db.update('labor_settings', settings.toMap());
          return settings;
        }
      } catch (_) {}
    }
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
    if (remote && await _online()) {
      try {
        final rows = await supabase!.from('holidays').select('fecha');
        if (rows.isNotEmpty) {
          return {
            for (final e in rows) (e as Map)['fecha'].toString().substring(0, 10),
          };
        }
      } catch (_) {}
    }
    final db = await _local.db;
    final rows = await db.query('holidays');
    return rows.map((e) => e['fecha'] as String).toSet();
  }

  Future<AttendanceLog?> lastToday(String empleadoId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final logs = await logsFor(
      empleadoId,
      from: start,
      to: start.add(const Duration(days: 1)),
    );
    return logs.isEmpty ? null : logs.first;
  }

  Future<List<AttendanceLog>> logsFor(String empleadoId, {DateTime? from, DateTime? to}) async {
    if (remote && await _online()) {
      try {
        var q = supabase!
            .from('attendance_logs')
            .select()
            .eq('empleado_id', empleadoId);
        if (from != null) {
          q = q.gte('marked_at', from.toUtc().toIso8601String());
        }
        if (to != null) {
          q = q.lte('marked_at', to.toUtc().toIso8601String());
        }
        final rows = await q.order('marked_at', ascending: false);
        final remoteLogs = (rows as List)
            .map((e) => AttendanceLog.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        final pending = await _pendingLogs(empleadoId);
        return _mergeLogs(remoteLogs, pending);
      } catch (_) {}
    }
    return _localLogs(empleadoId, from: from, to: to);
  }

  Future<List<AttendanceLog>> allLogs({DateTime? from, DateTime? to}) async {
    if (remote && await _online()) {
      try {
        var q = supabase!.from('attendance_logs').select();
        if (from != null) {
          q = q.gte('marked_at', from.toUtc().toIso8601String());
        }
        if (to != null) {
          q = q.lte('marked_at', to.toUtc().toIso8601String());
        }
        final rows = await q.order('marked_at', ascending: false);
        final remoteLogs = (rows as List)
            .map((e) => AttendanceLog.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        final pending = await _pendingLogs(null);
        return _mergeLogs(remoteLogs, pending);
      } catch (_) {}
    }
    return _localLogs(null, from: from, to: to);
  }

  Future<List<AttendanceLog>> _localLogs(
    String? empleadoId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _local.db;
    final rows = empleadoId == null
        ? await db.query('attendance_logs', orderBy: 'marked_at DESC')
        : await db.query(
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

  Future<List<AttendanceLog>> _pendingLogs(String? empleadoId) async {
    final db = await _local.db;
    final rows = empleadoId == null
        ? await db.query('attendance_logs', where: 'synced = 0')
        : await db.query(
            'attendance_logs',
            where: 'empleado_id = ? AND synced = 0',
            whereArgs: [empleadoId],
          );
    return rows.map(AttendanceLog.fromMap).toList();
  }

  List<AttendanceLog> _mergeLogs(
    List<AttendanceLog> remote,
    List<AttendanceLog> pending,
  ) {
    final byClient = {for (final l in remote) l.clientId: l};
    for (final l in pending) {
      byClient.putIfAbsent(l.clientId, () => l);
    }
    final list = byClient.values.toList()
      ..sort((a, b) => b.markedAt.compareTo(a.markedAt));
    return list;
  }

  Future<PunchResult> punch({
    required UserProfile actor,
    required UserProfile target,
    required double lat,
    required double lng,
    String source = 'app',
  }) async {
    final skipFence = target.rol.canSkipGeofence;
    final sites = (await listSites()).where((s) => s.activo).toList();
    final inside = skipFence ||
        isInsideAnyGeofence(
          user: GeoPoint(lat, lng),
          sites: [
            for (final s in sites)
              (lat: s.lat, lng: s.lng, radiusMeters: s.radioMetros),
          ],
        );
    if (!skipFence && sites.isEmpty) {
      return const PunchResult(
        ok: false,
        message: 'No hay sitios autorizados para validar el GPS',
      );
    }
    if (!inside) {
      return const PunchResult(
        ok: false,
        message:
            'Fuera de las oficinas y proyectos autorizados. Acércate a un sitio para fichar.',
      );
    }
    final shift = await shiftFor(target);
    if (actor.id != target.id && !actor.rol.canScanQr) {
      return const PunchResult(
        ok: false,
        message: 'No autorizado a fichar a otra persona',
      );
    }
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
    List<Map<String, dynamic>> rows;
    if (remote && await _online()) {
      try {
        var q = supabase!.from('incidencias').select();
        if (empleadoId != null) {
          q = q.eq('empleado_id', empleadoId);
        }
        final data = await q.order('fecha_inicio', ascending: false);
        rows = (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {
        rows = await _localIncidenciaRows(empleadoId);
      }
    } else {
      rows = await _localIncidenciaRows(empleadoId);
    }
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

  Future<List<Map<String, dynamic>>> _localIncidenciaRows(String? empleadoId) async {
    final db = await _local.db;
    final rows = empleadoId == null
        ? await db.query('incidencias', orderBy: 'fecha_inicio DESC')
        : await db.query(
            'incidencias',
            where: 'empleado_id = ?',
            whereArgs: [empleadoId],
            orderBy: 'fecha_inicio DESC',
          );
    return rows;
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
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final logs = await allLogs(
      from: start,
      to: start.add(const Duration(days: 1)),
    );
    final lastByEmp = <String, AttendanceLog>{};
    for (final log in logs) {
      lastByEmp.putIfAbsent(log.empleadoId, () => log);
    }
    return [
      for (final p in people)
        PresenceRow(
          profile: p,
          kind: presenceKindFor(lastByEmp[p.id]),
          lastMark: lastByEmp[p.id],
        ),
    ];
  }

  Future<bool> _online() async {
    final r = await Connectivity().checkConnectivity();
    return !r.contains(ConnectivityResult.none);
  }
}
