enum UserRol {
  superAdmin,
  supervisor,
  empleado,
  asesor,
  contratista;

  String get dbValue => switch (this) {
        UserRol.superAdmin => 'super_admin',
        UserRol.supervisor => 'supervisor',
        UserRol.empleado => 'empleado',
        UserRol.asesor => 'asesor',
        UserRol.contratista => 'contratista',
      };

  String get label => switch (this) {
        UserRol.superAdmin => 'Super Admin',
        UserRol.supervisor => 'Supervisor de Campo',
        UserRol.empleado => 'Empleado',
        UserRol.asesor => 'Asesor',
        UserRol.contratista => 'Contratista',
      };

  static UserRol parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase().replaceAll(' ', '_')) {
      case 'super_admin':
      case 'superadmin':
        return UserRol.superAdmin;
      case 'supervisor':
      case 'supervisor_de_campo':
        return UserRol.supervisor;
      case 'asesor':
        return UserRol.asesor;
      case 'contratista':
        return UserRol.contratista;
      default:
        return UserRol.empleado;
    }
  }

  bool get isStaff =>
      this == UserRol.superAdmin || this == UserRol.supervisor;

  bool get canRequestLeave => this == UserRol.empleado;

  bool get canManageLabor => this == UserRol.superAdmin;

  bool get canScanQr => isStaff;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.documento,
    required this.nombre,
    required this.apellido,
    this.cargo,
    this.correo,
    this.rh,
    this.eps,
    this.arl,
    required this.rol,
    this.locationId,
    this.shiftId,
    this.activo = true,
  });

  final String id;
  final String documento;
  final String nombre;
  final String apellido;
  final String? cargo;
  final String? correo;
  final String? rh;
  final String? eps;
  final String? arl;
  final UserRol rol;
  final String? locationId;
  final String? shiftId;
  final bool activo;

  String get fullName => '$nombre $apellido'.trim();

  String get initials {
    final a = nombre.isNotEmpty ? nombre[0] : '';
    final b = apellido.isNotEmpty ? apellido[0] : '';
    return '$a$b'.toUpperCase();
  }

  UserProfile copyWith({
    String? cargo,
    String? correo,
    String? rh,
    String? eps,
    String? arl,
    UserRol? rol,
    String? locationId,
    String? shiftId,
    bool? activo,
    String? nombre,
    String? apellido,
    String? documento,
  }) {
    return UserProfile(
      id: id,
      documento: documento ?? this.documento,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      cargo: cargo ?? this.cargo,
      correo: correo ?? this.correo,
      rh: rh ?? this.rh,
      eps: eps ?? this.eps,
      arl: arl ?? this.arl,
      rol: rol ?? this.rol,
      locationId: locationId ?? this.locationId,
      shiftId: shiftId ?? this.shiftId,
      activo: activo ?? this.activo,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'documento': documento,
        'nombre': nombre,
        'apellido': apellido,
        'cargo': cargo,
        'correo': correo,
        'rh': rh,
        'eps': eps,
        'arl': arl,
        'rol': rol.dbValue,
        'location_id': locationId,
        'shift_id': shiftId,
        'activo': activo ? 1 : 0,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      documento: '${map['documento']}',
      nombre: map['nombre'] as String? ?? '',
      apellido: map['apellido'] as String? ?? '',
      cargo: map['cargo'] as String?,
      correo: map['correo'] as String?,
      rh: map['rh'] as String?,
      eps: map['eps'] as String?,
      arl: map['arl'] as String?,
      rol: UserRol.parse(map['rol'] as String?),
      locationId: map['location_id'] as String?,
      shiftId: map['shift_id'] as String?,
      activo: map['activo'] == true || map['activo'] == 1 || map['activo'] == '1',
    );
  }
}

class WorkSite {
  const WorkSite({
    required this.id,
    required this.nombre,
    this.proyecto,
    this.cuadrilla,
    required this.lat,
    required this.lng,
    required this.radioMetros,
  });

  final String id;
  final String nombre;
  final String? proyecto;
  final String? cuadrilla;
  final double lat;
  final double lng;
  final int radioMetros;

  factory WorkSite.fromMap(Map<String, dynamic> map) => WorkSite(
        id: map['id'] as String,
        nombre: map['nombre'] as String? ?? '',
        proyecto: map['proyecto'] as String?,
        cuadrilla: map['cuadrilla'] as String?,
        lat: (map['lat'] as num?)?.toDouble() ?? 4.60971,
        lng: (map['lng'] as num?)?.toDouble() ?? -74.08175,
        radioMetros: (map['radio_metros'] as num?)?.toInt() ?? 250,
      );
}

class Shift {
  const Shift({
    required this.id,
    required this.nombre,
    required this.horaEntrada,
    required this.horaSalida,
    required this.horaEntradaSabado,
    required this.horaSalidaSabado,
  });

  final String id;
  final String nombre;
  final String horaEntrada;
  final String horaSalida;
  final String horaEntradaSabado;
  final String horaSalidaSabado;

  factory Shift.fromMap(Map<String, dynamic> map) => Shift(
        id: map['id'] as String,
        nombre: map['nombre'] as String? ?? 'Jornada',
        horaEntrada: map['hora_entrada'] as String? ?? '07:00',
        horaSalida: map['hora_salida'] as String? ?? '17:00',
        horaEntradaSabado: map['hora_entrada_sabado'] as String? ?? '08:00',
        horaSalidaSabado: map['hora_salida_sabado'] as String? ?? '12:00',
      );
}

class LaborSettings {
  const LaborSettings({
    this.periodoCorte = 'quincenal',
    this.horaEntrada = '07:00',
    this.horaSalida = '17:00',
    this.horaEntradaSabado = '08:00',
    this.horaSalidaSabado = '12:00',
    this.extraDiurna = 0.25,
    this.extraNocturna = 0.75,
    this.recargoNocturno = 0.35,
    this.dominicalOrdinario = 0.90,
    this.extraDiurnaFestivo = 1.05,
    this.extraNocturnaFestivo = 1.55,
  });

  final String periodoCorte;
  final String horaEntrada;
  final String horaSalida;
  final String horaEntradaSabado;
  final String horaSalidaSabado;
  final double extraDiurna;
  final double extraNocturna;
  final double recargoNocturno;
  final double dominicalOrdinario;
  final double extraDiurnaFestivo;
  final double extraNocturnaFestivo;

  factory LaborSettings.fromMap(Map<String, dynamic> map) => LaborSettings(
        periodoCorte: map['periodo_corte'] as String? ?? 'quincenal',
        horaEntrada: map['hora_entrada'] as String? ?? '07:00',
        horaSalida: map['hora_salida'] as String? ?? '17:00',
        horaEntradaSabado: map['hora_entrada_sabado'] as String? ?? '08:00',
        horaSalidaSabado: map['hora_salida_sabado'] as String? ?? '12:00',
        extraDiurna: (map['extra_diurna'] as num?)?.toDouble() ?? 0.25,
        extraNocturna: (map['extra_nocturna'] as num?)?.toDouble() ?? 0.75,
        recargoNocturno: (map['recargo_nocturno'] as num?)?.toDouble() ?? 0.35,
        dominicalOrdinario:
            (map['dominical_ordinario'] as num?)?.toDouble() ?? 0.90,
        extraDiurnaFestivo:
            (map['extra_diurna_festivo'] as num?)?.toDouble() ?? 1.05,
        extraNocturnaFestivo:
            (map['extra_nocturna_festivo'] as num?)?.toDouble() ?? 1.55,
      );

  Map<String, dynamic> toMap() => {
        'periodo_corte': periodoCorte,
        'hora_entrada': horaEntrada,
        'hora_salida': horaSalida,
        'hora_entrada_sabado': horaEntradaSabado,
        'hora_salida_sabado': horaSalidaSabado,
        'extra_diurna': extraDiurna,
        'extra_nocturna': extraNocturna,
        'recargo_nocturno': recargoNocturno,
        'dominical_ordinario': dominicalOrdinario,
        'extra_diurna_festivo': extraDiurnaFestivo,
        'extra_nocturna_festivo': extraNocturnaFestivo,
      };
}
