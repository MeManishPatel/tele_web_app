import 'dart:js_interop';
import 'dart:js_interop_unsafe';

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

  JSObject? _app;
  JSFunction? _viewportHandler;
  JSFunction? _safeAreaHandler;
  JSFunction? _contentSafeHandler;
  JSFunction? _backHandlerJs;
  VoidCallback? _backHandler;

  EdgeInsets _safeArea = EdgeInsets.zero;
  EdgeInsets _contentSafeArea = EdgeInsets.zero;
  double _viewportHeight = 0;
  double _viewportStableHeight = 0;
  bool _isExpanded = true;
  String _platform = 'web';

  bool get isAvailable => _app != null;

  TelegramUserRaw get user => _readUser();

  String get platform => _platform;

  String get initData {
    final app = _app;
    if (app == null) return '';
    return _readString(app, 'initData', '');
  }

  bool get hasInitData => initData.isNotEmpty;

  void bootstrap() {
    _app = _locateWebApp();
    final app = _app;
    if (app == null) return;

    try {
      app.callMethod('ready'.toJS);
      app.callMethod('expand'.toJS);
      app.callMethod('setHeaderColor'.toJS, '#07080A'.toJS);
      app.callMethod('setBackgroundColor'.toJS, '#07080A'.toJS);
    } catch (error) {
      debugPrint('Telegram ready/expand failed: $error');
    }

    try {
      app.callMethod('disableVerticalSwipes'.toJS);
    } catch (_) {}

    _platform = _readString(app, 'platform', 'web');
    _syncFromJs();

    _viewportHandler = ((JSAny? _) {
      _syncFromJs();
    }).toJS;
    _safeAreaHandler = ((JSAny? _) {
      _syncFromJs();
    }).toJS;
    _contentSafeHandler = ((JSAny? _) {
      _syncFromJs();
    }).toJS;

    try {
      app.callMethod('onEvent'.toJS, 'viewportChanged'.toJS, _viewportHandler);
      app.callMethod('onEvent'.toJS, 'safeAreaChanged'.toJS, _safeAreaHandler);
      app.callMethod(
        'onEvent'.toJS,
        'contentSafeAreaChanged'.toJS,
        _contentSafeHandler,
      );
    } catch (error) {
      debugPrint('Telegram event bind failed: $error');
    }
  }

  TelegramMetrics metricsFor(Size size, EdgeInsets mediaPadding) {
    final height = _viewportHeight > 0 ? _viewportHeight : size.height;
    final stable =
        _viewportStableHeight > 0 ? _viewportStableHeight : size.height;
    return TelegramMetrics(
      isAvailable: isAvailable,
      isExpanded: _isExpanded,
      viewportHeight: height,
      viewportStableHeight: stable,
      safeArea: _merge(_safeArea, mediaPadding),
      contentSafeArea: _merge(_contentSafeArea, mediaPadding),
      platform: _platform,
    );
  }

  void hapticImpact([String style = 'light']) {
    if (!_callHaptic('impactOccurred', style)) {
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
  }

  void hapticNotification([String type = 'success']) {
    if (!_callHaptic('notificationOccurred', type)) {
      HapticFeedback.mediumImpact();
    }
  }

  void hapticSelection() {
    if (!_callHaptic('selectionChanged', null)) {
      HapticFeedback.selectionClick();
    }
  }

  void openTelegramLink(String url) {
    final app = _app;
    if (app == null) {
      debugPrint('Opening Telegram link: $url');
      return;
    }
    try {
      app.callMethod('openTelegramLink'.toJS, url.toJS);
    } catch (error) {
      debugPrint('openTelegramLink failed: $error');
    }
  }

  void disableVerticalSwipes() {
    try {
      _app?.callMethod('disableVerticalSwipes'.toJS);
    } catch (_) {}
  }

  void enableVerticalSwipes() {
    try {
      _app?.callMethod('enableVerticalSwipes'.toJS);
    } catch (_) {}
  }

  void showBackButton(VoidCallback onPressed) {
    _backHandler = onPressed;
    final app = _app;
    if (app == null) return;
    try {
      final back = app['BackButton'];
      if (back == null) return;
      final button = back as JSObject;
      if (_backHandlerJs != null) {
        button.callMethod('offClick'.toJS, _backHandlerJs);
      }
      _backHandlerJs = ((JSAny? _) {
        _backHandler?.call();
      }).toJS;
      button.callMethod('onClick'.toJS, _backHandlerJs);
      button.callMethod('show'.toJS);
    } catch (error) {
      debugPrint('Telegram BackButton show failed: $error');
    }
  }

  void hideBackButton() {
    _backHandler = null;
    final app = _app;
    if (app == null) return;
    try {
      final back = app['BackButton'];
      if (back == null) return;
      final button = back as JSObject;
      if (_backHandlerJs != null) {
        button.callMethod('offClick'.toJS, _backHandlerJs);
        _backHandlerJs = null;
      }
      button.callMethod('hide'.toJS);
    } catch (_) {}
  }

  void close() {
    try {
      _app?.callMethod('close'.toJS);
    } catch (_) {}
  }

  JSObject? _locateWebApp() {
    try {
      if (!globalContext.has('Telegram')) return null;
      final telegram = globalContext['Telegram'];
      if (telegram == null) return null;
      final obj = telegram as JSObject;
      if (!obj.has('WebApp')) return null;
      final webApp = obj['WebApp'];
      if (webApp == null) return null;
      return webApp as JSObject;
    } catch (_) {
      return null;
    }
  }

  void _syncFromJs() {
    final app = _app;
    if (app == null) return;
    _viewportHeight = _readDouble(app, 'viewportHeight', _viewportHeight);
    _viewportStableHeight =
        _readDouble(app, 'viewportStableHeight', _viewportStableHeight);
    _isExpanded = _readBool(app, 'isExpanded', _isExpanded);
    _safeArea = _readInset(app, 'safeAreaInset');
    _contentSafeArea = _readInset(app, 'contentSafeAreaInset');
    notifyListeners();
  }

  TelegramUserRaw _readUser() {
    final app = _app;
    if (app == null) return TelegramUserRaw.preview;
    try {
      final unsafe = app['initDataUnsafe'];
      if (unsafe == null) return TelegramUserRaw.preview;
      final data = unsafe as JSObject;
      final userAny = data['user'];
      if (userAny == null) return TelegramUserRaw.preview;
      final user = userAny as JSObject;
      final id = _readInt(user, 'id', TelegramUserRaw.preview.id);
      final firstName = _readString(user, 'first_name', 'Player');
      return TelegramUserRaw(
        id: id,
        firstName: firstName.isEmpty ? 'Player' : firstName,
        lastName: _readOptString(user, 'last_name'),
        username: _readOptString(user, 'username'),
        photoUrl: _readOptString(user, 'photo_url'),
      );
    } catch (_) {
      return TelegramUserRaw.preview;
    }
  }

  bool _callHaptic(String method, String? arg) {
    final app = _app;
    if (app == null) return false;
    try {
      final haptic = app['HapticFeedback'];
      if (haptic == null) return false;
      final obj = haptic as JSObject;
      if (arg == null) {
        obj.callMethod(method.toJS);
      } else {
        obj.callMethod(method.toJS, arg.toJS);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  EdgeInsets _merge(EdgeInsets tg, EdgeInsets mq) {
    return EdgeInsets.only(
      top: tg.top > mq.top ? tg.top : mq.top,
      bottom: tg.bottom > mq.bottom ? tg.bottom : mq.bottom,
      left: tg.left > mq.left ? tg.left : mq.left,
      right: tg.right > mq.right ? tg.right : mq.right,
    );
  }

  double _readDouble(JSObject object, String key, double fallback) {
    try {
      if (!object.has(key)) return fallback;
      final value = object[key];
      if (value == null) return fallback;
      return (value as JSNumber).toDartDouble;
    } catch (_) {
      return fallback;
    }
  }

  int _readInt(JSObject object, String key, int fallback) {
    try {
      if (!object.has(key)) return fallback;
      final value = object[key];
      if (value == null) return fallback;
      return (value as JSNumber).toDartInt;
    } catch (_) {
      return fallback;
    }
  }

  bool _readBool(JSObject object, String key, bool fallback) {
    try {
      if (!object.has(key)) return fallback;
      final value = object[key];
      if (value == null) return fallback;
      return (value as JSBoolean).toDart;
    } catch (_) {
      return fallback;
    }
  }

  String _readString(JSObject object, String key, String fallback) {
    try {
      if (!object.has(key)) return fallback;
      final value = object[key];
      if (value == null) return fallback;
      return (value as JSString).toDart;
    } catch (_) {
      return fallback;
    }
  }

  String? _readOptString(JSObject object, String key) {
    try {
      if (!object.has(key)) return null;
      final value = object[key];
      if (value == null) return null;
      final text = (value as JSString).toDart;
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  EdgeInsets _readInset(JSObject object, String key) {
    try {
      if (!object.has(key)) return EdgeInsets.zero;
      final insetAny = object[key];
      if (insetAny == null) return EdgeInsets.zero;
      final inset = insetAny as JSObject;
      return EdgeInsets.fromLTRB(
        _readDouble(inset, 'left', 0),
        _readDouble(inset, 'top', 0),
        _readDouble(inset, 'right', 0),
        _readDouble(inset, 'bottom', 0),
      );
    } catch (_) {
      return EdgeInsets.zero;
    }
  }
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
