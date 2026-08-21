import 'dart:math';

class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

double distanceMeters(GeoPoint a, GeoPoint b) {
  const r = 6371000.0;
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final sa = sin(dLat / 2);
  final sb = sin(dLng / 2);
  final h =
      sa * sa + cos(_rad(a.lat)) * cos(_rad(b.lat)) * sb * sb;
  return 2 * r * asin(min(1, sqrt(h)));
}

bool isInsideGeofence({
  required GeoPoint user,
  required GeoPoint site,
  required int radiusMeters,
}) {
  if (radiusMeters <= 0) return true;
  return distanceMeters(user, site) <= radiusMeters;
}

double _rad(double deg) => deg * pi / 180;
