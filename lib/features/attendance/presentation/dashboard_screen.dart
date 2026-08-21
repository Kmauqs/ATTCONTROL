import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/app_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/attendance_models.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _busy = false;
  String? _feedback;
  bool _ok = true;
  AttendanceLog? _last;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) return;
    final repo = ref.read(appRepositoryProvider);
    await repo.syncPending();
    final last = await repo.lastToday(profile.id);
    if (mounted) setState(() => _last = last);
  }

  Future<void> _punch() async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) return;
    setState(() => _busy = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw Exception('Activa el GPS para fichar');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('La ubicación es obligatoria para el fichaje');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final result = await ref.read(appRepositoryProvider).punch(
            actor: profile,
            target: profile,
            lat: pos.latitude,
            lng: pos.longitude,
          );
      if (result.ok) {
        await hapticOk();
      } else {
        await hapticBad();
      }
      setState(() {
        _feedback = result.message;
        _ok = result.ok;
        _last = result.log;
      });
    } catch (e) {
      await hapticBad();
      setState(() {
        _ok = false;
        _feedback = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    if (profile == null) return const SizedBox.shrink();
    final nextIsIn = _last == null || _last!.kind == 'salida';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _Header(profile: profile),
          const SizedBox(height: 20),
          _PunchCard(
            nextIsIn: nextIsIn,
            busy: _busy,
            last: _last,
            onPunch: _punch,
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 12),
            _Banner(text: _feedback!, ok: _ok),
          ],
          if (profile.rol.canScanQr) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/qr'),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear QR de carnet'),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Hoy',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _TodaySummary(last: _last),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.forest,
          child: Text(
            profile.initials,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Text(
                '${profile.rol.label} · ${profile.cargo ?? ''}',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PunchCard extends StatelessWidget {
  const _PunchCard({
    required this.nextIsIn,
    required this.busy,
    required this.onPunch,
    this.last,
  });

  final bool nextIsIn;
  final bool busy;
  final VoidCallback onPunch;
  final AttendanceLog? last;

  @override
  Widget build(BuildContext context) {
    final color = nextIsIn ? AppColors.forest : const Color(0xFF1565C0);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            DateFormat("EEEE d 'de' MMMM", 'es').format(DateTime.now()),
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('HH:mm').format(DateTime.now()),
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 168,
            width: 168,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: color,
                shape: const CircleBorder(),
              ),
              onPressed: busy ? null : onPunch,
              child: busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          nextIsIn ? Icons.login : Icons.logout,
                          size: 42,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          nextIsIn ? 'ENTRADA' : 'SALIDA',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Text('1 toque', style: TextStyle(fontSize: 12)),
                      ],
                    ),
            ),
          ),
          if (last != null) ...[
            const SizedBox(height: 12),
            Text(
              'Última marca: ${last!.kind} · ${DateFormat('HH:mm').format(last!.markedAt)}',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.ok});
  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (ok ? AppColors.ok : AppColors.late).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: ok ? AppColors.ok : AppColors.late,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({this.last});
  final AttendanceLog? last;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          last == null
              ? Icons.timelapse
              : last!.kind == 'entrada'
                  ? Icons.check_circle
                  : Icons.home_outlined,
          color: AppColors.forest,
        ),
        title: Text(
          last == null
              ? 'Aún no hay marcas hoy'
              : last!.kind == 'entrada'
                  ? 'En sitio desde ${DateFormat('HH:mm').format(last!.markedAt)}'
                  : 'Jornada cerrada a las ${DateFormat('HH:mm').format(last!.markedAt)}',
        ),
        subtitle: last == null
            ? const Text('Toca el botón para registrar entrada')
            : Text('Estado: ${last!.status.replaceAll('_', ' ')}'),
      ),
    );
  }
}
