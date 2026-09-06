import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/debt_model.dart';
import '../domain/debt_payment_model.dart';

/// Manages debts and their payment subcollections in Firestore.
///
/// Debt path:     users/{uid}/debts/{debtId}
/// Payment path:  users/{uid}/debts/{debtId}/payments/{paymentId}
///
/// [remainingAmount] is NOT updated by transactions. It is maintained solely
/// by [recalculateRemainingAmount], which is called after every payment
/// add or delete.
class DebtService {
  DebtService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _debts(String uid) =>
      _firestore.collection('users').doc(uid).collection('debts');

  CollectionReference<Map<String, dynamic>> _payments(
    String uid,
    String debtId,
  ) =>
      _debts(uid).doc(debtId).collection('payments');

  // ── Debt CRUD ──────────────────────────────────────────────────────────────

  /// Creates a new debt.
  /// [remainingAmount] is initialised to [totalAmount] and [isSettled] = false.
  Future<void> createDebt(String uid, DebtModel debt) async {
    final docRef = _debts(uid).doc();
    await docRef.set(
      debt
          .copyWith(
            debtId: docRef.id,
            remainingAmount: debt.totalAmount,
            isSettled: false,
          )
          .toMap(),
    );
  }

  /// Updates fields on an existing debt document.
  Future<void> updateDebt(
    String uid,
    String debtId,
    Map<String, dynamic> data,
  ) async {
    await _debts(uid).doc(debtId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Permanently deletes a debt and all of its payments.
  Future<void> deleteDebt(String uid, String debtId) async {
    final batch = _firestore.batch();

    final paySnap = await _payments(uid, debtId).get();
    for (final doc in paySnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_debts(uid).doc(debtId));

    await batch.commit();
  }

  // ── Debt reads ─────────────────────────────────────────────────────────────

  /// Streams all debts sorted: unsettled by [dueDate] asc, settled last.
  Stream<List<DebtModel>> getDebts(String uid) {
    return _debts(uid).snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => DebtModel.fromMap(doc.data()))
          .toList()
        ..sort((a, b) {
          if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
          if (!a.isSettled) return a.dueDate.compareTo(b.dueDate);
          return a.title.compareTo(b.title);
        });
      return list;
    });
  }

  /// One-off read of a single debt document.
  Future<DebtModel?> getDebtById(String uid, String debtId) async {
    final doc = await _debts(uid).doc(debtId).get();
    if (!doc.exists || doc.data() == null) return null;
    return DebtModel.fromMap(doc.data()!);
  }

  /// Streams a single debt document in real time.
  /// Emits null when the debt is deleted — allows the detail screen to
  /// auto-navigate back to the debt list.
  Stream<DebtModel?> streamDebtById(String uid, String debtId) {
    return _debts(uid).doc(debtId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return DebtModel.fromMap(doc.data()!);
    });
  }

  // ── Payment CRUD ───────────────────────────────────────────────────────────

  /// Adds a payment and recalculates [remainingAmount] and [isSettled].
  Future<void> addPayment(
    String uid,
    String debtId,
    DebtPaymentModel payment,
  ) async {
    final docRef = _payments(uid, debtId).doc();
    await docRef.set(payment.copyWith(paymentId: docRef.id).toMap());
    await recalculateRemainingAmount(uid, debtId);
  }

  /// Streams payments for [debtId] sorted by date descending.
  Stream<List<DebtPaymentModel>> getPayments(String uid, String debtId) {
    return _payments(uid, debtId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => DebtPaymentModel.fromMap(doc.data()))
            .toList());
  }

  /// Deletes one payment and recalculates [remainingAmount] and [isSettled].
  Future<void> deletePayment(
    String uid,
    String debtId,
    String paymentId,
  ) async {
    await _payments(uid, debtId).doc(paymentId).delete();
    await recalculateRemainingAmount(uid, debtId);
  }

  // ── Recalculate ────────────────────────────────────────────────────────────

  /// Sums all payment amounts, then sets:
  ///   remainingAmount = max(0, totalAmount − totalPaid)
  ///   isSettled       = remainingAmount <= 0
  Future<void> recalculateRemainingAmount(
    String uid,
    String debtId,
  ) async {
    final paySnap = await _payments(uid, debtId).get();
    final totalPaid = paySnap.docs
        .map((doc) => (doc.data()['amount'] as num).toDouble())
        .fold<double>(0.0, (total, amount) => total + amount);

    final debtDoc = await _debts(uid).doc(debtId).get();
    if (!debtDoc.exists || debtDoc.data() == null) return;

    final totalAmount =
        (debtDoc.data()!['totalAmount'] as num).toDouble();

    // Clamp to 0 — remaining cannot go negative
    final newRemaining = (totalAmount - totalPaid) < 0
        ? 0.0
        : totalAmount - totalPaid;

    await _debts(uid).doc(debtId).update({
      'remainingAmount': newRemaining,
      'isSettled': newRemaining <= 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
