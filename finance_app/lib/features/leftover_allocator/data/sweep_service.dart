import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/month_end_sweep_model.dart';

/// Manages the month-end leftover sweep lifecycle.
///
/// Does NOT read or write the transactions collection for any purpose other
/// than summing amounts. Old transactions are never modified.
///
/// Firestore path: users/{uid}/monthEndSweeps/{month}
class SweepService {
  SweepService(this._firestore);

  final FirebaseFirestore _firestore;

  // ── Collection references ──────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _transactions(String uid) =>
      _firestore.collection('users').doc(uid).collection('transactions');

  CollectionReference<Map<String, dynamic>> _savingGoals(String uid) =>
      _firestore.collection('users').doc(uid).collection('savingGoals');

  CollectionReference<Map<String, dynamic>> _debts(String uid) =>
      _firestore.collection('users').doc(uid).collection('debts');

  CollectionReference<Map<String, dynamic>> _sweeps(String uid) =>
      _firestore.collection('users').doc(uid).collection('monthEndSweeps');

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns the previous calendar month key, e.g. "2026-05" when today
  /// is in June 2026.
  static String previousMonthKey() {
    final now = DateTime.now();
    // Dart correctly handles month = 0 as December of prior year.
    final prev = DateTime(now.year, now.month - 1);
    return '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
  }

  /// Reads the sweep document for [month].  Returns null if none exists.
  Future<MonthEndSweepModel?> getSweep(String uid, String month) async {
    final doc = await _sweeps(uid).doc(month).get();
    if (!doc.exists || doc.data() == null) return null;
    return MonthEndSweepModel.fromMap(doc.data()!);
  }

  /// Returns the pending sweep for the previous month, or null if none.
  Future<MonthEndSweepModel?> checkPendingSweep(String uid) async {
    final sweep = await getSweep(uid, previousMonthKey());
    if (sweep == null || !sweep.isPending) return null;
    return sweep;
  }

  /// Calculates the leftover for [previousMonth] without saving anything.
  ///
  /// Formula:
  ///   leftover = totalIncome - totalExpenses - allocatedSavings - allocatedDebt
  Future<MonthEndSweepModel> calculateLeftover(
    String uid,
    String previousMonth,
  ) async {
    final totalIncome = await _sumTransactions(uid, previousMonth, 'income');
    final totalExpenses = await _sumTransactions(uid, previousMonth, 'expense');
    final allocatedSavings = await _sumSavingContributions(uid, previousMonth);
    final allocatedDebt = await _sumDebtPayments(uid, previousMonth);

    final leftover = totalIncome -
        totalExpenses -
        allocatedSavings -
        allocatedDebt;

    return MonthEndSweepModel(
      sweepId: previousMonth,
      month: previousMonth,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      allocatedSavings: allocatedSavings,
      allocatedDebt: allocatedDebt,
      leftoverAmount: leftover < 0 ? 0 : leftover,
      allocations: const [],
      status: 'pending',
      createdAt: DateTime.now(),
    );
  }

  /// Checks whether a sweep is needed for the previous month and creates one
  /// if:
  ///   - No sweep document exists yet, AND
  ///   - The calculated leftover > 0
  ///
  /// Does nothing if a sweep already exists (any status) to prevent
  /// duplicate popups.
  Future<void> createPendingSweepIfNeeded(String uid) async {
    final month = previousMonthKey();

    // Already exists (pending, completed, or skipped) → nothing to do
    final existing = await getSweep(uid, month);
    if (existing != null) return;

    // Calculate leftover
    final sweep = await calculateLeftover(uid, month);

    // Only create if there is actual leftover
    if (sweep.leftoverAmount <= 0) return;

    await _sweeps(uid).doc(month).set(sweep.toMap());
  }

  /// Allocates the leftover as described by [allocations], writes
  /// contributions/payments to the respective subcollections, and marks the
  /// sweep as completed.
  Future<void> completeSweep(
    String uid,
    MonthEndSweepModel sweep,
    List<AllocationItem> allocations,
  ) async {
    final batch = _firestore.batch();
    final now = Timestamp.now();

    for (final alloc in allocations) {
      if (alloc.destinationType == 'savingGoal') {
        final ref = _savingGoals(uid)
            .doc(alloc.destinationId)
            .collection('contributions')
            .doc();
        batch.set(ref, {
          'contributionId': ref.id,
          'amount': alloc.amount,
          'date': now,
          'note': 'Leftover allocation — ${sweep.month}',
          'createdAt': now,
        });
      } else if (alloc.destinationType == 'debt') {
        final ref = _debts(uid)
            .doc(alloc.destinationId)
            .collection('payments')
            .doc();
        batch.set(ref, {
          'paymentId': ref.id,
          'amount': alloc.amount,
          'date': now,
          'note': 'Leftover allocation — ${sweep.month}',
          'createdAt': now,
        });
      }
    }

    // Mark sweep as completed, storing how much (if any) was not allocated.
    final totalAllocated =
        allocations.fold<double>(0.0, (s, a) => s + a.amount);
    final remaining = sweep.leftoverAmount - totalAllocated;

    batch.update(_sweeps(uid).doc(sweep.month), {
      'allocations': allocations.map((a) => a.toMap()).toList(),
      'status': 'completed',
      'completedAt': now,
      'remainingUnallocatedAmount': remaining < 0 ? 0.0 : remaining,
    });

    await batch.commit();

    // Recalculate savedAmount / remainingAmount for affected goals and debts
    for (final alloc in allocations) {
      if (alloc.destinationType == 'savingGoal') {
        await _recalculateSavedAmount(uid, alloc.destinationId);
      } else if (alloc.destinationType == 'debt') {
        await _recalculateRemainingAmount(uid, alloc.destinationId);
      }
    }
  }

  /// Marks the sweep as skipped so the popup never shows again this month.
  Future<void> skipSweep(String uid, String month) async {
    await _sweeps(uid).doc(month).update({
      'status': 'skipped',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<double> _sumTransactions(
    String uid,
    String month,
    String type,
  ) async {
    final snap = await _transactions(uid)
        .where('month', isEqualTo: month)
        .where('type', isEqualTo: type)
        .get();
    return snap.docs
        .map((d) => (d.data()['amount'] as num).toDouble())
        .fold<double>(0.0, (s, a) => s + a);
  }

  Future<double> _sumSavingContributions(
    String uid,
    String month,
  ) async {
    final goalsSnap = await _savingGoals(uid).get();
    double total = 0;

    for (final goalDoc in goalsSnap.docs) {
      final contribSnap = await goalDoc.reference
          .collection('contributions')
          .get();
      for (final doc in contribSnap.docs) {
        final date = (doc.data()['date'] as Timestamp?)?.toDate();
        if (date != null && _monthKey(date) == month) {
          total += (doc.data()['amount'] as num).toDouble();
        }
      }
    }
    return total;
  }

  Future<double> _sumDebtPayments(String uid, String month) async {
    final debtsSnap = await _debts(uid).get();
    double total = 0;

    for (final debtDoc in debtsSnap.docs) {
      final paySnap = await debtDoc.reference.collection('payments').get();
      for (final doc in paySnap.docs) {
        final date = (doc.data()['date'] as Timestamp?)?.toDate();
        if (date != null && _monthKey(date) == month) {
          total += (doc.data()['amount'] as num).toDouble();
        }
      }
    }
    return total;
  }

  /// Recalculates savedAmount and isCompleted on a saving goal.
  Future<void> _recalculateSavedAmount(String uid, String goalId) async {
    final snap = await _savingGoals(uid)
        .doc(goalId)
        .collection('contributions')
        .get();
    final totalSaved = snap.docs
        .map((d) => (d.data()['amount'] as num).toDouble())
        .fold<double>(0.0, (s, a) => s + a);

    final goalDoc = await _savingGoals(uid).doc(goalId).get();
    if (!goalDoc.exists || goalDoc.data() == null) return;
    final targetAmount =
        (goalDoc.data()!['targetAmount'] as num).toDouble();

    await _savingGoals(uid).doc(goalId).update({
      'savedAmount': totalSaved,
      'isCompleted': totalSaved >= targetAmount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Recalculates remainingAmount and isSettled on a debt.
  Future<void> _recalculateRemainingAmount(
    String uid,
    String debtId,
  ) async {
    final snap =
        await _debts(uid).doc(debtId).collection('payments').get();
    final totalPaid = snap.docs
        .map((d) => (d.data()['amount'] as num).toDouble())
        .fold<double>(0.0, (s, a) => s + a);

    final debtDoc = await _debts(uid).doc(debtId).get();
    if (!debtDoc.exists || debtDoc.data() == null) return;
    final totalAmount =
        (debtDoc.data()!['totalAmount'] as num).toDouble();

    final remaining = (totalAmount - totalPaid).clamp(0.0, totalAmount);
    await _debts(uid).doc(debtId).update({
      'remainingAmount': remaining,
      'isSettled': remaining <= 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Returns a "YYYY-MM" key for any [DateTime].
  String _monthKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
}
