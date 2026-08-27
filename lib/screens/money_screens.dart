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
  static const _presets = [300, 500, 750, 1000, 2000, 5000, 10000];
  static const _minAmount = 300.0;

  final _customController = TextEditingController();
  int? _preset = 500;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  double? get _amount {
    final custom = double.tryParse(_customController.text.trim());
    if (custom != null) return custom;
    final preset = _preset;
    if (preset != null) return preset.toDouble();
    return null;
  }

  void _selectPreset(int value) {
    TelegramBridge.instance.hapticSelection();
    setState(() {
      _preset = value;
      _customController.clear();
    });
  }

  void _continue() {
    final amount = _amount;
    if (amount == null || amount < _minAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a pack or enter at least ₹300.'),
        ),
      );
      return;
    }
    TelegramBridge.instance.hapticImpact('medium');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DepositPaymentScreen(
          amount: amount,
          upiId: widget.upiId,
          onDepositSubmitted: widget.onDepositSubmitted,
          onViewHistory: widget.onViewHistory,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _amount;
    return TgSubScaffold(
      title: 'Deposit Coins',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          TelegramScope.of(context).chromePadding.bottom +
              MediaQuery.viewInsetsOf(context).bottom +
              24,
        ),
        children: [
          const Text(
            'Select deposit amount',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose a pack or enter a custom amount. Minimum ₹300.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((value) {
              final isSelected =
                  _customController.text.trim().isEmpty && _preset == value;
              return _AmountChip(
                label: '₹$value',
                selected: isSelected,
                onTap: () => _selectPreset(value),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _customController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: tgInputDecoration(
              'Custom amount (min ₹300)',
              hint: '300',
            ),
            onChanged: (value) => setState(() {
              _preset = value.trim().isEmpty ? 500 : null;
            }),
          ),
          const SizedBox(height: 16),
          GlassCard(
            goldBorder: true,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'You will pay',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                AmountText(
                  amount: selected != null && selected >= _minAmount
                      ? selected
                      : 0,
                  fontSize: 22,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GoldButton(
            label: 'Continue to Payment',
            icon: Icons.arrow_forward_rounded,
            onPressed: _continue,
          ),
        ],
      ),
    );
  }
}

class DepositPaymentScreen extends StatefulWidget {
  final double amount;
  final String upiId;
  final Future<void> Function({
    required double amount,
    required String utr,
    Uint8List? receiptBytes,
    String? receiptName,
  }) onDepositSubmitted;
  final VoidCallback onViewHistory;

  const DepositPaymentScreen({
    super.key,
    required this.amount,
    required this.upiId,
    required this.onDepositSubmitted,
    required this.onViewHistory,
  });

  @override
  State<DepositPaymentScreen> createState() => _DepositPaymentScreenState();
}

class _DepositPaymentScreenState extends State<DepositPaymentScreen> {
  final _utrController = TextEditingController();
  final _picker = ImagePicker();
  bool _isSubmitting = false;
  Uint8List? _receiptBytes;
  String? _receiptName;
  static const _upiIdFallback = 'spinwin@upi';

  @override
  void dispose() {
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
    if (_isSubmitting) return;
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
        amount: widget.amount,
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
    final nav = Navigator.of(context);
    nav.pop();
    nav.pop();
    widget.onViewHistory();
  }

  @override
  Widget build(BuildContext context) {
    final upi = widget.upiId.isEmpty ? _upiIdFallback : widget.upiId;
    return TgSubScaffold(
      title: 'Payment Info',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          TelegramScope.of(context).chromePadding.bottom +
              MediaQuery.viewInsetsOf(context).bottom +
              24,
        ),
        children: [
          GlassCard(
            goldBorder: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PAY EXACTLY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                AmountText(amount: widget.amount, fontSize: 28),
                const SizedBox(height: 14),
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
                        upi,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGoldBright,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: upi));
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
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How to deposit',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _DepositStep(
                  number: '1',
                  text: 'Copy the UPI ID above.',
                ),
                _DepositStep(
                  number: '2',
                  text:
                      'Pay exactly ₹${widget.amount.toStringAsFixed(0)} from your UPI app. Do not change the amount.',
                ),
                const _DepositStep(
                  number: '3',
                  text: 'Copy the 12-digit UTR / UPI reference from the payment success screen.',
                ),
                const _DepositStep(
                  number: '4',
                  text: 'Upload a screenshot of the payment receipt.',
                ),
                const _DepositStep(
                  number: '5',
                  text: 'Paste the UTR below and tap Submit Deposit Slip.',
                ),
                const SizedBox(height: 6),
                const Text(
                  'Coins are credited after admin approval.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGoldBright,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _utrController,
            maxLength: 12,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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

class _DepositStep extends StatelessWidget {
  final String number;
  final String text;

  const _DepositStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.goldHover,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryGoldBright,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AmountChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.goldHover : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primaryGold : AppColors.glassBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected
                  ? AppColors.primaryGoldBright
                  : AppColors.textPrimary,
            ),
          ),
        ),
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
