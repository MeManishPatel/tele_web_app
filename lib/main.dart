import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/telegram/telegram_bridge.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TelegramBridge.instance.bootstrap();
  try {
    await AppConfig.initSupabase();
  } catch (error) {
    debugPrint('Supabase init failed: $error');
  }
  runApp(const TelegramSpinWinApp());
}
