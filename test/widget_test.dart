import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attcontrol/core/models/models.dart';
import 'package:attcontrol/core/theme/app_theme.dart';
import 'package:attcontrol/core/utils/geofence.dart';
import 'package:attcontrol/core/utils/labor_calc.dart';

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
}
