import '../../transactions/data/transaction_service.dart';
import '../../transactions/domain/transaction_model.dart';
import '../domain/dashboard_summary_model.dart';

/// Computes dashboard summary data from the transaction stream.
///
/// All calculations are pure functions so they are easy to unit-test.
/// No data is written to Firestore from this service.
class DashboardService {
  const DashboardService(this._transactionService);

  final TransactionService _transactionService;

  // ── Stream ──────────────────────────────────────────────────────────────────

  /// Streams a computed [DashboardSummaryModel] for [uid] and [month].
  ///
  /// The stream re-emits whenever the underlying transaction list changes,
  /// so the dashboard stays live without any manual refresh.
  Stream<DashboardSummaryModel> getDashboardSummary(
    String uid,
    String month,
  ) {
    return _transactionService
        .getTransactionsByMonth(uid, month)
        .map((transactions) {
      final income = calculateMonthlyIncome(transactions);
      final expense = calculateMonthlyExpense(transactions);
      final top = calculateTopExpenseCategory(transactions);

      return DashboardSummaryModel(
        month: month,
        totalIncome: income,
        totalExpense: expense,
        balance: calculateBalance(income, expense),
        transactionCount: transactions.length,
        topExpenseCategoryName: top.name,
        topExpenseCategoryAmount: top.amount,
        // Transactions are already sorted date-desc by getTransactionsByMonth.
        // Take the first 5 as the "recent" list.
        recentTransactions: transactions.take(5).toList(),
      );
    });
  }

  // ── Pure calculation functions ─────────────────────────────────────────────

  /// Sum of all income amounts in [transactions].
  double calculateMonthlyIncome(List<TransactionModel> transactions) {
    return transactions
        .where((t) => t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Sum of all expense amounts in [transactions].
  double calculateMonthlyExpense(List<TransactionModel> transactions) {
    return transactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Income minus expense.
  double calculateBalance(double income, double expense) => income - expense;

  /// Returns the expense category with the highest total spending.
  ///
  /// Returns `(name: null, amount: 0.0)` when there are no expense
  /// transactions. Uses a named Dart record for clarity.
  ({String? name, double amount}) calculateTopExpenseCategory(
    List<TransactionModel> transactions,
  ) {
    final expenses = transactions.where((t) => t.isExpense).toList();
    if (expenses.isEmpty) return (name: null, amount: 0.0);

    final Map<String, double> totals = {};
    for (final t in expenses) {
      totals[t.categoryName] = (totals[t.categoryName] ?? 0.0) + t.amount;
    }

    final top =
        totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return (name: top.key, amount: top.value);
  }

  /// Streams the [limit] most recent transactions across all months.
  /// Delegates to [TransactionService.streamRecentTransactions].
  Stream<List<TransactionModel>> getRecentTransactions(
    String uid,
    int limit,
  ) {
    return _transactionService.streamRecentTransactions(uid, limit);
  }
}
