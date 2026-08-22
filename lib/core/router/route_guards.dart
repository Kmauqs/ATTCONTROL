import '../models/models.dart';

/// Resolves GoRouter redirects for auth and staff-only screens.
String? resolveAppRedirect({
  required bool bootstrapping,
  required bool isLoggedIn,
  required UserRol? rol,
  required String location,
}) {
  if (bootstrapping) return null;
  final loggingIn = location == '/login';
  if (!isLoggedIn) return loggingIn ? null : '/login';
  if (loggingIn) return '/home';
  if (location == '/qr' && rol?.canScanQr != true) return '/home';
  if (location.startsWith('/sites') && rol?.isStaff != true) return '/home';
  if (location == '/map' && rol?.isStaff != true) return '/home';
  if (location.startsWith('/personnel') && rol?.isStaff != true) return '/home';
  return null;
}
