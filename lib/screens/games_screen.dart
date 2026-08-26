import 'package:flutter/material.dart';

import '../core/layout.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class GamesScreen extends StatelessWidget {
  final VoidCallback onOpenSpinGame;

  const GamesScreen({super.key, required this.onOpenSpinGame});

  @override
  Widget build(BuildContext context) {
    return TgScrollView(
      children: [
        const ScreenTitle(
          title: 'Gaming Arena',
          subtitle:
              'Play with your wallet coins and win instant multiplier rewards.',
        ),
        const SizedBox(height: 18),
        _GameItem(
          title: 'Spin & Win Wheel',
          desc:
              'Dynamic multiplier wheel with instant coin payouts up to 10.0X.',
          icon: Icons.casino,
          minStake: '₹10.00',
          status: 'AVAILABLE',
          statusColor: AppColors.success,
          onTap: onOpenSpinGame,
        ),
        const SizedBox(height: 12),
        const _GameItem(
          title: 'Crypto Crash',
          desc: 'Multiplier rises exponentially before the rocket bursts.',
          icon: Icons.rocket_launch_rounded,
          minStake: '₹20.00',
          status: 'COMING SOON',
          statusColor: AppColors.warning,
        ),
        const SizedBox(height: 12),
        const _GameItem(
          title: 'Lucky Dice Roll',
          desc: 'Predict high, low, or exact rolls with instant coin rewards.',
          icon: Icons.games_rounded,
          minStake: '₹10.00',
          status: 'COMING SOON',
          statusColor: AppColors.warning,
        ),
      ],
    );
  }
}

class _GameItem extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final String minStake;
  final String status;
  final Color statusColor;
  final VoidCallback? onTap;

  const _GameItem({
    required this.title,
    required this.desc,
    required this.icon,
    required this.minStake,
    required this.status,
    required this.statusColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.goldHover,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primaryGold, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Min Stake: $minStake',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryGoldBright,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(label: status, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          GoldButton(
            label: onTap != null ? 'Play Now' : 'Under Development',
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
