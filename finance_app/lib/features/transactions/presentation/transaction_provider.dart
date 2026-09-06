import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/transaction_service.dart';
import '../domain/transaction_model.dart';

// ── Service provider ───────────────────────────────────────────────────────────

final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService(FirebaseFirestore.instance);
});

// ── Transaction list providers ─────────────────────────────────────────────────

/// Streams transactions for [month] (format "YYYY-MM") for the current user.
/// Results are sorted by date descending inside [TransactionService].
///
/// Used by: TransactionListScreen, Dashboard module.
final transactionsByMonthProvider = StreamProvider.autoDispose
    .family<List<TransactionModel>, String>((ref, month) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return const Stream.empty();
  return ref
      .watch(transactionServiceProvider)
      .getTransactionsByMonth(user.uid, month);
});

/// Streams the [limit] most recent transactions across all months.
/// Used by the Dashboard module for the "Recent transactions" card.
final recentTransactionsProvider = StreamProvider.autoDispose
    .family<List<TransactionModel>, int>((ref, limit) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return const Stream.empty();
  return ref
      .watch(transactionServiceProvider)
      .streamRecentTransactions(user.uid, limit);
});
