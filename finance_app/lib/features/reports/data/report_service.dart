import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/category_spending_model.dart';
import '../domain/financial_summary_model.dart';
import '../domain/monthly_trend_model.dart';

/// Pure read-only aggregation service.
///
/// Queries existing Firestore collections and computes analytics in memory.
/// Never writes any data. Designed for reuse by:
///   - Reports screen
///   - AI Financial Assistant (monthly context builder)
///   - Invisible Expense Audit (spending pattern analysis)
///   - Financial Health Score calculator
///   - Monthly Report Generator
class ReportService {
  ReportService(this._firestore);

  final FirebaseFirestore _firestore;

  // ── Collection references ──────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _transactions(String uid) =>
      _firestore.collection('users').doc(uid).collection('transactions');

  CollectionReference<Map<String, dynamic>> _budgets(String uid) =>
      _firestore.collection('users').doc(uid).collection('budgets');

  CollectionReference<Map<String, dynamic>> _savingGoals(String uid) =>
      _firestore.collection('users').doc(uid).collection('savingGoals');

  CollectionReference<Map<String, dynamic>> _debts(String uid) =>
      _firestore.collection('users').doc(uid).collection('debts');

  // ── Financial summary ──────────────────────────────────────────────────────

  /// Returns a full financial snapshot for [uid] and [month].
  ///
  /// Runs 4 Firestore queries in parallel (transactions, budgets, goals, debts)
  /// then aggregates the results in memory. O(1) Firestore round trips.
  Future<FinancialSummaryModel> getFinancialSummary(
    String uid,
    String month,
  ) async {
    final results = await Future.wait([
      _transactions(uid).where('month', isEqualTo: month).get(),
      _budgets(uid).where('month', isEqualTo: month).get(),
      _savingGoals(uid).get(),
      _debts(uid).get(),
    ]);

    final txSnap = results[0];
    final budgetSnap = results[1];
    final goalSnap = results[2];
    final debtSnap = results[3];

    // ── Transaction totals ────────────────────────────────────────────────
    double totalIncome = 0;
    double totalExpense = 0;
    for (final doc in txSnap.docs) {
      final amount = (doc.data()['amount'] as num).toDouble();
      if (doc.data()['type'] == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }
    }

    // ── Budget totals (spending within budgeted categories) ───────────────
    final budgetedCategoryIds = budgetSnap.docs
        .map((d) => d.data()['categoryId'] as String)
        .toSet();

    double budgetAllocated = 0;
    for (final doc in budgetSnap.docs) {
      budgetAllocated += (doc.data()['allocatedAmount'] as num).toDouble();
    }

    double budgetSpent = 0;
    for (final doc in txSnap.docs) {
      if (doc.data()['type'] == 'expense' &&
          budgetedCategoryIds.contains(doc.data()['categoryId'])) {
        budgetSpent += (doc.data()['amount'] as num).toDouble();
      }
    }

    // ── Savings totals ────────────────────────────────────────────────────
    double totalSavingsTarget = 0;
    double totalSavingsCurrent = 0;
    for (final doc in goalSnap.docs) {
      totalSavingsTarget +=
          (doc.data()['targetAmount'] as num).toDouble();
      totalSavingsCurrent +=
          (doc.data()['savedAmount'] as num? ?? 0).toDouble();
    }

    // ── Debt totals ───────────────────────────────────────────────────────
    double totalDebtAmount = 0;
    double totalDebtRemaining = 0;
    for (final doc in debtSnap.docs) {
      totalDebtAmount +=
          (doc.data()['totalAmount'] as num).toDouble();
      totalDebtRemaining +=
          (doc.data()['remainingAmount'] as num? ?? 0).toDouble();
    }

    return FinancialSummaryModel(
      month: month,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netBalance: totalIncome - totalExpense,
      budgetAllocated: budgetAllocated,
      budgetSpent: budgetSpent,
      budgetRemaining: budgetAllocated - budgetSpent,
      totalSavingsTarget: totalSavingsTarget,
      totalSavingsCurrent: totalSavingsCurrent,
      totalDebtAmount: totalDebtAmount,
      totalDebtRemaining: totalDebtRemaining,
    );
  }

  // ── Category spending ──────────────────────────────────────────────────────

  /// Returns expense spending grouped by category for [month], sorted by
  /// total spent descending.
  Future<List<CategorySpendingModel>> getCategorySpending(
    String uid,
    String month,
  ) async {
    final snap = await _transactions(uid)
        .where('month', isEqualTo: month)
        .where('type', isEqualTo: 'expense')
        .get();

    return _buildCategorySpending(snap.docs);
  }

  /// Returns the top [limit] expense categories for [month].
  Future<List<CategorySpendingModel>> getTopExpenseCategories(
    String uid,
    String month,
    int limit,
  ) async {
    final all = await getCategorySpending(uid, month);
    return all.take(limit).toList();
  }

  /// Returns the top [limit] income sources grouped by category for [month].
  Future<List<CategorySpendingModel>> getTopIncomeCategories(
    String uid,
    String month,
    int limit,
  ) async {
    final snap = await _transactions(uid)
        .where('month', isEqualTo: month)
        .where('type', isEqualTo: 'income')
        .get();

    final result = _buildCategorySpending(snap.docs);
    return result.take(limit).toList();
  }

  // ── Monthly trend ──────────────────────────────────────────────────────────

  /// Returns income/expense/balance for the last [months] calendar months,
  /// oldest to newest. Each month requires one Firestore query.
  Future<List<MonthlyTrendModel>> getMonthlyTrend(
    String uid,
    int months,
  ) async {
    final now = DateTime.now();

    final futures = List.generate(months, (i) {
      final offset = months - 1 - i;
      final dt = DateTime(now.year, now.month - offset);
      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      return _transactions(uid)
          .where('month', isEqualTo: key)
          .get()
          .then((snap) => (key: key, snap: snap));
    });

    final results = await Future.wait(futures);

    return results.map((r) {
      double income = 0;
      double expense = 0;
      for (final doc in r.snap.docs) {
        final amount = (doc.data()['amount'] as num).toDouble();
        if (doc.data()['type'] == 'income') {
          income += amount;
        } else {
          expense += amount;
        }
      }
      return MonthlyTrendModel(
        month: r.key,
        income: income,
        expense: expense,
        balance: income - expense,
      );
    }).toList();
  }

  // ── Savings progress ───────────────────────────────────────────────────────

  /// Returns an aggregated savings progress snapshot across all goals.
  ///
  /// Useful for the AI Assistant to understand overall savings health
  /// without needing a specific month context.
  Future<({double totalTarget, double totalSaved, double progressPercent})>
      calculateSavingsProgress(String uid) async {
    final snap = await _savingGoals(uid).get();

    double totalTarget = 0;
    double totalSaved = 0;
    for (final doc in snap.docs) {
      totalTarget += (doc.data()['targetAmount'] as num).toDouble();
      totalSaved +=
          (doc.data()['savedAmount'] as num? ?? 0).toDouble();
    }

    return (
      totalTarget: totalTarget,
      totalSaved: totalSaved,
      progressPercent:
          totalTarget > 0 ? totalSaved / totalTarget : 0.0,
    );
  }

  // ── Debt progress ──────────────────────────────────────────────────────────

  /// Returns an aggregated debt repayment snapshot across all debts.
  ///
  /// Useful for the AI Assistant and Financial Health Score.
  Future<({double totalDebt, double totalRemaining, double repaidPercent})>
      calculateDebtProgress(String uid) async {
    final snap = await _debts(uid).get();

    double totalDebt = 0;
    double totalRemaining = 0;
    for (final doc in snap.docs) {
      totalDebt += (doc.data()['totalAmount'] as num).toDouble();
      totalRemaining +=
          (doc.data()['remainingAmount'] as num? ?? 0).toDouble();
    }

    final repaid = totalDebt - totalRemaining;
    return (
      totalDebt: totalDebt,
      totalRemaining: totalRemaining,
      repaidPercent: totalDebt > 0 ? repaid / totalDebt : 0.0,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Groups transaction documents by categoryId, calculates totals and
  /// percentages, returns sorted by totalSpent descending.
  List<CategorySpendingModel> _buildCategorySpending(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Map<String, double> totals = {};
    final Map<String, String> names = {};
    double grandTotal = 0;

    for (final doc in docs) {
      final amount = (doc.data()['amount'] as num).toDouble();
      final catId = doc.data()['categoryId'] as String;
      final catName = doc.data()['categoryName'] as String;
      totals[catId] = (totals[catId] ?? 0.0) + amount;
      names[catId] = catName;
      grandTotal += amount;
    }

    final result = totals.entries
        .map(
          (e) => CategorySpendingModel(
            categoryId: e.key,
            categoryName: names[e.key] ?? e.key,
            totalSpent: e.value,
            percentage: grandTotal > 0 ? e.value / grandTotal : 0.0,
          ),
        )
        .toList()
      ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

    return result;
  }
}
