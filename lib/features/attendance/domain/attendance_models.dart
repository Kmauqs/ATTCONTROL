import '../../../core/models/models.dart';

class AttendanceLog {
  const AttendanceLog({
    required this.id,
    required this.clientId,
    required this.empleadoId,
    required this.kind,
    required this.markedAt,
    this.lat,
    this.lng,
    this.source = 'app',
    this.status = 'a_tiempo',
    this.dentroGeocerca = true,
    this.notas,
    this.synced = true,
  });

  final String id;
  final String clientId;
  final String empleadoId;
  final String kind;
  final DateTime markedAt;
  final double? lat;
  final double? lng;
  final String source;
  final String status;
  final bool dentroGeocerca;
  final String? notas;
  final bool synced;

  bool get isEntrada => kind == 'entrada';

  factory AttendanceLog.fromMap(Map<String, dynamic> map) {
    return AttendanceLog(
      id: map['id'] as String,
      clientId: map['client_id'] as String? ?? map['id'] as String,
      empleadoId: map['empleado_id'] as String,
      kind: map['kind'] as String? ?? 'entrada',
      markedAt: DateTime.parse(map['marked_at'] as String).toLocal(),
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      source: map['source'] as String? ?? 'app',
      status: map['status'] as String? ?? 'a_tiempo',
      dentroGeocerca: map['dentro_geocerca'] == true ||
          map['dentro_geocerca'] == 1 ||
          map['dentro_geocerca'] == '1',
      notas: map['notas'] as String?,
      synced: map['synced'] == null ||
          map['synced'] == true ||
          map['synced'] == 1,
    );
  }

  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'client_id': clientId,
        'empleado_id': empleadoId,
        'kind': kind,
        'marked_at': markedAt.toUtc().toIso8601String(),
        'lat': lat,
        'lng': lng,
        'source': source,
        'status': status,
        'dentro_geocerca': dentroGeocerca ? 1 : 0,
        'notas': notas,
        'synced': synced ? 1 : 0,
      };

  Map<String, dynamic> toRemoteMap() => {
        'id': id,
        'client_id': clientId,
        'empleado_id': empleadoId,
        'kind': kind,
        'marked_at': markedAt.toUtc().toIso8601String(),
        'lat': lat,
        'lng': lng,
        'source': source,
        'status': status,
        'dentro_geocerca': dentroGeocerca,
        'notas': notas,
      };
}

class Incidencia {
  const Incidencia({
    required this.id,
    required this.empleadoId,
    required this.tipo,
    required this.fechaInicio,
    required this.fechaFin,
    this.comentario,
    this.estado = 'pendiente',
    this.empleadoNombre,
  });

  final String id;
  final String empleadoId;
  final String tipo;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String? comentario;
  final String estado;
  final String? empleadoNombre;

  factory Incidencia.fromMap(Map<String, dynamic> map) {
    DateTime d(dynamic v) {
      if (v is DateTime) return v;
      return DateTime.parse(v.toString());
    }

    return Incidencia(
      id: map['id'] as String,
      empleadoId: map['empleado_id'] as String,
      tipo: map['tipo'] as String,
      fechaInicio: d(map['fecha_inicio']),
      fechaFin: d(map['fecha_fin']),
      comentario: map['comentario'] as String?,
      estado: map['estado'] as String? ?? 'pendiente',
      empleadoNombre: map['empleado_nombre'] as String?,
    );
  }
}

enum PresenceKind { presente, ausente, tarde }

class PresenceRow {
  const PresenceRow({
    required this.profile,
    required this.kind,
    this.lastMark,
  });

  final UserProfile profile;
  final PresenceKind kind;
  final AttendanceLog? lastMark;
}
