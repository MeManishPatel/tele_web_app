import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TelegramUserRaw {
  final int id;
  final String firstName;
  final String? lastName;
  final String? username;
  final String? photoUrl;

  const TelegramUserRaw({
    required this.id,
    required this.firstName,
    this.lastName,
    this.username,
    this.photoUrl,
  });

  static const preview = TelegramUserRaw(
    id: 984128912,
    firstName: 'Aarav',
    lastName: 'Sharma',
    username: 'aarav_sharma',
  );
}

class TelegramMetrics {
  final bool isAvailable;
  final bool isExpanded;
  final double viewportHeight;
  final double viewportStableHeight;
  final EdgeInsets safeArea;
  final EdgeInsets contentSafeArea;
  final String platform;

  const TelegramMetrics({
    required this.isAvailable,
    required this.isExpanded,
    required this.viewportHeight,
    required this.viewportStableHeight,
    required this.safeArea,
    required this.contentSafeArea,
    required this.platform,
  });

  EdgeInsets get chromePadding => EdgeInsets.only(
        top: _max(safeArea.top, contentSafeArea.top),
        bottom: _max(safeArea.bottom, contentSafeArea.bottom),
        left: _max(safeArea.left, contentSafeArea.left),
        right: _max(safeArea.right, contentSafeArea.right),
      );

  static double _max(double a, double b) => a > b ? a : b;
}

class TelegramBridge extends ChangeNotifier {
  TelegramBridge._();
  static final TelegramBridge instance = TelegramBridge._();

  bool get isAvailable => false;
  TelegramUserRaw get user => TelegramUserRaw.preview;
  String get platform => 'preview';
  String get initData => '';
  bool get hasInitData => false;

  final EdgeInsets _safeArea = EdgeInsets.zero;
  final EdgeInsets _contentSafeArea = EdgeInsets.zero;
  final double _viewportHeight = 0;
  final double _viewportStableHeight = 0;
  final bool _isExpanded = true;

  void bootstrap() {}

  TelegramMetrics metricsFor(Size size, EdgeInsets mediaPadding) {
    final height = _viewportHeight > 0 ? _viewportHeight : size.height;
    final stable =
        _viewportStableHeight > 0 ? _viewportStableHeight : size.height;
    return TelegramMetrics(
      isAvailable: false,
      isExpanded: _isExpanded,
      viewportHeight: height,
      viewportStableHeight: stable,
      safeArea: _merge(_safeArea, mediaPadding),
      contentSafeArea: _merge(_contentSafeArea, mediaPadding),
      platform: platform,
    );
  }

  EdgeInsets _merge(EdgeInsets tg, EdgeInsets mq) {
    return EdgeInsets.only(
      top: tg.top > mq.top ? tg.top : mq.top,
      bottom: tg.bottom > mq.bottom ? tg.bottom : mq.bottom,
      left: tg.left > mq.left ? tg.left : mq.left,
      right: tg.right > mq.right ? tg.right : mq.right,
    );
  }

  void hapticImpact([String style = 'light']) {
    switch (style) {
      case 'heavy':
      case 'rigid':
        HapticFeedback.heavyImpact();
      case 'medium':
        HapticFeedback.mediumImpact();
      default:
        HapticFeedback.lightImpact();
    }
  }

  void hapticNotification([String type = 'success']) {
    HapticFeedback.mediumImpact();
  }

  void hapticSelection() {
    HapticFeedback.selectionClick();
  }

  void openTelegramLink(String url) {
    debugPrint('Opening Telegram link: $url');
  }

  void disableVerticalSwipes() {}

  void enableVerticalSwipes() {}

  void showBackButton(VoidCallback onPressed) {}

  void hideBackButton() {}

  void close() {}
}

class TelegramBackButtonObserver extends NavigatorObserver {
  void _sync() {
    final nav = navigator;
    if (nav == null) return;
    if (nav.canPop()) {
      TelegramBridge.instance.showBackButton(() => nav.maybePop());
    } else {
      TelegramBridge.instance.hideBackButton();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _sync();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _sync();
}
