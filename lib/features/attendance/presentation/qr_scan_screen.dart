import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/app_repository.dart';
import '../../auth/presentation/auth_controller.dart';

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  bool _handled = false;
  String? _message;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (raw == null || raw.trim().isEmpty) return;
    _handled = true;
    final actor = ref.read(authControllerProvider).profile;
    if (actor == null) return;
    try {
      final target =
          await ref.read(appRepositoryProvider).findProfile(raw.trim());
      if (target == null) {
        setState(() => _message = 'Documento $raw no está en la base');
        _handled = false;
        return;
      }
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _message = 'GPS obligatorio para fichar');
        _handled = false;
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final result = await ref.read(appRepositoryProvider).punch(
            actor: actor,
            target: target,
            lat: pos.latitude,
            lng: pos.longitude,
            source: 'qr',
          );
      if (!mounted) return;
      await hapticOk();
      if (!mounted) return;
      Navigator.of(context).pop(result.message);
    } catch (e) {
      setState(() {
        _message = e.toString();
        _handled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear carnet')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'El QR del carnet debe contener el número de documento.',
            ),
          ),
          Expanded(
            child: MobileScanner(onDetect: _onDetect),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _message!,
                style: const TextStyle(color: AppColors.late),
              ),
            ),
        ],
      ),
    );
  }
}
