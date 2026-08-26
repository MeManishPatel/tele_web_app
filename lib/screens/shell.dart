import 'package:flutter/material.dart';

import '../core/layout.dart';
import '../core/telegram/telegram_bridge.dart';
import '../core/theme.dart';
import '../state/app_store.dart';
import '../widgets/bottom_nav.dart';
import 'games_screen.dart';
import 'home_screen.dart';
import 'money_screens.dart';
import 'profile_screen.dart';
import 'spin_screen.dart';
import 'wallet_screen.dart';

class MainAppShell extends StatefulWidget {
  final AppStore store;

  const MainAppShell({super.key, required this.store});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _index = 0;

  void _goToTab(int index) {
    setState(() => _index = index);
  }

  Future<void> _openSpin() async {
    TelegramBridge.instance.hapticImpact('medium');
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpinAndWinScreen(
          wallet: widget.store.wallet,
          playSpin: widget.store.playSpin,
          onOpenHistory: _openGameHistory,
        ),
      ),
    );
  }

  void _openGameHistory() {
    TelegramBridge.instance.hapticImpact('light');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameHistoryScreen(history: widget.store.gameHistory),
      ),
    );
  }

  void _openDeposit() {
    TelegramBridge.instance.hapticImpact('medium');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DepositScreen(
          upiId: widget.store.upiId,
          onDepositSubmitted: widget.store.submitDeposit,
          onViewHistory: _openDepositHistory,
        ),
      ),
    );
  }

  void _openDepositHistory() {
    TelegramBridge.instance.hapticImpact('light');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DepositHistoryScreen(deposits: widget.store.deposits),
      ),
    );
  }

  void _openWithdraw() {
    TelegramBridge.instance.hapticImpact('medium');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WithdrawScreen(
          wallet: widget.store.wallet,
          playerName: widget.store.player.displayName,
          onWithdrawalSubmitted: widget.store.submitWithdrawal,
          onViewHistory: _openWithdrawalHistory,
        ),
      ),
    );
  }

  void _openWithdrawalHistory() {
    TelegramBridge.instance.hapticImpact('light');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            WithdrawalHistoryScreen(withdrawals: widget.store.withdrawals),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        player: widget.store.player,
        wallet: widget.store.wallet,
        onNavigateToTab: _goToTab,
        onOpenSpin: _openSpin,
        onOpenDeposit: _openDeposit,
        onOpenWithdraw: _openWithdraw,
      ),
      GamesScreen(onOpenSpinGame: _openSpin),
      WalletScreen(
        wallet: widget.store.wallet,
        transactions: widget.store.transactions,
        onOpenDeposit: _openDeposit,
        onOpenWithdraw: _openWithdraw,
        onOpenDepositHistory: _openDepositHistory,
        onOpenWithdrawHistory: _openWithdrawalHistory,
      ),
      ProfileScreen(
        player: widget.store.player,
        wallet: widget.store.wallet,
        totalSpins: widget.store.gameHistory.length,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: _index, children: screens),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TgBottomNav(index: _index, onChanged: _goToTab),
          ),
        ],
      ),
    );
  }
}

class AppStoreScope extends InheritedNotifier<AppStore> {
  const AppStoreScope({
    super.key,
    required AppStore store,
    required super.child,
  }) : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStoreScope>();
    assert(scope != null, 'AppStoreScope not found');
    return scope!.notifier!;
  }
}

class TelegramSpinWinApp extends StatefulWidget {
  const TelegramSpinWinApp({super.key});

  @override
  State<TelegramSpinWinApp> createState() => _TelegramSpinWinAppState();
}

class _TelegramSpinWinAppState extends State<TelegramSpinWinApp> {
  late final AppStore _store;
  final _backObserver = TelegramBackButtonObserver();

  @override
  void initState() {
    super.initState();
    _store = AppStore(user: TelegramBridge.instance.user);
    _store.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        return MaterialApp(
          title: 'Spin & Win',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          navigatorObservers: [_backObserver],
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: media.textScaler.clamp(maxScaleFactor: 1.2),
              ),
              child: TelegramScope(
                child: AppStoreScope(
                  store: _store,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
          home: MainAppShell(store: _store),
        );
      },
    );
  }
}
