/// Aggregated financial snapshot for one month.
///
/// Computed by [ReportService.getFinancialSummary] from live Firestore data.
/// Never stored in Firestore.
///
/// Designed for reuse by:
/// - Reports screen
/// - AI Financial Assistant (monthly context)
/// - Financial Health Score
/// - Monthly Report Generator
class FinancialSummaryModel {
  const FinancialSummaryModel({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.budgetAllocated,
    required this.budgetSpent,
    required this.budgetRemaining,
    required this.totalSavingsTarget,
    required this.totalSavingsCurrent,
    required this.totalDebtAmount,
    required this.totalDebtRemaining,
  });

  /// "YYYY-MM" — the month this summary covers.
  final String month;

  // ── Transaction totals ────────────────────────────────────────────────────

  final double totalIncome;
  final double totalExpense;

  /// totalIncome − totalExpense.
  final double netBalance;

  // ── Budget totals ─────────────────────────────────────────────────────────
  // Calculated from budgets documents + matching expense transactions.

  final double budgetAllocated;
  final double budgetSpent;
  final double budgetRemaining;

  // ── Savings totals (across all goals, any month) ──────────────────────────

  final double totalSavingsTarget;
  final double totalSavingsCurrent;

  // ── Debt totals (all outstanding debts) ───────────────────────────────────

  final double totalDebtAmount;
  final double totalDebtRemaining;

  // ── Computed ──────────────────────────────────────────────────────────────

  double get budgetUsagePercent =>
      budgetAllocated > 0 ? budgetSpent / budgetAllocated : 0.0;

  double get savingsProgressPercent =>
      totalSavingsTarget > 0
          ? totalSavingsCurrent / totalSavingsTarget
          : 0.0;

  double get debtRepaidPercent =>
      totalDebtAmount > 0
          ? (totalDebtAmount - totalDebtRemaining) / totalDebtAmount
          : 0.0;

  double get totalDebtPaid => totalDebtAmount - totalDebtRemaining;

  bool get hasBudgets => budgetAllocated > 0;
  bool get hasTransactions => totalIncome > 0 || totalExpense > 0;
  bool get hasSavings => totalSavingsTarget > 0;
  bool get hasDebts => totalDebtAmount > 0;
}
