import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/layout.dart';
import '../core/telegram/telegram_bridge.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/wheel.dart';

class SpinAndWinScreen extends StatefulWidget {
  final PlayerWallet wallet;
  final Future<GameRoundItem> Function(double stake) playSpin;
  final VoidCallback onOpenHistory;

  const SpinAndWinScreen({
    super.key,
    required this.wallet,
    required this.playSpin,
    required this.onOpenHistory,
  });

  @override
  State<SpinAndWinScreen> createState() => _SpinAndWinScreenState();
}

class _SpinAndWinScreenState extends State<SpinAndWinScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double>? _animation;

  double _currentAngle = 0;
  bool _isSpinning = false;
  double _selectedStake = 50;

  static const List<WheelSegment> segments = [
    WheelSegment(
      label: '0.5X',
      multiplier: 0.5,
      weight: 35,
      color: Color(0xFF334155),
    ),
    WheelSegment(
      label: '1.0X',
      multiplier: 1.0,
      weight: 30,
      color: Color(0xFF1E293B),
    ),
    WheelSegment(
      label: '1.5X',
      multiplier: 1.5,
      weight: 15,
      color: Color(0xFF0F766E),
    ),
    WheelSegment(
      label: '2.0X',
      multiplier: 2.0,
      weight: 10,
      color: Color(0xFFD4AF37),
    ),
    WheelSegment(
      label: '3.0X',
      multiplier: 3.0,
      weight: 6,
      color: Color(0xFFEAB308),
    ),
    WheelSegment(
      label: '5.0X',
      multiplier: 5.0,
      weight: 3,
      color: Color(0xFFF97316),
    ),
    WheelSegment(
      label: '10.0X',
      multiplier: 10.0,
      weight: 1,
      color: Color(0xFFEF4444),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );
    _controller.addListener(() {
      final animation = _animation;
      if (animation == null) return;
      setState(() => _currentAngle = animation.value);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSelectStake(double stake) {
    if (_isSpinning) return;
    TelegramBridge.instance.hapticSelection();
    setState(() => _selectedStake = stake);
  }

  Future<void> _executeSpin() async {
    if (_isSpinning) return;

    if (widget.wallet.availableBalance < _selectedStake) {
      TelegramBridge.instance.hapticNotification('error');
      _showInsufficientBalance();
      return;
    }

    setState(() => _isSpinning = true);
    TelegramBridge.instance.hapticImpact('heavy');
    TelegramBridge.instance.disableVerticalSwipes();

    GameRoundItem roundItem;
    try {
      roundItem = await widget.playSpin(_selectedStake);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSpinning = false);
      TelegramBridge.instance.hapticNotification('error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
      return;
    }

    final winningIndex = segments.indexWhere(
      (segment) => segment.label == roundItem.winningSegment,
    );
    final safeIndex = winningIndex >= 0 ? winningIndex : 0;
    final winningSegment = segments[safeIndex];

    final segmentAngle = (2 * math.pi) / segments.length;
    final targetSegmentAngle = winningIndex * segmentAngle + (segmentAngle / 2);
    final baseRotations = 5 * (2 * math.pi);
    final endAngle = _currentAngle +
        baseRotations +
        (2 * math.pi - targetSegmentAngle) -
        (_currentAngle % (2 * math.pi));

    _animation = Tween<double>(begin: _currentAngle, end: endAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    await _controller.forward(from: 0);
    if (!mounted) return;

    setState(() => _isSpinning = false);

    if (winningSegment.multiplier > 1) {
      TelegramBridge.instance.hapticNotification('success');
    } else {
      TelegramBridge.instance.hapticImpact('medium');
    }
    _showResult(roundItem);
  }

  void _showInsufficientBalance() {
    showTgSheet(
      context: context,
      builder: (_) => TgSheetScaffold(
        child: Column(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 40,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            const Text(
              'Insufficient Balance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Available ₹${widget.wallet.availableBalance.toStringAsFixed(2)}. Required ₹${_selectedStake.toStringAsFixed(2)}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            GoldButton(
              label: 'Close',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showResult(GameRoundItem round) {
    final isWin = round.multiplier > 1;
    showTgSheet(
      context: context,
      builder: (_) => TgSheetScaffold(
        child: Column(
          children: [
            Icon(
              isWin ? Icons.emoji_events_rounded : Icons.replay_rounded,
              size: 42,
              color: isWin
                  ? AppColors.primaryGoldBright
                  : AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              isWin ? 'CONGRATULATIONS!' : 'BETTER LUCK NEXT TIME!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isWin
                    ? AppColors.primaryGoldBright
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Multiplier: ${round.winningSegment}  •  Won: ₹${round.payoutAmount.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GoldButton(
              label: 'Spin Again',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chrome = TelegramScope.of(context).chromePadding;
    final short = TgLayout.isShort(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: TgLayout.isCompact(context) ? 48 : 52,
        leadingWidth: 44,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: _isSpinning ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Spin & Win Wheel',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.primaryGold),
            onPressed: widget.onOpenHistory,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, chrome.bottom + 12),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Balance',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    AmountText(
                      amount: widget.wallet.availableBalance,
                      fontSize: 16,
                      compact: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: short ? 8 : 12),
              Expanded(
                child: Center(
                  child: FlexibleWheel(
                    segments: segments,
                    angle: _currentAngle,
                  ),
                ),
              ),
              SizedBox(height: short ? 8 : 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final value in [10, 20, 50, 100, 200, 500])
                      _StakeChip(
                        value: value.toDouble(),
                        selected: _selectedStake == value,
                        enabled: !_isSpinning,
                        onTap: () => _onSelectStake(value.toDouble()),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GoldButton(
                label: _isSpinning
                    ? 'SPINNING...'
                    : 'SPIN (₹${_selectedStake.toStringAsFixed(0)})',
                onPressed: _isSpinning ? null : _executeSpin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StakeChip extends StatelessWidget {
  final double value;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _StakeChip({
    required this.value,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('₹${value.toStringAsFixed(0)}'),
        selected: selected,
        selectedColor: AppColors.primaryGold,
        backgroundColor: AppColors.surface,
        labelStyle: TextStyle(
          color: selected ? Colors.black : AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        side: BorderSide(
          color: selected ? AppColors.primaryGold : AppColors.glassBorder,
        ),
        onSelected: enabled ? (_) => onTap() : null,
      ),
    );
  }
}

class GameHistoryScreen extends StatelessWidget {
  final List<GameRoundItem> history;

  const GameHistoryScreen({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return TgSubScaffold(
      title: 'Game History',
      body: history.isEmpty
          ? const Center(
              child: Text(
                'No rounds yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                TelegramScope.of(context).chromePadding.bottom + 16,
              ),
              itemCount: history.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final round = history[index];
                return GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Multiplier: ${round.winningSegment}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGoldBright,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Stake: ₹${round.entryAmount.toStringAsFixed(0)}  •  Won: ₹${round.payoutAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: round.isWin ? 'WIN' : 'LOSS',
                        color: round.isWin ? AppColors.success : AppColors.error,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
