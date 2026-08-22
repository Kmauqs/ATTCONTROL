import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  try {
    await dotenv.load(fileName: 'assets/.env', isOptional: true);
  } catch (_) {}
  if (!Env.hasSupabase) {
    try {
      await dotenv.load(fileName: '.env.example');
    } catch (_) {}
  }

  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: true,
      ),
    );
  }

  runApp(const ProviderScope(child: AttcontrolApp()));
}
