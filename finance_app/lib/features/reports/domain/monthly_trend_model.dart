/// Income, expense, and balance data for one calendar month.
///
/// Used by [ReportService.getMonthlyTrend] to build a historical trend.
/// Never stored in Firestore.
class MonthlyTrendModel {
  const MonthlyTrendModel({
    required this.month,
    required this.income,
    required this.expense,
    required this.balance,
  });

  /// "YYYY-MM" format.
  final String month;

  final double income;
  final double expense;

  /// income − expense.
  final double balance;

  // ── Display helpers ────────────────────────────────────────────────────────

  static const _names = [
    '',
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Short label for display, e.g. "May 2026".
  String get monthLabel {
    final parts = month.split('-');
    if (parts.length < 2) return month;
    final m = int.tryParse(parts[1]) ?? 0;
    return '${m > 0 && m < 13 ? _names[m] : parts[1]} ${parts[0]}';
  }

  bool get isPositive => balance >= 0;
}
