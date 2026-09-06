import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../transactions/presentation/transaction_provider.dart';
import '../data/dashboard_service.dart';
import '../domain/dashboard_summary_model.dart';

// ── Service provider ───────────────────────────────────────────────────────────

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService(ref.read(transactionServiceProvider));
});

// ── Current month helper ───────────────────────────────────────────────────────

/// Returns the current month in "YYYY-MM" format (e.g. "2026-05").
String currentMonthKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

// ── Dashboard summary providers ────────────────────────────────────────────────

/// Streams the [DashboardSummaryModel] for the current calendar month.
///
/// Re-emits automatically whenever transactions are added, edited, or deleted,
/// so both mobile and web dashboards stay live without any manual refresh.
final currentMonthDashboardProvider =
    StreamProvider.autoDispose<DashboardSummaryModel>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return const Stream.empty();

  return ref
      .watch(dashboardServiceProvider)
      .getDashboardSummary(user.uid, currentMonthKey());
});

/// Streams a [DashboardSummaryModel] for any given [month] (family version).
/// Used when a screen needs to display a month other than the current one.
final dashboardSummaryProvider = StreamProvider.autoDispose
    .family<DashboardSummaryModel, String>((ref, month) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return const Stream.empty();

  return ref
      .watch(dashboardServiceProvider)
      .getDashboardSummary(user.uid, month);
});
