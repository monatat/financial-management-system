import 'budget_model.dart';

/// Combines a [BudgetModel] with its calculated spending for the month.
///
/// This model is computed — never stored in Firestore.
/// It is produced by the [budgetsWithSpendingProvider] which joins
/// the budgets stream with the transactions stream for the same month.
class BudgetWithSpendingModel {
  const BudgetWithSpendingModel({
    required this.budget,
    required this.spentAmount,
    required this.remainingAmount,
    required this.usagePercent,
    required this.isOverspent,
  });

  /// The underlying budget document.
  final BudgetModel budget;

  /// Sum of expense transactions for budget.categoryId in budget.month.
  final double spentAmount;

  /// budget.allocatedAmount − spentAmount. Negative when overspent.
  final double remainingAmount;

  /// spentAmount / allocatedAmount.
  /// May exceed 1.0 when overspent; use [clampedPercent] for progress bars.
  final double usagePercent;

  /// True when spentAmount > budget.allocatedAmount.
  final bool isOverspent;

  // ── Convenience ───────────────────────────────────────────────────────────

  /// Progress-bar value clamped to [0.0, 1.0].
  double get clampedPercent => usagePercent.clamp(0.0, 1.0);

  /// Percentage string for display (e.g. "73%").
  String get percentLabel =>
      '${(usagePercent * 100).clamp(0, 999).toStringAsFixed(0)}%';
}
