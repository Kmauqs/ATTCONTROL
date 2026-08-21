import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ??
      const String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static bool get hasSupabase {
    final url = supabaseUrl.trim();
    final key = supabaseAnonKey.trim();
    return url.startsWith('http') &&
        !url.contains('YOUR_PROJECT') &&
        key.isNotEmpty &&
        key != 'your_publishable_or_anon_key';
  }

  static const seedPassword = 'AttControl2026!';
}

Map<String, dynamic>? decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    final normalized = base64Url.normalize(parts[1]);
    return jsonDecode(utf8.decode(base64Url.decode(normalized)))
        as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}
