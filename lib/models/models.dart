import 'package:flutter/material.dart';

enum AccountStatus { active, suspended, blocked }

enum DepositStatus { pending, approved, rejected }

enum WithdrawalStatus { pending, processing, paid, rejected }

enum TransactionType {
  deposit,
  withdrawal,
  gameDebit,
  gameCredit,
  refund,
  bonus,
}

class AppPlayer {
  final String id;
  final int telegramId;
  final String firstName;
  final String? lastName;
  final String? username;
  final AccountStatus status;

  const AppPlayer({
    required this.id,
    required this.telegramId,
    required this.firstName,
    this.lastName,
    this.username,
    required this.status,
  });

  String get displayName => '$firstName ${lastName ?? ''}'.trim();

  String get handle =>
      username != null ? '@$username' : 'ID: $telegramId';

  String get initial {
    if (firstName.isEmpty) return 'P';
    return firstName[0].toUpperCase();
  }
}

class PlayerWallet {
  final String id;
  double availableBalance;
  double pendingBalance;
  double totalDeposited;
  double totalWithdrawn;
  double gameVolume;

  PlayerWallet({
    required this.id,
    required this.availableBalance,
    required this.pendingBalance,
    required this.totalDeposited,
    required this.totalWithdrawn,
    required this.gameVolume,
  });
}

class WheelSegment {
  final String label;
  final double multiplier;
  final double weight;
  final Color color;

  const WheelSegment({
    required this.label,
    required this.multiplier,
    required this.weight,
    required this.color,
  });
}

class GameRoundItem {
  final String id;
  final double entryAmount;
  final double multiplier;
  final double payoutAmount;
  final String winningSegment;
  final DateTime createdAt;

  const GameRoundItem({
    required this.id,
    required this.entryAmount,
    required this.multiplier,
    required this.payoutAmount,
    required this.winningSegment,
    required this.createdAt,
  });

  bool get isWin => payoutAmount > entryAmount;
}

class DepositRequestItem {
  final String id;
  final double amount;
  final String utr;
  final DepositStatus status;
  final DateTime createdAt;

  const DepositRequestItem({
    required this.id,
    required this.amount,
    required this.utr,
    required this.status,
    required this.createdAt,
  });
}

class WithdrawalRequestItem {
  final String id;
  final double amount;
  final String upiId;
  final String accountHolderName;
  final WithdrawalStatus status;
  final String? paymentReference;
  final DateTime createdAt;

  const WithdrawalRequestItem({
    required this.id,
    required this.amount,
    required this.upiId,
    required this.accountHolderName,
    required this.status,
    this.paymentReference,
    required this.createdAt,
  });
}

class WalletTransactionItem {
  final String id;
  final TransactionType type;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String description;
  final DateTime createdAt;

  const WalletTransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.description,
    required this.createdAt,
  });

  bool get isCredit =>
      type == TransactionType.deposit ||
      type == TransactionType.gameCredit ||
      type == TransactionType.refund ||
      type == TransactionType.bonus;

  String get displayTitle {
    switch (type) {
      case TransactionType.deposit:
        return 'UPI Coin Deposit';
      case TransactionType.withdrawal:
        return 'Withdrawal Payout';
      case TransactionType.gameDebit:
        return 'Spin & Win Stake';
      case TransactionType.gameCredit:
        return 'Spin & Win Prize';
      case TransactionType.refund:
        return 'Withdrawal Refund';
      case TransactionType.bonus:
        return 'Welcome Bonus';
    }
  }

  IconData get icon {
    switch (type) {
      case TransactionType.deposit:
        return Icons.south_west_rounded;
      case TransactionType.withdrawal:
        return Icons.north_east_rounded;
      case TransactionType.gameDebit:
        return Icons.casino_outlined;
      case TransactionType.gameCredit:
        return Icons.emoji_events_rounded;
      case TransactionType.refund:
        return Icons.replay_rounded;
      case TransactionType.bonus:
        return Icons.card_giftcard_rounded;
    }
  }
}
