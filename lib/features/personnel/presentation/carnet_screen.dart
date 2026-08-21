import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/app_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import 'profile_photo.dart';

class CarnetScreen extends ConsumerStatefulWidget {
  const CarnetScreen({super.key});

  @override
  ConsumerState<CarnetScreen> createState() => _CarnetScreenState();
}

class _CarnetScreenState extends ConsumerState<CarnetScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(authControllerProvider.notifier).refreshProfile(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    if (profile == null) return const SizedBox.shrink();
    final hasPdf = (profile.carnetPath ?? '').isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi carnet digital')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ProfilePhoto(profile: profile, radius: 52),
                  const SizedBox(height: 16),
                  Text(
                    profile.fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${profile.documento} · ${profile.rol.label}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  if ((profile.cargo ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(profile.cargo!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: hasPdf
                ? () async {
                    final url = await ref
                        .read(appRepositoryProvider)
                        .signedFileUrl(profile.carnetPath);
                    if (url == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No se pudo abrir el carnet. Intenta con internet.',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    final uri = Uri.parse(url);
                    final ok = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No hay visor de PDF en este teléfono',
                          ),
                        ),
                      );
                    }
                  }
                : null,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(
              hasPdf ? 'Ver carnet en PDF' : 'Aún no hay carnet cargado',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasPdf
                ? 'El archivo se abre con el visor de PDF del teléfono.'
                : 'Pide a un supervisor o administrador que cargue tu carnet '
                    'desde la ficha de personal.',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          const Text(
            'Solo tú, los supervisores y los administradores pueden ver '
            'esta información.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
