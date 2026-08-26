import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/layout.dart';
import '../core/telegram/telegram_bridge.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class DepositScreen extends StatefulWidget {
  final String upiId;
  final Future<void> Function({
    required double amount,
    required String utr,
    Uint8List? receiptBytes,
    String? receiptName,
  }) onDepositSubmitted;
  final VoidCallback onViewHistory;

  const DepositScreen({
    super.key,
    required this.upiId,
    required this.onDepositSubmitted,
    required this.onViewHistory,
  });

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _amountController = TextEditingController(text: '500');
  final _utrController = TextEditingController();
  final _picker = ImagePicker();
  bool _isSubmitting = false;
  Uint8List? _receiptBytes;
  String? _receiptName;
  static const _upiIdFallback = 'spinwin@upi';

  @override
  void dispose() {
    _amountController.dispose();
    _utrController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _receiptBytes = bytes;
      _receiptName = file.name;
    });
  }

  Future<void> _submit() async {
    if (_utrController.text.trim().length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 12-digit UTR.')),
      );
      return;
    }
    if (_receiptBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload a payment receipt photo.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onDepositSubmitted(
        amount: double.tryParse(_amountController.text) ?? 500,
        utr: _utrController.text.trim(),
        receiptBytes: _receiptBytes,
        receiptName: _receiptName,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.pop(context);
    widget.onViewHistory();
  }

  @override
  Widget build(BuildContext context) {
    return TgSubScaffold(
      title: 'Deposit Coins (UPI)',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          TelegramScope.of(context).chromePadding.bottom +
              MediaQuery.viewInsetsOf(context).bottom +
              16,
        ),
        children: [
          GlassCard(
            goldBorder: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pay to this UPI ID',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.upiId.isEmpty ? _upiIdFallback : widget.upiId,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGoldBright,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final value = widget.upiId.isEmpty
                            ? _upiIdFallback
                            : widget.upiId;
                        await Clipboard.setData(ClipboardData(text: value));
                        TelegramBridge.instance.hapticSelection();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('UPI ID copied')),
                        );
                      },
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: AppColors.primaryGold,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: tgInputDecoration('Amount (₹)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _utrController,
            maxLength: 12,
            keyboardType: TextInputType.number,
            decoration: tgInputDecoration('12-Digit Bank UTR'),
          ),
          const SizedBox(height: 12),
          GlassCard(
            onTap: _pickReceipt,
            child: _receiptBytes == null
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.photo_camera_back_outlined,
                          color: AppColors.primaryGold,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment receipt photo',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Tap to upload UPI screenshot',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _receiptBytes!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _receiptName ?? 'Receipt selected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          GoldButton(
            label: _isSubmitting ? 'Submitting...' : 'Submit Deposit Slip',
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class WithdrawScreen extends StatefulWidget {
  final PlayerWallet wallet;
  final String playerName;
  final double minAmount;
  final double maxAmount;
  final Future<void> Function(WithdrawalRequestItem withdrawal)
      onWithdrawalSubmitted;
  final VoidCallback onViewHistory;

  const WithdrawScreen({
    super.key,
    required this.wallet,
    required this.playerName,
    this.minAmount = 100,
    this.maxAmount = 50000,
    required this.onWithdrawalSubmitted,
    required this.onViewHistory,
  });

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  late final TextEditingController _amountController;
  final _upiController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final available = widget.wallet.availableBalance;
    final suggested = available >= 300
        ? 300.0
        : available.floorToDouble();
    _amountController = TextEditingController(
      text: suggested >= widget.minAmount ? suggested.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final upi = _upiController.text.trim();
    if (upi.isEmpty || !upi.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid UPI ID such as name@bank.')),
      );
      return;
    }
    if (amount < widget.minAmount || amount > widget.maxAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enter an amount between ₹${widget.minAmount.toStringAsFixed(0)} and ₹${widget.maxAmount.toStringAsFixed(0)}.',
          ),
        ),
      );
      return;
    }
    if (amount > widget.wallet.availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient withdrawable balance.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onWithdrawalSubmitted(
        WithdrawalRequestItem(
          id: 'wth_${DateTime.now().millisecondsSinceEpoch}',
          amount: amount,
          upiId: upi,
          accountHolderName: widget.playerName,
          status: WithdrawalStatus.pending,
          createdAt: DateTime.now(),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.pop(context);
    widget.onViewHistory();
  }

  @override
  Widget build(BuildContext context) {
    return TgSubScaffold(
      title: 'Withdraw Coins (UPI)',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          TelegramScope.of(context).chromePadding.bottom +
              MediaQuery.viewInsetsOf(context).bottom +
              32,
        ),
        children: [
          GlassCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Withdrawable',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    AmountText(
                      amount: widget.wallet.availableBalance,
                      fontSize: 18,
                    ),
                  ],
                ),
                if (widget.wallet.pendingBalance > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Pending payout',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      Text(
                        '₹ ${widget.wallet.pendingBalance.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Minimum ₹${widget.minAmount.toStringAsFixed(0)} · Maximum ₹${widget.maxAmount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: tgInputDecoration('Amount (₹)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _upiController,
            keyboardType: TextInputType.emailAddress,
            decoration: tgInputDecoration(
              'Beneficiary UPI ID',
              hint: 'name@bank',
            ),
          ),
          const SizedBox(height: 16),
          GoldButton(
            label: _isSubmitting ? 'Submitting...' : 'Request Payout',
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class DepositHistoryScreen extends StatelessWidget {
  final List<DepositRequestItem> deposits;

  const DepositHistoryScreen({super.key, required this.deposits});

  @override
  Widget build(BuildContext context) {
    return TgSubScaffold(
      title: 'Deposit History',
      body: deposits.isEmpty
          ? const Center(
              child: Text(
                'No deposits yet.',
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
              itemCount: deposits.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = deposits[index];
                return GlassCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AmountText(amount: item.amount, fontSize: 16),
                            const SizedBox(height: 2),
                            Text(
                              'UTR: ${item.utr}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (item.screenshotUrl != null) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.screenshotUrl!,
                                  height: 72,
                                  width: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: item.status.name.toUpperCase(),
                        color: item.status == DepositStatus.approved
                            ? AppColors.success
                            : item.status == DepositStatus.rejected
                                ? AppColors.error
                                : AppColors.warning,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class WithdrawalHistoryScreen extends StatelessWidget {
  final List<WithdrawalRequestItem> withdrawals;

  const WithdrawalHistoryScreen({super.key, required this.withdrawals});

  @override
  Widget build(BuildContext context) {
    return TgSubScaffold(
      title: 'Withdrawal History',
      body: withdrawals.isEmpty
          ? const Center(
              child: Text(
                'No withdrawals yet.',
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
              itemCount: withdrawals.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = withdrawals[index];
                return GlassCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AmountText(amount: item.amount, fontSize: 16),
                            const SizedBox(height: 2),
                            Text(
                              'UPI: ${item.upiId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: item.status.name.toUpperCase(),
                        color: item.status == WithdrawalStatus.paid
                            ? AppColors.success
                            : item.status == WithdrawalStatus.rejected
                                ? AppColors.error
                                : AppColors.warning,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  final AppPlayer player;

  const SettingsScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return TgSubScaffold(
      title: 'Platform Settings',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          TelegramScope.of(context).chromePadding.bottom + 16,
        ),
        children: [
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  title: const Text('Telegram ID'),
                  subtitle: Text('${player.telegramId}'),
                ),
                const Divider(color: AppColors.glassBorder, height: 1),
                ListTile(
                  title: const Text('Registered Name'),
                  subtitle: Text(player.displayName),
                ),
                const Divider(color: AppColors.glassBorder, height: 1),
                const ListTile(
                  title: Text('Official Support Desk'),
                  subtitle: Text('@spinwin_support'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
