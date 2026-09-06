import 'package:cloud_firestore/cloud_firestore.dart';
import '../../transactions/domain/transaction_model.dart';
import '../domain/audit_decision_model.dart';
import '../domain/audit_result_model.dart';

/// Detects invisible expense patterns (subscriptions and micro-habits) from
/// the user's expense transaction history.
///
/// Detection is read-only — this service NEVER modifies or deletes transactions.
/// Results are saved to users/{uid}/invisibleExpenseAudits/{month}.
class AuditService {
  AuditService(this._firestore);

  final FirebaseFirestore _firestore;

  // ── Thresholds ─────────────────────────────────────────────────────────────

  /// Expense amounts below this (in the user's base currency) are considered
  /// micro-transactions eligible for micro-habit detection.
  static const double _microThreshold = 10.0;

  /// Minimum occurrences (total in month) to flag as a micro-habit.
  static const int _microMinOccurrences = 4;

  /// Amount tolerance for subscription matching (5 %).
  static const double _subscriptionTolerance = 0.05;

  /// Number of months of history used for subscription detection.
  static const int _subscriptionLookbackMonths = 3;

  // ── Collection references ──────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _transactions(String uid) =>
      _firestore.collection('users').doc(uid).collection('transactions');

  CollectionReference<Map<String, dynamic>> _audits(String uid) =>
      _firestore.collection('users').doc(uid).collection('invisibleExpenseAudits');

  CollectionReference<Map<String, dynamic>> _decisions(String uid) =>
      _firestore.collection('users').doc(uid).collection('auditDecisions');

  // ── Decision persistence ────────────────────────────────────────────────────

  /// Saves (or overwrites) a user decision for a detected subscription.
  ///
  /// Document ID is derived from the normalised description via
  /// [AuditDecisionModel.decisionId] so the same subscription always maps to
  /// the same document.
  Future<void> saveDecision(String uid, AuditDecisionModel decision) async {
    final id = AuditDecisionModel.decisionId(decision.description);
    await _decisions(uid).doc(id).set(decision.toMap());
  }

  /// Returns all decisions for [month] keyed by normalised description,
  /// so callers can do an O(1) look-up per subscription item.
  Future<Map<String, AuditDecisionModel>> getDecisions(
    String uid,
    String month,
  ) async {
    final snap = await _decisions(uid)
        .where('month', isEqualTo: month)
        .get();
    final result = <String, AuditDecisionModel>{};
    for (final doc in snap.docs) {
      if (doc.data().isEmpty) continue;
      final d = AuditDecisionModel.fromMap(doc.data());
      result[_normalise(d.description)] = d;
    }
    return result;
  }

  // ── Main entry points ──────────────────────────────────────────────────────

  /// Runs the full audit for [uid] and [month], saves the result to Firestore,
  /// and returns the [AuditResultModel].
  ///
  /// Subscription detection uses the last [_subscriptionLookbackMonths] months.
  /// Micro-habit detection uses only the current [month].
  Future<AuditResultModel> runAudit(String uid, String month) async {
    // ── Load transaction data ────────────────────────────────────────────────
    final baseDate = _parseMonth(month);

    // Collect transactions from the lookback window for subscription detection
    final allTransactions = <TransactionModel>[];
    for (int i = 0; i < _subscriptionLookbackMonths; i++) {
      final dt = DateTime(baseDate.year, baseDate.month - i);
      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      final snap =
          await _transactions(uid).where('month', isEqualTo: key).get();
      for (final doc in snap.docs) {
        allTransactions.add(TransactionModel.fromMap(doc.data()));
      }
    }

    // Current month only (for micro-habit detection)
    final currentMonthTx =
        allTransactions.where((t) => t.month == month).toList();

    // ── Run detectors ────────────────────────────────────────────────────────
    final subscriptions = detectSubscriptions(allTransactions);
    final microHabits = detectMicroHabits(currentMonthTx);

    // ── Aggregate ────────────────────────────────────────────────────────────
    final subscriptionLeakage =
        subscriptions.fold<double>(0.0, (s, i) => s + i.amount);
    final microLeakage =
        microHabits.fold<double>(0.0, (s, i) => s + i.totalAmount);

    final result = AuditResultModel(
      auditId: month, // month is the document key
      month: month,
      generatedAt: DateTime.now(),
      subscriptions: subscriptions,
      microHabits: microHabits,
      totalLeakage: subscriptionLeakage + microLeakage,
    );

    await saveAuditResult(uid, result);
    return result;
  }

  /// Returns the saved audit result for [month], or null if none exists.
  Future<AuditResultModel?> getAuditResult(
    String uid,
    String month,
  ) async {
    final doc = await _audits(uid).doc(month).get();
    if (!doc.exists || doc.data() == null) return null;
    return AuditResultModel.fromMap(doc.data()!);
  }

  /// Persists [result] to Firestore. Uses the month as the document ID so
  /// re-running the audit overwrites the previous result for that month.
  Future<void> saveAuditResult(String uid, AuditResultModel result) async {
    await _audits(uid).doc(result.month).set(result.toMap());
  }

  // ── Detection logic ────────────────────────────────────────────────────────

  /// Detects recurring subscriptions across the provided [transactions].
  ///
  /// A subscription is flagged when:
  ///   - type == "expense"
  ///   - Same description (case-insensitive, trimmed) in ≥ 2 distinct months
  ///   - Amounts are consistent within [_subscriptionTolerance] (5 %)
  List<SubscriptionItem> detectSubscriptions(
    List<TransactionModel> transactions,
  ) {
    final expenses =
        transactions.where((t) => t.isExpense).toList();

    // Group by normalised description
    final Map<String, List<TransactionModel>> grouped = {};
    for (final t in expenses) {
      final key = _normalise(t.description);
      grouped.putIfAbsent(key, () => []).add(t);
    }

    final result = <SubscriptionItem>[];

    for (final entry in grouped.entries) {
      final txList = entry.value;

      // Must appear in at least 2 different months
      final distinctMonths = txList.map((t) => t.month).toSet();
      if (distinctMonths.length < 2) continue;

      // Amounts must be consistent (all within ±5 % of the average)
      final amounts = txList.map((t) => t.amount).toList();
      final avg = amounts.reduce((a, b) => a + b) / amounts.length;
      final consistent =
          amounts.every((a) => avg == 0 || ((a - avg).abs() / avg) <= _subscriptionTolerance);
      if (!consistent) continue;

      result.add(SubscriptionItem(
        description: txList.first.description,
        amount: avg,
        occurrences: txList.length,
        projectedAnnual: calculateAnnualProjection(avg, 12),
        transactionIds: txList.map((t) => t.transactionId).toList(),
      ));
    }

    result.sort((a, b) => b.projectedAnnual.compareTo(a.projectedAnnual));
    return result;
  }

  /// Detects micro-habit spending from the provided [transactions].
  ///
  /// A micro-habit is flagged when:
  ///   - type == "expense"
  ///   - amount < [_microThreshold] (< 10 in base currency)
  ///   - Same description (≥ [_microMinOccurrences] times total) OR
  ///     ≥ 4 occurrences in a single ISO week
  List<MicroHabitItem> detectMicroHabits(
    List<TransactionModel> transactions,
  ) {
    final micro = transactions
        .where((t) => t.isExpense && t.amount < _microThreshold)
        .toList();

    // Group by normalised description
    final Map<String, List<TransactionModel>> grouped = {};
    for (final t in micro) {
      final key = _normalise(t.description);
      grouped.putIfAbsent(key, () => []).add(t);
    }

    final result = <MicroHabitItem>[];

    for (final entry in grouped.entries) {
      final txList = entry.value;

      // Check total count threshold
      final enoughTotal = txList.length >= _microMinOccurrences;

      // Also check weekly pattern: ≥ 4 in any ISO week
      final byWeek = <String, int>{};
      for (final t in txList) {
        final wk = _isoWeekKey(t.date);
        byWeek[wk] = (byWeek[wk] ?? 0) + 1;
      }
      final weeklySpike = byWeek.values.any((c) => c >= 4);

      if (!enoughTotal && !weeklySpike) continue;

      final totalAmount =
          txList.fold<double>(0.0, (s, t) => s + t.amount);

      result.add(MicroHabitItem(
        description: txList.first.description,
        count: txList.length,
        totalAmount: totalAmount,
        // Monthly total × 12 = annual projection
        projectedAnnual: calculateAnnualProjection(totalAmount, 12),
        transactionIds: txList.map((t) => t.transactionId).toList(),
      ));
    }

    result.sort((a, b) => b.projectedAnnual.compareTo(a.projectedAnnual));
    return result;
  }

  /// Returns the estimated annual cost of an expense that occurs [frequency]
  /// times per year with a per-occurrence [amount].
  ///
  /// Examples:
  ///   Monthly subscription RM 9.90 → calculateAnnualProjection(9.90, 12) = 118.80
  ///   Weekly coffee RM 8.00 → calculateAnnualProjection(8.00, 52) = 416.00
  double calculateAnnualProjection(double amount, int frequency) {
    return amount * frequency;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Normalises a description string for comparison.
  String _normalise(String s) => s.trim().toLowerCase();

  /// Returns an ISO-week key for grouping (format: "YYYY-Www").
  String _isoWeekKey(DateTime date) {
    // Move to Monday of the same week
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return '${monday.year}-W${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  /// Parses a "YYYY-MM" string into a [DateTime] on the 1st of that month.
  DateTime _parseMonth(String month) {
    final parts = month.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }
}
