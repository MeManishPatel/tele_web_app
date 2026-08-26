import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../models/models.dart';

class BackendException implements Exception {
  BackendException(this.message);
  final String message;

  @override
  String toString() => message;
}

class Backend {
  Backend._();

  static SupabaseClient get _client => AppConfig.client;

  static Future<void> authenticateWithTelegram(String initData) async {
    try {
      final response = await _client.functions.invoke(
        'telegram-auth',
        body: {'initData': initData},
      );
      final data = _map(response.data);
      final error = data['error'] as String?;
      if (response.status == 404) {
        throw BackendException(
          'Telegram login is not deployed yet. Run ./scripts/deploy_backend.sh',
        );
      }
      if (response.status != 200 || error != null) {
        throw BackendException(error ?? 'Telegram sign-in failed');
      }
      final refresh = data['refresh_token'] as String?;
      if (refresh == null || refresh.isEmpty) {
        throw BackendException('Session missing from Telegram sign-in');
      }
      await _client.auth.setSession(refresh);
      if (_client.auth.currentUser == null) {
        throw BackendException('Could not establish a signed-in session');
      }
    } on BackendException {
      rethrow;
    } on FunctionException catch (error) {
      throw BackendException(_functionError(error));
    }
  }

  static String _functionError(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final mapped = details['error'] ?? details['message'];
      if (mapped is String && mapped.isNotEmpty) return mapped;
    }
    if (details is String && details.isNotEmpty) return details;
    if (error.reasonPhrase != null && error.reasonPhrase!.isNotEmpty) {
      return error.reasonPhrase!;
    }
    return 'Telegram sign-in is unavailable';
  }

  static Future<bool> restoreTelegramSession(int telegramId) async {
    final session = _client.auth.currentSession;
    final user = session?.user;
    if (session == null || user == null) return false;
    final metaId = user.userMetadata?['telegram_id'];
    if (metaId != null && metaId.toString() != telegramId.toString()) {
      await _client.auth.signOut();
      return false;
    }
    try {
      final row = await _client
          .from('users')
          .select('telegram_id')
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) {
        await _client.auth.signOut();
        return false;
      }
      if (row['telegram_id']?.toString() != telegramId.toString()) {
        await _client.auth.signOut();
        return false;
      }
      return true;
    } catch (_) {
      await _client.auth.signOut();
      return false;
    }
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static bool get hasSession => _client.auth.currentSession != null;

  static Future<void> loadAccount({
    required void Function(AppPlayer player) onPlayer,
    required void Function(PlayerWallet wallet) onWallet,
    required void Function(List<GameRoundItem> rounds) onRounds,
    required void Function(List<DepositRequestItem> deposits) onDeposits,
    required void Function(List<WithdrawalRequestItem> withdrawals)
        onWithdrawals,
    required void Function(List<WalletTransactionItem> txs) onTransactions,
    required void Function(String upiId) onUpi,
    required void Function({
      required double minWithdrawal,
      required double maxWithdrawal,
    }) onLimits,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw BackendException('Not signed in');

    final userRow = await _client.from('users').select().eq('id', uid).single();
    final walletRow =
        await _client.from('wallets').select().eq('user_id', uid).single();
    final txRows = await _client
        .from('wallet_transactions')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50);
    final spinRows = await _client
        .from('spins')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50);
    final depositRows = await _client
        .from('deposit_requests')
        .select()
        .eq('user_id', uid)
        .order('submitted_at', ascending: false)
        .limit(50);
    final withdrawalRows = await _client
        .from('withdrawal_requests')
        .select()
        .eq('user_id', uid)
        .order('requested_at', ascending: false)
        .limit(50);
    final settings = await _client.from('platform_settings').select().eq('id', 1).maybeSingle();

    final txs = (txRows as List)
        .map((row) => _tx(Map<String, dynamic>.from(row as Map)))
        .toList();

    onPlayer(
      AppPlayer(
        id: userRow['id'] as String,
        telegramId: (userRow['telegram_id'] as num).toInt(),
        firstName: (userRow['first_name'] as String?) ?? 'Player',
        lastName: userRow['last_name'] as String?,
        username: userRow['username'] as String?,
        photoUrl: userRow['photo_url'] as String?,
        status: (userRow['is_active'] as bool? ?? true)
            ? AccountStatus.active
            : AccountStatus.suspended,
      ),
    );
    onWallet(_walletFrom(Map<String, dynamic>.from(walletRow), txs));
    onRounds(
      (spinRows as List)
          .map((row) => _spin(Map<String, dynamic>.from(row as Map)))
          .toList(),
    );
    onDeposits(
      (depositRows as List)
          .map((row) => _deposit(Map<String, dynamic>.from(row as Map)))
          .toList(),
    );
    onWithdrawals(
      (withdrawalRows as List)
          .map((row) => _withdrawal(Map<String, dynamic>.from(row as Map)))
          .toList(),
    );
    onTransactions(txs);
    onUpi((settings?['upi_id'] as String?) ?? 'spinwin@upi');
    onLimits(
      minWithdrawal: _num(settings?['min_withdrawal'] ?? 100),
      maxWithdrawal: _num(settings?['max_withdrawal'] ?? 50000),
    );
  }

  static Future<Map<String, dynamic>> spin({
    required double stake,
    required String requestId,
  }) async {
    final response = await _client.rpc(
      'perform_spin',
      params: {'p_stake': stake, 'p_request_id': requestId},
    );
    return _map(response);
  }

  static Future<Map<String, dynamic>> submitDeposit({
    required double amount,
    required String utr,
    String? screenshotPath,
    String? screenshotUrl,
  }) async {
    try {
      final response = await _client.rpc(
        'submit_deposit',
        params: {
          'p_amount': amount,
          'p_utr': utr,
          'p_screenshot_path': screenshotPath,
          'p_screenshot_url': screenshotUrl,
        },
      );
      return _map(response);
    } on PostgrestException catch (error) {
      throw BackendException(error.message);
    }
  }

  static Future<({String path, String url})> uploadReceipt({
    required Uint8List bytes,
    required String filename,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw BackendException('Not signed in');
    final ext = filename.split('.').last.toLowerCase();
    final safeExt =
        ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext) ? ext : 'jpg';
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    final contentType = switch (safeExt) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
    await _client.storage.from('payment-screenshots').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    final url = await _client.storage
        .from('payment-screenshots')
        .createSignedUrl(path, 60 * 60 * 24 * 30);
    return (path: path, url: url);
  }

  static Future<List<AdminDepositItem>> adminListDeposits(String code) async {
    try {
      final response = await _client.rpc(
        'admin_list_deposits',
        params: {'p_code': code},
      );
      if (response is List) {
        return response
            .map(
              (row) => AdminDepositItem.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
      }
      throw BackendException('Could not load admin deposits');
    } on PostgrestException catch (error) {
      throw BackendException(error.message);
    }
  }

  static Future<void> adminReviewDeposit({
    required String code,
    required String depositId,
    required bool approve,
    String? note,
  }) async {
    try {
      await _client.rpc(
        'admin_review_deposit',
        params: {
          'p_code': code,
          'p_deposit_id': depositId,
          'p_approve': approve,
          'p_note': note,
        },
      );
    } on PostgrestException catch (error) {
      throw BackendException(error.message);
    }
  }

  static Future<Map<String, dynamic>> submitWithdrawal({
    required double amount,
    required String upiId,
  }) async {
    try {
      final response = await _client.rpc(
        'submit_withdrawal',
        params: {'p_amount': amount, 'p_upi_id': upiId},
      );
      return _map(response);
    } on PostgrestException catch (error) {
      throw BackendException(_withdrawalError(error.message));
    }
  }

  static String _withdrawalError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('insufficient')) {
      return 'Not enough withdrawable balance for this payout.';
    }
    if (lower.contains('invalid withdrawal amount')) {
      return 'Amount is outside the allowed withdrawal range.';
    }
    if (lower.contains('invalid upi')) {
      return 'Enter a valid UPI ID such as name@bank.';
    }
    if (lower.contains('not authenticated')) {
      return 'Sign in with Telegram to withdraw.';
    }
    if (lower.contains('disabled')) {
      return 'Withdrawals are temporarily disabled.';
    }
    if (lower.contains('wallet_components_consistent')) {
      return 'Wallet could not hold this payout. Please try again.';
    }
    return message;
  }

  static Map<String, dynamic> _map(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw BackendException('Unexpected backend response');
  }

  static PlayerWallet _walletFrom(
    Map<String, dynamic> row,
    List<WalletTransactionItem> txs,
  ) {
    double sum(TransactionType type) => txs
        .where((tx) => tx.type == type)
        .fold<double>(0, (value, tx) => value + tx.amount);

    return PlayerWallet(
      id: row['id'] as String,
      availableBalance: _available(row),
      pendingBalance: _num(row['reserved_balance']),
      totalDeposited: sum(TransactionType.deposit),
      totalWithdrawn: sum(TransactionType.withdrawal),
      gameVolume: sum(TransactionType.gameDebit),
    );
  }

  static GameRoundItem _spin(Map<String, dynamic> row) {
    final metadata = row['metadata'] is Map
        ? Map<String, dynamic>.from(row['metadata'] as Map)
        : <String, dynamic>{};
    return GameRoundItem(
      id: row['id'] as String,
      entryAmount: _num(row['stake']),
      multiplier: _num(row['multiplier']),
      payoutAmount: _num(row['reward']),
      winningSegment: (metadata['label'] as String?) ??
          '${_num(row['multiplier']).toStringAsFixed(1)}X',
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static DepositRequestItem _deposit(Map<String, dynamic> row) {
    return DepositRequestItem(
      id: row['id'] as String,
      amount: _num(row['amount']),
      utr: (row['utr_number'] as String?) ?? '',
      status: switch (row['status'] as String?) {
        'approved' => DepositStatus.approved,
        'rejected' => DepositStatus.rejected,
        _ => DepositStatus.pending,
      },
      createdAt: DateTime.tryParse(row['submitted_at'] as String? ?? '') ??
          DateTime.now(),
      screenshotUrl: row['screenshot_url'] as String?,
    );
  }

  static WithdrawalRequestItem _withdrawal(Map<String, dynamic> row) {
    return WithdrawalRequestItem(
      id: row['id'] as String,
      amount: _num(row['amount']),
      upiId: (row['upi_id'] as String?) ?? '',
      accountHolderName: 'Player',
      status: switch (row['status'] as String?) {
        'processing' => WithdrawalStatus.processing,
        'paid' => WithdrawalStatus.paid,
        'rejected' => WithdrawalStatus.rejected,
        _ => WithdrawalStatus.pending,
      },
      paymentReference: row['admin_reference'] as String?,
      createdAt: DateTime.tryParse(row['requested_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static WalletTransactionItem _tx(Map<String, dynamic> row) {
    final type = switch (row['type'] as String?) {
      'deposit' => TransactionType.deposit,
      'withdrawal_hold' ||
      'withdrawal_completed' =>
        TransactionType.withdrawal,
      'spin_cost' => TransactionType.gameDebit,
      'spin_reward' => TransactionType.gameCredit,
      'refund' || 'withdrawal_reversal' => TransactionType.refund,
      'bonus' => TransactionType.bonus,
      _ => TransactionType.gameDebit,
    };
    return WalletTransactionItem(
      id: row['id'] as String,
      type: type,
      amount: _num(row['amount']),
      balanceBefore: _num(row['balance_before']),
      balanceAfter: _num(row['balance_after']),
      description: (row['metadata'] is Map
              ? (row['metadata'] as Map)['label'] as String?
              : null) ??
          type.name,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static double _num(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static double _available(Map<String, dynamic> row) {
    if (row.containsKey('withdrawable_balance') &&
        row['withdrawable_balance'] != null) {
      return _num(row['withdrawable_balance']);
    }
    return _num(row['balance']);
  }
}

class AdminDepositItem {
  final String id;
  final double amount;
  final String utr;
  final String status;
  final String? screenshotUrl;
  final DateTime submittedAt;
  final String? firstName;
  final String? lastName;
  final String? username;
  final int? telegramId;

  const AdminDepositItem({
    required this.id,
    required this.amount,
    required this.utr,
    required this.status,
    required this.submittedAt,
    this.screenshotUrl,
    this.firstName,
    this.lastName,
    this.username,
    this.telegramId,
  });

  factory AdminDepositItem.fromJson(Map<String, dynamic> row) {
    return AdminDepositItem(
      id: '${row['id']}',
      amount: row['amount'] is num
          ? (row['amount'] as num).toDouble()
          : double.tryParse('${row['amount']}') ?? 0,
      utr: (row['utr_number'] as String?) ?? '',
      status: (row['status'] as String?) ?? 'pending',
      screenshotUrl: row['screenshot_url'] as String?,
      submittedAt: DateTime.tryParse(row['submitted_at'] as String? ?? '') ??
          DateTime.now(),
      firstName: row['first_name'] as String?,
      lastName: row['last_name'] as String?,
      username: row['username'] as String?,
      telegramId: row['telegram_id'] is num
          ? (row['telegram_id'] as num).toInt()
          : int.tryParse('${row['telegram_id']}'),
    );
  }

  String get playerLabel {
    final name = [firstName, lastName]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' ');
    if (name.isNotEmpty) return name;
    if (username != null && username!.isNotEmpty) return '@$username';
    return 'Player';
  }
}

String newRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
