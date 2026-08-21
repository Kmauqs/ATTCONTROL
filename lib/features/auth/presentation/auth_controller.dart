import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/config/env.dart';
import '../../../core/models/models.dart';
import '../../../data/app_repository.dart';

class AuthState {
  const AuthState({
    this.profile,
    this.loading = false,
    this.bootstrapping = true,
    this.error,
    this.biometricsAvailable = false,
    this.hasStoredSession = false,
  });

  final UserProfile? profile;
  final bool loading;
  final bool bootstrapping;
  final String? error;
  final bool biometricsAvailable;
  final bool hasStoredSession;

  bool get isLoggedIn => profile != null;

  AuthState copyWith({
    UserProfile? profile,
    bool? loading,
    bool? bootstrapping,
    String? error,
    bool? biometricsAvailable,
    bool? hasStoredSession,
    bool clearProfile = false,
    bool clearError = false,
  }) {
    return AuthState(
      profile: clearProfile ? null : (profile ?? this.profile),
      loading: loading ?? this.loading,
      bootstrapping: bootstrapping ?? this.bootstrapping,
      error: clearError ? null : (error ?? this.error),
      biometricsAvailable: biometricsAvailable ?? this.biometricsAvailable,
      hasStoredSession: hasStoredSession ?? this.hasStoredSession,
    );
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  final _storage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  AppRepository get _repo => ref.read(appRepositoryProvider);

  @override
  AuthState build() {
    Future.microtask(restore);
    return const AuthState();
  }

  Future<void> restore() async {
    final bio = await _auth.isDeviceSupported();
    final stored = await _storage.read(key: 'session');
    state = state.copyWith(
      bootstrapping: false,
      biometricsAvailable: bio,
      hasStoredSession: stored != null,
    );
  }

  Future<void> login(String identifier, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final profile = Env.hasSupabase
          ? await _repo.loginRemote(identifier, password)
          : await _repo.loginLocal(identifier, password);
      await _storage.write(
        key: 'session',
        value: jsonEncode(profile.toMap()),
      );
      state = state.copyWith(
        profile: profile,
        loading: false,
        hasStoredSession: true,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<bool> loginWithBiometrics() async {
    final stored = await _storage.read(key: 'session');
    if (stored == null) return false;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Confirma tu identidad para entrar a ATTCONTROL',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (!ok) return false;
      final map = jsonDecode(stored) as Map<String, dynamic>;
      state = state.copyWith(profile: UserProfile.fromMap(map));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    if (Env.hasSupabase) {
      try {
        await _repo.supabase?.auth.signOut();
      } catch (_) {}
    }
    await _storage.delete(key: 'session');
    state = state.copyWith(clearProfile: true, hasStoredSession: false);
  }
}

Future<void> hapticOk() => HapticFeedback.mediumImpact();
Future<void> hapticBad() => HapticFeedback.heavyImpact();
