import 'package:flutter/material.dart';

import '../core/layout.dart';
import '../core/telegram/telegram_bridge.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'money_screens.dart';

class ProfileScreen extends StatelessWidget {
  final AppPlayer player;
  final PlayerWallet wallet;
  final int totalSpins;
  final bool signedIn;
  final Future<void> Function()? onSignOut;

  const ProfileScreen({
    super.key,
    required this.player,
    required this.wallet,
    required this.totalSpins,
    this.signedIn = false,
    this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return TgScrollView(
      children: [
        const ScreenTitle(
          title: 'Player Profile',
          subtitle:
              'Verified Telegram account credentials and gameplay summary.',
        ),
        const SizedBox(height: 16),
        GlassCard(
          goldBorder: true,
          gradient: AppColors.cardGradient,
          child: Row(
            children: [
              PlayerAvatar(
                initial: player.initial,
                photoUrl: player.photoUrl,
                radius: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            player.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: signedIn
                              ? AppColors.primaryGold
                              : AppColors.textTertiary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      player.handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryGoldBright,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      signedIn
                          ? 'Telegram ID: ${player.telegramId} · connected'
                          : 'Telegram ID: ${player.telegramId}',
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
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('LIFETIME GAMING STATS'),
        const SizedBox(height: 10),
        GlassCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      'TOTAL DEPOSITED',
                      '₹ ${wallet.totalDeposited.toStringAsFixed(0)}',
                      AppColors.success,
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      'TOTAL WITHDRAWN',
                      '₹ ${wallet.totalWithdrawn.toStringAsFixed(0)}',
                      AppColors.error,
                    ),
                  ),
                ],
              ),
              const Divider(color: AppColors.glassBorder, height: 24),
              Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      'TOTAL SPINS',
                      '$totalSpins Rounds',
                      AppColors.primaryGoldBright,
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      'GAMEPLAY VOLUME',
                      '₹ ${wallet.gameVolume.toStringAsFixed(0)}',
                      AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionLabel('SETTINGS & PLATFORM GOVERNANCE'),
        const SizedBox(height: 10),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _MenuTile(
                icon: Icons.settings_rounded,
                title: 'Platform & Game Settings',
                subtitle: 'Sound, haptics, limits and verified identity',
                onTap: () {
                  TelegramBridge.instance.hapticImpact('light');
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(player: player),
                    ),
                  );
                },
              ),
              const Divider(color: AppColors.glassBorder, height: 1),
              _MenuTile(
                icon: Icons.support_agent_rounded,
                title: 'Official Telegram Support Desk',
                subtitle: '24/7 resolution desk on @spinwin_support',
                onTap: () => _showSupport(context),
              ),
              const Divider(color: AppColors.glassBorder, height: 1),
              _MenuTile(
                icon: Icons.shield_outlined,
                title: 'Responsible Gaming Policy',
                subtitle: '18+ strict eligibility & self-exclusion',
                onTap: () => _showPolicy(context),
              ),
              if (signedIn && onSignOut != null) ...[
                const Divider(color: AppColors.glassBorder, height: 1),
                _MenuTile(
                  icon: Icons.logout_rounded,
                  title: 'Sign out of Telegram',
                  subtitle: 'Disconnect this Mini App session',
                  onTap: () => _confirmSignOut(context),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    TelegramBridge.instance.hapticImpact('light');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to continue with Telegram again to use your wallet, spin, deposit, or withdraw.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay signed in'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sign out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await onSignOut?.call();
    }
  }

  void _showSupport(BuildContext context) {
    showTgSheet(
      context: context,
      builder: (_) => TgSheetScaffold(
        child: Column(
          children: [
            const Icon(
              Icons.support_agent,
              size: 40,
              color: AppColors.primaryGold,
            ),
            const SizedBox(height: 10),
            const Text(
              '24/7 Telegram Support Desk',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Contact @spinwin_support for instant assistance.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            GoldButton(
              label: 'Open Telegram Chat',
              onPressed: () {
                TelegramBridge.instance.openTelegramLink(
                  'https://t.me/spinwin_support',
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPolicy(BuildContext context) {
    showTgSheet(
      context: context,
      builder: (_) => const TgSheetScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Responsible Gaming (18+)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Spin & Win operates under a strict 18+ eligibility policy. Games of chance involve financial risk. Please play responsibly within your budgetary limits.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatItem(this.title, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: AppColors.goldHover,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primaryGold, size: 18),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 13,
        color: AppColors.textTertiary,
      ),
      onTap: onTap,
    );
  }
}
