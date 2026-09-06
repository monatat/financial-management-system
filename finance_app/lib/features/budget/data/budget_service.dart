import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/budget_model.dart';
import '../domain/budget_with_spending_model.dart';

/// Manages monthly category budgets in Firestore.
///
/// Stored at: users/{uid}/budgets/{budgetId}
///
/// Spending is NOT stored on the budget document. It is calculated at
/// query time from the transactions collection.
class BudgetService {
  BudgetService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _budgets(String uid) =>
      _firestore.collection('users').doc(uid).collection('budgets');

  // Transactions are queried directly here to avoid a circular service
  // dependency. BudgetService only reads transactions; it never writes them.
  CollectionReference<Map<String, dynamic>> _transactions(String uid) =>
      _firestore.collection('users').doc(uid).collection('transactions');

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Creates a new budget.
  /// Throws [Exception] if a budget for the same category and month
  /// already exists — prevents accidental duplicates.
  Future<void> createBudget(String uid, BudgetModel budget) async {
    final existing = await getBudgetByCategoryAndMonth(
      uid,
      budget.categoryId,
      budget.month,
    );
    if (existing != null) {
      throw Exception(
        'A budget for "${budget.categoryName}" already exists '
        'for ${budget.month}.',
      );
    }

    final docRef = _budgets(uid).doc();
    await docRef.set(budget.copyWith(budgetId: docRef.id).toMap());
  }

  /// Updates fields on an existing budget document.
  Future<void> updateBudget(
    String uid,
    String budgetId,
    Map<String, dynamic> data,
  ) async {
    await _budgets(uid).doc(budgetId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Permanently deletes a budget document.
  Future<void> deleteBudget(String uid, String budgetId) async {
    await _budgets(uid).doc(budgetId).delete();
  }

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Streams all budgets for [month], sorted alphabetically by category name.
  Stream<List<BudgetModel>> getBudgetsByMonth(String uid, String month) {
    return _budgets(uid)
        .where('month', isEqualTo: month)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => BudgetModel.fromMap(doc.data()))
          .toList()
        ..sort((a, b) => a.categoryName.compareTo(b.categoryName));
      return list;
    });
  }

  /// Returns the budget for a specific category and month, or null if none.
  /// Used for duplicate-budget checks before creating a new one.
  Future<BudgetModel?> getBudgetByCategoryAndMonth(
    String uid,
    String categoryId,
    String month,
  ) async {
    final snap = await _budgets(uid)
        .where('categoryId', isEqualTo: categoryId)
        .where('month', isEqualTo: month)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return BudgetModel.fromMap(snap.docs.first.data());
  }

  // ── Spending calculation ───────────────────────────────────────────────────

  /// Returns the total amount spent in [categoryId] for [month].
  /// Queries expense transactions directly — no manual updates needed.
  Future<double> calculateSpentForCategory(
    String uid,
    String categoryId,
    String month,
  ) async {
    final snap = await _transactions(uid)
        .where('type', isEqualTo: 'expense')
        .where('month', isEqualTo: month)
        .where('categoryId', isEqualTo: categoryId)
        .get();

    return snap.docs
        .map((doc) => (doc.data()['amount'] as num).toDouble())
        .fold<double>(0.0, (total, amount) => total + amount);
  }

  /// Returns all budgets for [month] combined with their calculated spending.
  ///
  /// This version makes one query per budget (suitable for one-off reads).
  /// For real-time reactive UI, prefer [budgetsWithSpendingProvider] which
  /// combines two live streams without polling.
  Future<List<BudgetWithSpendingModel>> getBudgetsWithSpending(
    String uid,
    String month,
  ) async {
    final snap = await _budgets(uid).where('month', isEqualTo: month).get();
    final budgets = snap.docs
        .map((doc) => BudgetModel.fromMap(doc.data()))
        .toList()
      ..sort((a, b) => a.categoryName.compareTo(b.categoryName));

    final results = await Future.wait(budgets.map((budget) async {
      final spent = await calculateSpentForCategory(
        uid,
        budget.categoryId,
        month,
      );
      final remaining = budget.allocatedAmount - spent;
      final percent =
          budget.allocatedAmount > 0 ? spent / budget.allocatedAmount : 0.0;

      return BudgetWithSpendingModel(
        budget: budget,
        spentAmount: spent,
        remainingAmount: remaining,
        usagePercent: percent,
        isOverspent: spent > budget.allocatedAmount,
      );
    }));

    return results;
  }
}
