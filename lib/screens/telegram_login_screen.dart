import 'package:flutter/material.dart';

import '../core/telegram/telegram_bridge.dart';
import '../core/theme.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';

class TelegramLoginScreen extends StatefulWidget {
  final AppStore store;

  const TelegramLoginScreen({super.key, required this.store});

  @override
  State<TelegramLoginScreen> createState() => _TelegramLoginScreenState();
}

class _TelegramLoginScreenState extends State<TelegramLoginScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    TelegramBridge.instance.hapticImpact('medium');
    try {
      await widget.store.signInWithTelegram();
    } catch (_) {
      if (mounted) {
        TelegramBridge.instance.hapticNotification('error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = TelegramBridge.instance.user;
    final error = widget.store.backendMessage;
    final handle = user.username != null
        ? '@${user.username}'
        : 'Telegram ID ${user.id}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: GlassCard(
                  goldBorder: true,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlayerAvatar(
                        initial: user.firstName.isEmpty
                            ? 'P'
                            : user.firstName[0].toUpperCase(),
                        photoUrl: user.photoUrl,
                        radius: 36,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Sign in with Telegram',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Continue as ${user.firstName} to open your wallet, spin, deposit, and withdraw.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        handle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGoldBright,
                        ),
                      ),
                      if (error != null && error.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGold,
                          ),
                        )
                      else
                        GoldButton(
                          label: 'Continue with Telegram',
                          icon: Icons.telegram,
                          onPressed: _signIn,
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your Telegram ID is used to restore the same wallet on this Mini App.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
