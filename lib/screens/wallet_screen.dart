import 'package:flutter/material.dart';

import '../core/layout.dart';
import '../core/telegram/telegram_bridge.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class WalletScreen extends StatefulWidget {
  final PlayerWallet wallet;
  final List<WalletTransactionItem> transactions;
  final VoidCallback onOpenDeposit;
  final VoidCallback onOpenWithdraw;
  final VoidCallback onOpenDepositHistory;
  final VoidCallback onOpenWithdrawHistory;

  const WalletScreen({
    super.key,
    required this.wallet,
    required this.transactions,
    required this.onOpenDeposit,
    required this.onOpenWithdraw,
    required this.onOpenDepositHistory,
    required this.onOpenWithdrawHistory,
  });

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String _filter = 'All';

  List<WalletTransactionItem> get _filtered {
    switch (_filter) {
      case 'Deposits':
        return widget.transactions
            .where((t) => t.type == TransactionType.deposit)
            .toList();
      case 'Payouts':
        return widget.transactions
            .where((t) => t.type == TransactionType.withdrawal)
            .toList();
      case 'Wins':
        return widget.transactions
            .where((t) => t.type == TransactionType.gameCredit)
            .toList();
      case 'Stakes':
        return widget.transactions
            .where((t) => t.type == TransactionType.gameDebit)
            .toList();
      default:
        return widget.transactions;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TgScrollView(
      children: [
        const ScreenTitle(
          title: 'Master Wallet & Ledger',
          subtitle:
              'Inspect platform reserves, pending balances and immutable audit history.',
        ),
        const SizedBox(height: 16),
        GlassCard(
          goldBorder: true,
          gradient: AppColors.cardGradient,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'AVAILABLE COIN BALANCE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 18,
                    color: AppColors.primaryGold,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AmountText(amount: widget.wallet.availableBalance),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pending Payouts In-Transit',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '₹ ${widget.wallet.pendingBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GoldButton(
                      label: 'Deposit',
                      icon: Icons.add_rounded,
                      onPressed: widget.onOpenDeposit,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GhostButton(
                      label: 'Withdraw',
                      icon: Icons.arrow_outward_rounded,
                      onPressed: widget.onOpenWithdraw,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _HistoryTile(
                icon: Icons.history_edu_rounded,
                title: 'Deposit Slips',
                color: AppColors.success,
                onTap: widget.onOpenDepositHistory,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HistoryTile(
                icon: Icons.receipt_long_rounded,
                title: 'Payouts',
                color: AppColors.error,
                onTap: widget.onOpenWithdrawHistory,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  'DEPOSITED',
                  widget.wallet.totalDeposited,
                  AppColors.success,
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  'WITHDRAWN',
                  widget.wallet.totalWithdrawn,
                  AppColors.error,
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  'VOLUME',
                  widget.wallet.gameVolume,
                  AppColors.primaryGoldBright,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final label in ['All', 'Deposits', 'Payouts', 'Wins', 'Stakes'])
                _FilterChip(
                  label: label,
                  selected: _filter == label,
                  onTap: () => setState(() => _filter = label),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No transactions in this view.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _filtered.length; i++) ...[
                  if (i > 0)
                    const Divider(color: AppColors.glassBorder, height: 1),
                  _TxTile(
                    tx: _filtered[i],
                    onTap: () => _showDetails(_filtered[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  void _showDetails(WalletTransactionItem tx) {
    showTgSheet(
      context: context,
      builder: (_) => TgSheetScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tx.displayTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Amount: ₹${tx.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGoldBright,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Balance: ₹${tx.balanceBefore.toStringAsFixed(2)} → ₹${tx.balanceAfter.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 6),
            Text('Description: ${tx.description}'),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _HistoryTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        TelegramBridge.instance.hapticSelection();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String title;
  final double value;
  final Color color;

  const _SummaryStat(this.title, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '₹ ${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.primaryGold,
        backgroundColor: AppColors.surfaceElevated,
        labelStyle: TextStyle(
          color: selected ? Colors.black : AppColors.textSecondary,
          fontSize: 11,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: selected ? AppColors.primaryGold : AppColors.glassBorder,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final WalletTransactionItem tx;
  final VoidCallback onTap;

  const _TxTile({required this.tx, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: tx.isCredit ? AppColors.successBg : AppColors.errorBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                tx.icon,
                size: 16,
                color: tx.isCredit ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tx.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${tx.isCredit ? '+' : '-'} ₹${tx.amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: tx.isCredit ? AppColors.success : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
