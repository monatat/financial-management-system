import 'package:cloud_firestore/cloud_firestore.dart';

/// A single repayment made toward one debt.
///
/// Stored at: users/{uid}/debts/{debtId}/payments/{paymentId}
///
/// Each time a payment is added or deleted, the parent debt's
/// [remainingAmount] and [isSettled] are recalculated.
class DebtPaymentModel {
  const DebtPaymentModel({
    required this.paymentId,
    required this.amount,
    required this.date,
    required this.note,
    required this.createdAt,
  });

  final String paymentId;
  final double amount;
  final DateTime date;

  /// Optional note. Max 200 characters.
  final String note;

  final DateTime createdAt;

  // ── Firestore serialization ────────────────────────────────────────────────

  factory DebtPaymentModel.fromMap(Map<String, dynamic> map) {
    return DebtPaymentModel(
      paymentId: map['paymentId'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// ── copyWith extension ────────────────────────────────────────────────────────

extension DebtPaymentModelCopyWith on DebtPaymentModel {
  DebtPaymentModel copyWith({
    String? paymentId,
    double? amount,
    DateTime? date,
    String? note,
    DateTime? createdAt,
  }) {
    return DebtPaymentModel(
      paymentId: paymentId ?? this.paymentId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
