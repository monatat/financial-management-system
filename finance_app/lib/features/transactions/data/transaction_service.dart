import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/transaction_model.dart';

/// Manages transactions in Firestore.
///
/// Stored at: users/{uid}/transactions/{transactionId}
///
/// NOTE: This service does NOT update budget spentAmount.
/// The Budget module (Phase 6) will calculate spending by querying
/// getTransactionsByMonth filtered by categoryId.
class TransactionService {
  TransactionService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _transactions(String uid) =>
      _firestore.collection('users').doc(uid).collection('transactions');

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Saves a new transaction document.
  /// The [transactionId] inside [transaction] is overwritten with the
  /// Firestore auto-generated ID.
  Future<void> addTransaction(
    String uid,
    TransactionModel transaction,
  ) async {
    final docRef = _transactions(uid).doc();
    await docRef.set(
      transaction.copyWith(transactionId: docRef.id).toMap(),
    );
  }

  /// Updates specific fields on a transaction.
  /// Always stamps [updatedAt] with a server timestamp.
  ///
  /// If [data] contains 'date', it must also contain 'month' so the
  /// denormalized month field stays consistent.
  Future<void> updateTransaction(
    String uid,
    String transactionId,
    Map<String, dynamic> data,
  ) async {
    await _transactions(uid).doc(transactionId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Permanently deletes a transaction.
  /// Transactions use hard delete (no isDeleted flag) because they
  /// are user-owned records with no referential constraints.
  Future<void> deleteTransaction(String uid, String transactionId) async {
    await _transactions(uid).doc(transactionId).delete();
  }

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Streams all transactions for a given month.
  /// [month] must be in "YYYY-MM" format (e.g. "2026-05").
  /// Results are sorted by date descending in Dart to avoid composite indexes.
  Stream<List<TransactionModel>> getTransactionsByMonth(
    String uid,
    String month,
  ) {
    return _transactions(uid)
        .where('month', isEqualTo: month)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => TransactionModel.fromMap(doc.data()))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  /// Streams all transactions for a specific category.
  Stream<List<TransactionModel>> getTransactionsByCategory(
    String uid,
    String categoryId,
  ) {
    return _transactions(uid)
        .where('categoryId', isEqualTo: categoryId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => TransactionModel.fromMap(doc.data()))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  /// Streams all transactions of a given type ("income" or "expense").
  Stream<List<TransactionModel>> getTransactionsByType(
    String uid,
    String type,
  ) {
    return _transactions(uid)
        .where('type', isEqualTo: type)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => TransactionModel.fromMap(doc.data()))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  /// Streams the [limit] most recent transactions across all months.
  /// Used by the Dashboard module to show a "Recent transactions" card.
  Stream<List<TransactionModel>> streamRecentTransactions(
    String uid,
    int limit,
  ) {
    return _transactions(uid)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => TransactionModel.fromMap(doc.data()))
            .toList());
  }
}
