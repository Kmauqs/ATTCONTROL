import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attcontrol/core/models/models.dart';
import 'package:attcontrol/core/router/route_guards.dart';
import 'package:attcontrol/core/theme/app_theme.dart';
import 'package:attcontrol/core/utils/geofence.dart';
import 'package:attcontrol/core/utils/labor_calc.dart';
import 'package:attcontrol/core/utils/passwords.dart';
import 'package:attcontrol/features/attendance/domain/attendance_models.dart';

void main() {
  test('geocerca acepta el punto del sitio', () {
    const site = GeoPoint(4.60971, -74.08175);
    expect(
      isInsideGeofence(user: site, site: site, radiusMeters: 250),
      isTrue,
    );
    expect(
      isInsideGeofence(
        user: const GeoPoint(4.62, -74.08175),
        site: site,
        radiusMeters: 250,
      ),
      isFalse,
    );
  });

  test('hora extra nocturna en festivo', () {
    final b = LaborCalc.pairHours(
      entrada: DateTime(2026, 7, 20, 19),
      salida: DateTime(2026, 7, 20, 21),
      settings: const LaborSettings(),
      holidayIso: {'2026-07-20'},
    );
    expect(b.extraNocturnaFestivo, greaterThan(1.5));
  });

  test('color corporativo', () {
    expect(AppColors.forest, const Color(0xFF1B5E3B));
  });

  test('fuera de geocerca no cuenta como presente', () {
    final fuera = AttendanceLog(
      id: '1',
      clientId: '1',
      empleadoId: 'e1',
      kind: 'entrada',
      markedAt: DateTime(2026, 8, 21, 8),
      dentroGeocerca: false,
      status: 'fuera_sitio',
    );
    expect(presenceKindFor(fuera), PresenceKind.ausente);
    expect(presenceKindFor(null), PresenceKind.ausente);
    expect(
      presenceKindFor(
        AttendanceLog(
          id: '2',
          clientId: '2',
          empleadoId: 'e1',
          kind: 'entrada',
          markedAt: DateTime(2026, 8, 21, 8),
          status: 'tarde',
        ),
      ),
      PresenceKind.tarde,
    );
    expect(
      presenceKindFor(
        AttendanceLog(
          id: '3',
          clientId: '3',
          empleadoId: 'e1',
          kind: 'entrada',
          markedAt: DateTime(2026, 8, 21, 8),
        ),
      ),
      PresenceKind.presente,
    );
  });

  test('contraseña nueva es obligatoria y de 8 caracteres', () {
    expect(validatePassword('', required: true), isNotNull);
    expect(validatePassword('corta', required: true), isNotNull);
    expect(validatePassword('segura123', required: true), isNull);
    expect(validatePassword('', required: false), isNull);
  });

  test('empleado no entra a QR ni a personal', () {
    expect(
      resolveAppRedirect(
        bootstrapping: false,
        isLoggedIn: true,
        rol: UserRol.empleado,
        location: '/qr',
      ),
      '/home',
    );
    expect(
      resolveAppRedirect(
        bootstrapping: false,
        isLoggedIn: true,
        rol: UserRol.empleado,
        location: '/personnel/new',
      ),
      '/home',
    );
    expect(
      resolveAppRedirect(
        bootstrapping: false,
        isLoggedIn: true,
        rol: UserRol.supervisor,
        location: '/qr',
      ),
      isNull,
    );
  });

  test('sin sesión se envía al login', () {
    expect(
      resolveAppRedirect(
        bootstrapping: false,
        isLoggedIn: false,
        rol: null,
        location: '/home',
      ),
      '/login',
    );
  });
}
