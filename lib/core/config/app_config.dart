import 'package:supabase_flutter/supabase_flutter.dart';

/// Public client config only. Bot token and DB password stay on the server.
class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wjkoykwxemprfujbcozr.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indqa295a3d4ZW1wcmZ1amJjb3pyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc1NzA1MTEsImV4cCI6MjEwMzE0NjUxMX0.t2beO0lrohcJh6KhfLW1SdxRNd9imPRCeTiS4q-ftm8',
  );

  static bool supabaseReady = false;

  static Future<void> initSupabase() async {
    if (supabaseReady) return;
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        detectSessionInUri: false,
      ),
    );
    supabaseReady = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
}
