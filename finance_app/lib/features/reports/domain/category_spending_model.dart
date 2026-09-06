/// Spending breakdown for one expense (or income) category in a given month.
///
/// Computed by [ReportService.getCategorySpending] from transaction data.
/// Never stored in Firestore.
class CategorySpendingModel {
  const CategorySpendingModel({
    required this.categoryId,
    required this.categoryName,
    required this.totalSpent,
    required this.percentage,
  });

  final String categoryId;
  final String categoryName;

  /// Total amount spent in this category for the month.
  final double totalSpent;

  /// This category's share of total spending (0.0 – 1.0).
  final double percentage;

  // ── Display helpers ────────────────────────────────────────────────────────

  String get percentLabel =>
      '${(percentage * 100).toStringAsFixed(1)}%';

  // ── Immutable update ───────────────────────────────────────────────────────

  CategorySpendingModel copyWith({
    String? categoryId,
    String? categoryName,
    double? totalSpent,
    double? percentage,
  }) {
    return CategorySpendingModel(
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      totalSpent: totalSpent ?? this.totalSpent,
      percentage: percentage ?? this.percentage,
    );
  }
}
