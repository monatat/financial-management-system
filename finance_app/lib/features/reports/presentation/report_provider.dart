import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/report_service.dart';
import '../domain/category_spending_model.dart';
import '../domain/financial_summary_model.dart';
import '../domain/monthly_trend_model.dart';

// ── Service provider ───────────────────────────────────────────────────────────

final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService(FirebaseFirestore.instance);
});

// ── Financial summary ──────────────────────────────────────────────────────────

/// Provides [FinancialSummaryModel] for a given [month] ("YYYY-MM").
/// Uses FutureProvider.autoDispose so stale results are discarded when the
/// screen leaves the widget tree or the selected month changes.
final financialSummaryProvider = FutureProvider.autoDispose
    .family<FinancialSummaryModel, String>((ref, month) async {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) throw Exception('Not authenticated');
  return ref
      .read(reportServiceProvider)
      .getFinancialSummary(user.uid, month);
});

// ── Category spending ──────────────────────────────────────────────────────────

/// Provides expense category spending for a given [month].
final categorySpendingProvider = FutureProvider.autoDispose
    .family<List<CategorySpendingModel>, String>((ref, month) async {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) throw Exception('Not authenticated');
  return ref
      .read(reportServiceProvider)
      .getCategorySpending(user.uid, month);
});

/// Provides top income categories for a given [month].
final topIncomeProvider = FutureProvider.autoDispose
    .family<List<CategorySpendingModel>, String>((ref, month) async {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) throw Exception('Not authenticated');
  return ref
      .read(reportServiceProvider)
      .getTopIncomeCategories(user.uid, month, 5);
});

// ── Monthly trend ──────────────────────────────────────────────────────────────

/// Provides the last [months] months of income/expense trend data.
///
/// The [months] parameter is the family key so callers can request
/// different ranges (e.g. 3, 6, or 12 months).
final monthlyTrendProvider = FutureProvider.autoDispose
    .family<List<MonthlyTrendModel>, int>((ref, months) async {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) throw Exception('Not authenticated');
  return ref
      .read(reportServiceProvider)
      .getMonthlyTrend(user.uid, months);
});

