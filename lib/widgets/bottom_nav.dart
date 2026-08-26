import 'package:flutter/material.dart';

import '../core/layout.dart';
import '../core/telegram/telegram_bridge.dart';
import '../core/theme.dart';

class TgBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const TgBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
  });

  static const _items = [
    (label: 'Home', icon: Icons.home_outlined, active: Icons.home_rounded),
    (label: 'Games', icon: Icons.casino_outlined, active: Icons.casino_rounded),
    (
      label: 'Wallet',
      icon: Icons.account_balance_wallet_outlined,
      active: Icons.account_balance_wallet_rounded,
    ),
    (
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      active: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final metrics = TelegramScope.of(context);
    final compact = TgLayout.isNarrow(context) || TgLayout.isShort(context);
    final height = TgLayout.navBarHeight(context);
    final pad = TgLayout.pagePad(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        pad,
        0,
        pad,
        metrics.chromePadding.bottom + TgLayout.navGap,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: TgLayout.maxContentWidth),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.glassSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.glassBorderGold),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: AppColors.primaryGold.withValues(alpha: 0.08),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _NavItem(
                      label: _items[i].label,
                      icon: _items[i].icon,
                      activeIcon: _items[i].active,
                      selected: index == i,
                      compact: compact,
                      onTap: () {
                        TelegramBridge.instance.hapticSelection();
                        onChanged(i);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? AppColors.primaryGoldBright : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected ? AppColors.goldHover : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? Border.all(color: AppColors.glassBorderGold)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, size: compact ? 20 : 20, color: color),
            if (!compact) ...[
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
