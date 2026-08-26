import 'package:flutter/foundation.dart';

import 'telegram/telegram_bridge.dart';

class TelegramAccess {
  TelegramAccess._();

  static bool get isAdminRoute {
    if (!kIsWeb) return false;
    final fragment = Uri.base.fragment.replaceFirst(RegExp(r'^#'), '');
    final path = Uri.base.path;
    return fragment == '/admin' ||
        fragment.startsWith('/admin') ||
        path == '/admin' ||
        path.endsWith('/admin');
  }

  /// Player Mini App must run inside Telegram. Admin dashboard may use a browser.
  static bool get requiresTelegram => kIsWeb && !isAdminRoute;

  static bool get isInsideTelegram => TelegramBridge.instance.hasInitData;
}
