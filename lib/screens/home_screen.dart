import 'package:flutter/material.dart';

import '../core/layout.dart';
import '../core/telegram/telegram_bridge.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  final AppPlayer player;
  final PlayerWallet wallet;
  final ValueChanged<int> onNavigateToTab;
  final VoidCallback onOpenSpin;
  final VoidCallback onOpenDeposit;
  final VoidCallback onOpenWithdraw;
  final bool telegramSignedIn;

  const HomeScreen({
    super.key,
    required this.player,
    required this.wallet,
    required this.onNavigateToTab,
    required this.onOpenSpin,
    required this.onOpenDeposit,
    required this.onOpenWithdraw,
    this.telegramSignedIn = false,
  });

  @override
  Widget build(BuildContext context) {
    final compact = TgLayout.isCompact(context);
    return TgScrollView(
      children: [
        _Header(
          player: player,
          wallet: wallet,
          signedIn: telegramSignedIn,
          onWalletTap: () => onNavigateToTab(2),
        ),
        const SizedBox(height: 16),
        GlassCard(
          goldBorder: true,
          gradient: AppColors.cardGradient,
          padding: EdgeInsets.all(compact ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'AVAILABLE BALANCE',
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
                    Icons.shield_outlined,
                    size: 16,
                    color: AppColors.primaryGold,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AmountText(
                amount: wallet.availableBalance,
                fontSize: compact ? 28 : 34,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GoldButton(
                      label: 'Deposit',
                      icon: Icons.add_rounded,
                      onPressed: onOpenDeposit,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GhostButton(
                      label: 'Withdraw',
                      icon: Icons.arrow_outward_rounded,
                      onPressed: onOpenWithdraw,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                label: 'Deposit',
                icon: Icons.south_west_rounded,
                onTap: onOpenDeposit,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionTile(
                label: 'Withdraw',
                icon: Icons.north_east_rounded,
                onTap: onOpenWithdraw,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionTile(
                label: 'Spin',
                icon: Icons.casino_rounded,
                onTap: onOpenSpin,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionTile(
                label: 'Ledger',
                icon: Icons.receipt_long_rounded,
                onTap: () => onNavigateToTab(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        SectionLabel(
          'FEATURED GAME',
          action: 'View Catalog',
          onAction: () => onNavigateToTab(1),
        ),
        const SizedBox(height: 10),
        GlassCard(
          goldBorder: true,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: compact ? 46 : 54,
                    height: compact ? 46 : 54,
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGold.withValues(alpha: 0.35),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.casino, color: Colors.black, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Flexible(
                              child: Text(
                                'Spin & Win Wheel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const StatusBadge(
                              label: 'ACTIVE',
                              color: AppColors.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Dynamic multiplier payouts up to 10.0X',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GoldButton(
                label: 'Launch Spin & Win',
                onPressed: onOpenSpin,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final AppPlayer player;
  final PlayerWallet wallet;
  final bool signedIn;
  final VoidCallback onWalletTap;

  const _Header({
    required this.player,
    required this.wallet,
    required this.signedIn,
    required this.onWalletTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PlayerAvatar(
          initial: player.initial,
          photoUrl: player.photoUrl,
          radius: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, ${player.firstName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                player.handle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              if (signedIn)
                const Text(
                  'Telegram signed in',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
            ],
          ),
        ),
        InkWell(
          onTap: onWalletTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorderGold),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  size: 14,
                  color: AppColors.primaryGold,
                ),
                const SizedBox(width: 6),
                Text(
                  '₹ ${wallet.availableBalance.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGoldBright,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        TelegramBridge.instance.hapticSelection();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryGold),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
