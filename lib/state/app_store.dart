import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/telegram/telegram_bridge.dart';
import '../models/models.dart';
import '../services/backend.dart';

class AppStore extends ChangeNotifier {
  AppStore({TelegramUserRaw? user}) {
    _loadPreview(user ?? TelegramBridge.instance.user);
  }

  late AppPlayer player;
  late PlayerWallet wallet;
  String upiId = 'spinwin@upi';
  bool isLive = false;
  bool isReady = true;
  String? backendMessage;

  final List<GameRoundItem> gameHistory = [];
  final List<DepositRequestItem> deposits = [];
  final List<WithdrawalRequestItem> withdrawals = [];
  final List<WalletTransactionItem> transactions = [];

  Future<void> bootstrap() async {
    final initData = TelegramBridge.instance.initData;
    if (!AppConfig.supabaseReady || initData.isEmpty) {
      isLive = false;
      isReady = true;
      backendMessage = initData.isEmpty
          ? 'Preview mode — open inside Telegram to use the live wallet.'
          : 'Supabase is not initialized.';
      notifyListeners();
      return;
    }

    try {
      await Backend.authenticateWithTelegram(initData);
      await _reloadAccount();
      isLive = true;
      backendMessage = null;
    } catch (error) {
      isLive = false;
      backendMessage = 'Live backend unavailable, using preview. $error';
      debugPrint('Supabase bootstrap failed: $error');
    }
    isReady = true;
    notifyListeners();
  }

  Future<void> _reloadAccount() async {
    await Backend.loadAccount(
      onPlayer: (value) => player = value,
      onWallet: (value) => wallet = value,
      onRounds: (value) {
        gameHistory
          ..clear()
          ..addAll(value);
      },
      onDeposits: (value) {
        deposits
          ..clear()
          ..addAll(value);
      },
      onWithdrawals: (value) {
        withdrawals
          ..clear()
          ..addAll(value);
      },
      onTransactions: (value) {
        transactions
          ..clear()
          ..addAll(value);
      },
      onUpi: (value) => upiId = value,
    );
  }

  Future<GameRoundItem> playSpin(double stake) async {
    if (!isLive) {
      final round = _localSpin(stake);
      recordGameRound(round);
      return round;
    }

    final result = await Backend.spin(stake: stake, requestId: newRequestId());
    final spin = result['spin'] is Map
        ? Map<String, dynamic>.from(result['spin'] as Map)
        : result;
    final walletRow = result['wallet'] is Map
        ? Map<String, dynamic>.from(result['wallet'] as Map)
        : null;
    if (walletRow != null) {
      wallet.availableBalance = _num(walletRow['balance']);
      wallet.pendingBalance = _num(walletRow['reserved_balance']);
    }

    final round = GameRoundItem(
      id: (spin['id'] as String?) ?? newRequestId(),
      entryAmount: _num(spin['stake'] ?? stake),
      multiplier: _num(spin['multiplier']),
      payoutAmount: _num(spin['reward']),
      winningSegment: (result['label'] as String?) ??
          (spin['metadata'] is Map
              ? (spin['metadata'] as Map)['label'] as String?
              : null) ??
          '${_num(spin['multiplier']).toStringAsFixed(1)}X',
      createdAt: DateTime.now(),
    );
    gameHistory.insert(0, round);
    wallet.gameVolume += round.entryAmount;
    notifyListeners();
    return round;
  }

  Future<void> submitDeposit(DepositRequestItem deposit) async {
    if (!isLive) {
      addDeposit(deposit);
      return;
    }
    await Backend.submitDeposit(amount: deposit.amount, utr: deposit.utr);
    await _reloadAccount();
    notifyListeners();
  }

  Future<void> submitWithdrawal(WithdrawalRequestItem withdrawal) async {
    if (!isLive) {
      addWithdrawal(withdrawal);
      return;
    }
    await Backend.submitWithdrawal(
      amount: withdrawal.amount,
      upiId: withdrawal.upiId,
    );
    await _reloadAccount();
    notifyListeners();
  }

  void recordGameRound(GameRoundItem round) {
    gameHistory.insert(0, round);
    final beforeStake = wallet.availableBalance;
    wallet.availableBalance =
        wallet.availableBalance - round.entryAmount + round.payoutAmount;
    wallet.gameVolume += round.entryAmount;

    transactions.insert(
      0,
      WalletTransactionItem(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        type: TransactionType.gameDebit,
        amount: round.entryAmount,
        balanceBefore: beforeStake,
        balanceAfter: beforeStake - round.entryAmount,
        description: 'Spin & Win round entry stake',
        createdAt: DateTime.now(),
      ),
    );

    if (round.payoutAmount > 0) {
      transactions.insert(
        0,
        WalletTransactionItem(
          id: 'tx_${DateTime.now().millisecondsSinceEpoch + 1}',
          type: TransactionType.gameCredit,
          amount: round.payoutAmount,
          balanceBefore: beforeStake - round.entryAmount,
          balanceAfter: wallet.availableBalance,
          description: 'Spin & Win ${round.winningSegment} prize won',
          createdAt: DateTime.now(),
        ),
      );
    }
    notifyListeners();
  }

  void addDeposit(DepositRequestItem deposit) {
    deposits.insert(0, deposit);
    notifyListeners();
  }

  void addWithdrawal(WithdrawalRequestItem withdrawal) {
    withdrawals.insert(0, withdrawal);
    wallet.availableBalance -= withdrawal.amount;
    wallet.pendingBalance += withdrawal.amount;
    transactions.insert(
      0,
      WalletTransactionItem(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        type: TransactionType.withdrawal,
        amount: withdrawal.amount,
        balanceBefore: wallet.availableBalance + withdrawal.amount,
        balanceAfter: wallet.availableBalance,
        description: 'Withdrawal request to UPI: ${withdrawal.upiId}',
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void _loadPreview(TelegramUserRaw user) {
    player = AppPlayer(
      id: 'usr_${user.id}',
      telegramId: user.id,
      firstName: user.firstName,
      lastName: user.lastName,
      username: user.username,
      status: AccountStatus.active,
    );
    wallet = PlayerWallet(
      id: 'wal_${user.id}',
      availableBalance: 1250,
      pendingBalance: 0,
      totalDeposited: 3500,
      totalWithdrawn: 2050,
      gameVolume: 8400,
    );
    gameHistory
      ..clear()
      ..add(
        GameRoundItem(
          id: 'rnd_994101',
          entryAmount: 50,
          multiplier: 2,
          payoutAmount: 100,
          winningSegment: '2.0X',
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
      );
    deposits
      ..clear()
      ..add(
        DepositRequestItem(
          id: 'dep_102918',
          amount: 500,
          utr: '491029182910',
          status: DepositStatus.approved,
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
      );
    withdrawals
      ..clear()
      ..add(
        WithdrawalRequestItem(
          id: 'wth_882910',
          amount: 400,
          upiId: 'aarav@okaxis',
          accountHolderName: 'Aarav Sharma',
          status: WithdrawalStatus.paid,
          paymentReference: 'UTR_771920192819',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
    transactions
      ..clear()
      ..addAll([
        WalletTransactionItem(
          id: 'tx_9812401',
          type: TransactionType.gameCredit,
          amount: 100,
          balanceBefore: 1150,
          balanceAfter: 1250,
          description: 'Spin & Win 2.0X Multiplier prize won',
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
        WalletTransactionItem(
          id: 'tx_9812400',
          type: TransactionType.gameDebit,
          amount: 50,
          balanceBefore: 1200,
          balanceAfter: 1150,
          description: 'Spin & Win round entry stake',
          createdAt: DateTime.now().subtract(const Duration(minutes: 11)),
        ),
        WalletTransactionItem(
          id: 'tx_9812398',
          type: TransactionType.deposit,
          amount: 500,
          balanceBefore: 700,
          balanceAfter: 1200,
          description: 'Verified manual UPI coin balance top-up',
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
      ]);
  }

  GameRoundItem _localSpin(double stake) {
    const segments = [
      (label: '0.5X', multiplier: 0.5, weight: 35.0),
      (label: '1.0X', multiplier: 1.0, weight: 30.0),
      (label: '1.5X', multiplier: 1.5, weight: 15.0),
      (label: '2.0X', multiplier: 2.0, weight: 10.0),
      (label: '3.0X', multiplier: 3.0, weight: 6.0),
      (label: '5.0X', multiplier: 5.0, weight: 3.0),
      (label: '10.0X', multiplier: 10.0, weight: 1.0),
    ];
    final total = segments.fold<double>(0, (sum, item) => sum + item.weight);
    var cursor = math.Random().nextDouble() * total;
    var picked = segments.last;
    for (final segment in segments) {
      cursor -= segment.weight;
      if (cursor <= 0) {
        picked = segment;
        break;
      }
    }
    return GameRoundItem(
      id: 'rnd_${DateTime.now().millisecondsSinceEpoch}',
      entryAmount: stake,
      multiplier: picked.multiplier,
      payoutAmount: stake * picked.multiplier,
      winningSegment: picked.label,
      createdAt: DateTime.now(),
    );
  }

  double _num(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}
