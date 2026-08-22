import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/presentation/dashboard_screen.dart';
import '../../features/attendance/presentation/hours_screen.dart';
import '../../features/attendance/presentation/punch_map_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/incidencias/presentation/incidencias_screen.dart';
import '../../features/personnel/presentation/personnel_screens.dart';
import '../../features/personnel/presentation/presence_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/labor_settings_screen.dart';
import '../config/app_version.dart';
import '../models/models.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _Dest {
  const _Dest(this.label, this.icon, this.builder, this.show);
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  final bool Function(UserRol) show;
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  List<_Dest> _dests(UserRol rol) {
    return [
      _Dest('Inicio', Icons.fingerprint, (_) => const DashboardScreen(), (_) => true),
      _Dest('Horas', Icons.schedule, (_) => const HoursScreen(), (_) => true),
      _Dest(
        'Equipo',
        Icons.groups_outlined,
        (_) => const PresenceScreen(),
        (r) => r.isStaff,
      ),
      _Dest(
        'Personal',
        Icons.badge_outlined,
        (_) => const PersonnelListScreen(),
        (r) => r.isStaff,
      ),
      _Dest(
        'Permisos',
        Icons.event_available,
        (_) => const IncidenciasScreen(),
        (r) => r.canRequestLeave || r.isStaff,
      ),
      _Dest(
        'Reportes',
        Icons.summarize_outlined,
        (_) => const ReportsScreen(),
        (r) => r.isStaff,
      ),
      _Dest(
        'Mapa',
        Icons.map_outlined,
        (_) => const PunchMapScreen(),
        (r) => r.isStaff,
      ),
      _Dest(
        'Ajustes',
        Icons.tune,
        (_) => const LaborSettingsScreen(),
        (r) => r.canManageLabor,
      ),
    ].where((d) => d.show(rol)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    if (profile == null) return const SizedBox.shrink();
    final dests = _dests(profile.rol);
    final index = _index.clamp(0, dests.length - 1);
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => _showAbout(context),
          child: Row(
            children: [
              Image.asset('assets/branding/icon_64.png', width: 32, height: 32),
              const SizedBox(width: 8),
              const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ATTCONTROL'),
                  Text(
                    kAppVersionLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Mi carnet',
            onPressed: () => context.push('/carnet'),
            icon: const Icon(Icons.badge_outlined),
          ),
          if (profile.rol.canScanQr)
            IconButton(
              tooltip: 'Escanear QR',
              onPressed: () => context.push('/qr'),
              icon: const Icon(Icons.qr_code_scanner),
            ),
          IconButton(
            tooltip: 'Salir',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: dests[index].builder(context),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in dests)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ATTCONTROL'),
        content: Text(
          'Esta aplicación registra la entrada y la salida del personal '
          'en el sitio de trabajo.\n\n$kAppVersionLabel',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
