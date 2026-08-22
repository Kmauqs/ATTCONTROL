import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/config/env.dart';
import '../../../core/models/models.dart';
import '../../../core/utils/session.dart';
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
  static const _kSession = 'session';
  static const _kRefresh = 'refresh_token';
  static const _kLoggedAt = 'logged_at';

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
    final stored = await _storage.read(key: _kSession);
    final refresh = await _storage.read(key: _kRefresh);
    final loggedAtRaw = await _storage.read(key: _kLoggedAt);
    var loggedAt = DateTime.tryParse(loggedAtRaw ?? '');
    if (stored != null && loggedAt == null) {
      loggedAt = DateTime.now().toUtc();
      await _storage.write(key: _kLoggedAt, value: loggedAt.toIso8601String());
    }
    final withinTtl =
        loggedAt != null && sessionStillValid(loggedAt, DateTime.now());

    if (stored != null && loggedAt != null && !withinTtl) {
      await _clearStoredSession();
      state = state.copyWith(
        bootstrapping: false,
        biometricsAvailable: bio,
        hasStoredSession: false,
      );
      return;
    }

    if (withinTtl && stored != null) {
      final restored = await _restoreSession(
        stored: stored,
        refresh: refresh,
      );
      if (restored) return;
    }

    final supabaseSession = _repo.supabase?.auth.currentSession;
    state = state.copyWith(
      bootstrapping: false,
      biometricsAvailable: bio,
      hasStoredSession: stored != null &&
          withinTtl &&
          (!Env.hasSupabase || refresh != null || supabaseSession != null),
    );
  }

  Future<bool> _restoreSession({
    required String stored,
    String? refresh,
  }) async {
    try {
      if (Env.hasSupabase) {
        final client = _repo.supabase;
        if (client == null) return false;
        var session = client.auth.currentSession;
        if (session == null) {
          if (refresh == null || refresh.isEmpty) return false;
          final result = await client.auth.setSession(refresh);
          session = result.session;
        }
        if (session == null) return false;
        final token = session.refreshToken;
        if (token != null && token.isNotEmpty) {
          await _storage.write(key: _kRefresh, value: token);
        }
        final profile = await _repo.profileById(session.user.id);
        if (profile == null) return false;
        await _persist(profile, renewTtl: false);
        state = state.copyWith(
          profile: profile,
          bootstrapping: false,
          hasStoredSession: true,
        );
        return true;
      }
      final map = jsonDecode(stored) as Map<String, dynamic>;
      state = state.copyWith(
        profile: UserProfile.fromMap(map),
        bootstrapping: false,
        hasStoredSession: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persist(UserProfile profile, {bool renewTtl = true}) async {
    await _storage.write(
      key: _kSession,
      value: jsonEncode(profile.toMap()),
    );
    final refresh = _repo.supabase?.auth.currentSession?.refreshToken;
    if (refresh != null && refresh.isNotEmpty) {
      await _storage.write(key: _kRefresh, value: refresh);
    }
    if (renewTtl) {
      await _storage.write(
        key: _kLoggedAt,
        value: DateTime.now().toUtc().toIso8601String(),
      );
    }
  }

  Future<void> _clearStoredSession() async {
    await _storage.delete(key: _kSession);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kLoggedAt);
  }

  Future<void> login(String identifier, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final profile = Env.hasSupabase
          ? await _repo.loginRemote(identifier, password)
          : await _repo.loginLocal(identifier, password);
      await _persist(profile);
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
    final stored = await _storage.read(key: _kSession);
    if (stored == null) return false;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Confirma tu identidad para entrar a ATTCONTROL',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (!ok) return false;

      if (Env.hasSupabase) {
        final client = _repo.supabase;
        if (client == null) return false;
        var session = client.auth.currentSession;
        if (session == null) {
          final refresh = await _storage.read(key: _kRefresh);
          if (refresh == null || refresh.isEmpty) return false;
          final restored = await client.auth.setSession(refresh);
          session = restored.session;
        }
        if (session == null) return false;
        final token = session.refreshToken;
        if (token != null && token.isNotEmpty) {
          await _storage.write(key: _kRefresh, value: token);
        }
        final profile = await _repo.profileById(session.user.id);
        if (profile == null) return false;
        await _persist(profile, renewTtl: false);
        state = state.copyWith(profile: profile, hasStoredSession: true);
        return true;
      }

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
    await _clearStoredSession();
    state = state.copyWith(clearProfile: true, hasStoredSession: false);
  }

  Future<void> refreshProfile() async {
    final current = state.profile;
    if (current == null) return;
    final fresh = await _repo.profileById(current.id);
    if (fresh == null) return;
    await _persist(fresh, renewTtl: false);
    state = state.copyWith(profile: fresh);
  }
}

Future<void> hapticOk() => HapticFeedback.mediumImpact();
Future<void> hapticBad() => HapticFeedback.heavyImpact();
