import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../transactions/domain/transaction_model.dart';
import '../../transactions/presentation/transaction_provider.dart';
import '../data/budget_service.dart';
import '../domain/budget_model.dart';
import '../domain/budget_with_spending_model.dart';

// ── Service provider ───────────────────────────────────────────────────────────

final budgetServiceProvider = Provider<BudgetService>((ref) {
  return BudgetService(FirebaseFirestore.instance);
});

// ── Budget list provider ───────────────────────────────────────────────────────

/// Streams raw [BudgetModel] documents for [month].
/// Used internally by [budgetsWithSpendingProvider].
final budgetsByMonthProvider = StreamProvider.autoDispose
    .family<List<BudgetModel>, String>((ref, month) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return const Stream.empty();
  return ref.watch(budgetServiceProvider).getBudgetsByMonth(user.uid, month);
});

// ── Combined budgets + spending provider ──────────────────────────────────────
//
// This provider combines two live streams — budgets and transactions — and
// computes spending synchronously whenever either changes. The result is an
// AsyncValue so the UI can handle loading and error states uniformly.
//
// Using a regular Provider (not StreamProvider) keeps the combination
// logic simple: watch both streams, merge their values.

/// Provides [List<BudgetWithSpendingModel>] for [month], reactive to both
/// budget changes and transaction changes.
final budgetsWithSpendingProvider = Provider.autoDispose
    .family<AsyncValue<List<BudgetWithSpendingModel>>, String>((ref, month) {
  final budgets = ref.watch(budgetsByMonthProvider(month));
  final transactions = ref.watch(transactionsByMonthProvider(month));

  return budgets.when(
    loading: () => const AsyncLoading(),
    error: AsyncError.new,
    data: (budgetList) => transactions.when(
      loading: () => const AsyncLoading(),
      error: AsyncError.new,
      data: (txList) =>
          AsyncData(_buildWithSpending(budgetList, txList)),
    ),
  );
});

// ── Pure calculation function ──────────────────────────────────────────────────

/// Combines a list of budgets with the corresponding expense transactions to
/// produce [BudgetWithSpendingModel] entries.
///
/// This is a pure function — no Firestore calls, easy to unit-test.
List<BudgetWithSpendingModel> _buildWithSpending(
  List<BudgetModel> budgets,
  List<TransactionModel> transactions,
) {
  return budgets.map((budget) {
    // Sum expense transactions for this category in this month.
    final spent = transactions
        .where((t) => t.isExpense && t.categoryId == budget.categoryId)
        .fold<double>(0.0, (total, t) => total + t.amount);

    final remaining = budget.allocatedAmount - spent;
    final percent = budget.allocatedAmount > 0
        ? spent / budget.allocatedAmount
        : 0.0;

    return BudgetWithSpendingModel(
      budget: budget,
      spentAmount: spent,
      remainingAmount: remaining,
      usagePercent: percent,
      isOverspent: spent > budget.allocatedAmount,
    );
  }).toList();
}
