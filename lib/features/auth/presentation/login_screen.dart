import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_version.dart';
import '../../../core/config/env.dart';
import '../../../core/theme/app_theme.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _id = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _id.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.forestDark, AppColors.forest, Color(0xFF2E7D4F)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            children: [
              const SizedBox(height: 12),
              Center(
                child: Image.asset(
                  'assets/branding/icon_256.png',
                  width: 148,
                  height: 148,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Asistencia de personal',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mint, letterSpacing: 1.2),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _id,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Documento o correo',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      obscureText: _obscure,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        auth.error!,
                        style: const TextStyle(color: AppColors.late),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: auth.loading ? null : _submit,
                      child: auth.loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Entrar'),
                    ),
                    if (auth.biometricsAvailable && auth.hasStoredSession) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => ref
                            .read(authControllerProvider.notifier)
                            .loginWithBiometrics(),
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Entrar con biometría'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      Env.hasSupabase
                          ? 'La sesión permanece activa 7 días. '
                              'Usa la contraseña asignada por tu supervisor.'
                          : 'Modo local de demostración. Clave inicial: ${Env.seedPassword}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                kAppVersionLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    await ref.read(authControllerProvider.notifier).login(
          _id.text.trim(),
          _pass.text,
        );
  }
}
