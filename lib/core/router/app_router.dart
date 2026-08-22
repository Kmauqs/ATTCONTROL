import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/presentation/qr_scan_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/personnel/presentation/carnet_screen.dart';
import '../../features/personnel/presentation/personnel_screens.dart';
import '../../features/settings/presentation/sites_screen.dart';
import '../shell/app_shell.dart';
import 'route_guards.dart';

final _refresh = _GoRefresh();

class _GoRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  ref.listen(authControllerProvider, (_, _) => _refresh.ping());
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      return resolveAppRedirect(
        bootstrapping: auth.bootstrapping,
        isLoggedIn: auth.isLoggedIn,
        rol: auth.profile?.rol,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/home', builder: (c, s) => const AppShell()),
      GoRoute(path: '/qr', builder: (c, s) => const QrScanScreen()),
      GoRoute(path: '/carnet', builder: (c, s) => const CarnetScreen()),
      GoRoute(path: '/sites', builder: (c, s) => const SitesScreen()),
      GoRoute(path: '/sites/new', builder: (c, s) => const SiteFormScreen()),
      GoRoute(
        path: '/sites/:id',
        builder: (c, s) => SiteFormScreen(id: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/personnel/new',
        builder: (c, s) => const PersonnelFormScreen(),
      ),
      GoRoute(
        path: '/personnel/:id',
        builder: (c, s) => PersonnelFormScreen(id: s.pathParameters['id']),
      ),
    ],
  );
});
