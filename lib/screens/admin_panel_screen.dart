import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/theme.dart';
import '../services/backend.dart';
import '../widgets/common.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _codeController = TextEditingController();
  String? _code;
  bool _loading = false;
  String? _error;
  List<AdminDepositItem> _deposits = [];

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!AppConfig.supabaseReady) {
        await AppConfig.initSupabase();
      }
      final rows = await Backend.adminListDeposits(code);
      setState(() {
        _code = code;
        _deposits = rows;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _refresh() async {
    final code = _code;
    if (code == null) return;
    setState(() => _loading = true);
    try {
      final rows = await Backend.adminListDeposits(code);
      setState(() {
        _deposits = rows;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _review(AdminDepositItem item, {required bool approve}) async {
    final code = _code;
    if (code == null) return;
    setState(() => _loading = true);
    try {
      await Backend.adminReviewDeposit(
        code: code,
        depositId: item.id,
        approve: approve,
      );
      await _refresh();
    } catch (error) {
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _code == null ? _login() : _queue(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _login() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Deposit Admin',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Review UPI deposit slips submitted from the Telegram Mini App.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        GlassCard(
          goldBorder: true,
          child: Column(
            children: [
              TextField(
                controller: _codeController,
                obscureText: true,
                decoration: tgInputDecoration('Admin access code'),
                onSubmitted: (_) => _unlock(),
              ),
              const SizedBox(height: 14),
              GoldButton(
                label: _loading ? 'Checking...' : 'Open queue',
                onPressed: _loading ? null : _unlock,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _queue() {
    final pending = _deposits.where((d) => d.status == 'pending').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Deposit queue',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryGold),
            ),
          ],
        ),
        Text(
          '$pending pending  •  ${_deposits.length} total',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: _deposits.isEmpty
              ? const Center(
                  child: Text(
                    'No deposit requests yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  itemCount: _deposits.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _deposits[index];
                    final pendingItem = item.status == 'pending';
                    return GlassCard(
                      goldBorder: pendingItem,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.playerLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              StatusBadge(
                                label: item.status.toUpperCase(),
                                color: item.status == 'approved'
                                    ? AppColors.success
                                    : item.status == 'rejected'
                                        ? AppColors.error
                                        : AppColors.warning,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.telegramId == null
                                ? 'Unknown Telegram user'
                                : 'Telegram ID: ${item.telegramId}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AmountText(amount: item.amount, fontSize: 22),
                          Text(
                            'UTR: ${item.utr}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (item.screenshotUrl != null &&
                              item.screenshotUrl!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                item.screenshotUrl!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'Receipt image could not be loaded.',
                                    style: TextStyle(color: AppColors.textTertiary),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (pendingItem) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: GoldButton(
                                    label: 'Approve',
                                    onPressed: _loading
                                        ? null
                                        : () => _review(item, approve: true),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GhostButton(
                                    label: 'Reject',
                                    onPressed: _loading
                                        ? null
                                        : () => _review(item, approve: false),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
