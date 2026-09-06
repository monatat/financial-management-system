import '../../transactions/domain/transaction_model.dart';

/// Computed monthly summary for the dashboard.
///
/// This model is never stored in Firestore — it is derived on the client
/// by mapping the transactions stream through [DashboardService].
class DashboardSummaryModel {
  const DashboardSummaryModel({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.transactionCount,
    this.topExpenseCategoryName,
    required this.topExpenseCategoryAmount,
    required this.recentTransactions,
  });

  /// "YYYY-MM" — the month this summary covers.
  final String month;

  /// Sum of all income transaction amounts for [month].
  final double totalIncome;

  /// Sum of all expense transaction amounts for [month].
  final double totalExpense;

  /// totalIncome − totalExpense.
  final double balance;

  /// Total number of transactions (income + expense) in [month].
  final int transactionCount;

  /// Name of the expense category with the highest total spending,
  /// or null if there are no expense transactions.
  final String? topExpenseCategoryName;

  /// Total amount spent in [topExpenseCategoryName]. 0.0 when null.
  final double topExpenseCategoryAmount;

  /// Up to 5 most recent transactions for [month], sorted date descending.
  final List<TransactionModel> recentTransactions;

  // ── Convenience ───────────────────────────────────────────────────────────

  bool get hasTransactions => transactionCount > 0;
  bool get hasExpenses => totalExpense > 0;
  bool get isBalancePositive => balance >= 0;
}
