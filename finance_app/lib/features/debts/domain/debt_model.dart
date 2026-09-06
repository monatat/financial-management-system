import 'package:cloud_firestore/cloud_firestore.dart';

/// A debt the user is repaying (e.g. PTPTN, personal loan, credit card).
///
/// Stored at: users/{uid}/debts/{debtId}
///
/// [remainingAmount] is maintained by [DebtService.recalculateRemainingAmount],
/// which sets it to max(0, totalAmount − sum of all payments).
/// It is NOT updated by transactions — debt tracking is independent.
class DebtModel {
  const DebtModel({
    required this.debtId,
    required this.title,
    required this.totalAmount,
    required this.remainingAmount,
    required this.monthlyDue,
    required this.startDate,
    required this.dueDate,
    required this.note,
    required this.isSettled,
    required this.createdAt,
    required this.updatedAt,
  });

  final String debtId;
  final String title;

  /// The original loan/debt amount when the debt was created.
  final double totalAmount;

  /// Updated by [DebtService.recalculateRemainingAmount].
  /// Clamped to 0 — never negative.
  final double remainingAmount;

  /// Expected monthly repayment amount.
  final double monthlyDue;

  final DateTime startDate;

  /// Final repayment deadline.
  final DateTime dueDate;

  final String note;

  /// True when remainingAmount has reached 0.
  final bool isSettled;

  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Computed ──────────────────────────────────────────────────────────────

  /// How much has been paid: totalAmount − remainingAmount.
  double get paidAmount =>
      (totalAmount - remainingAmount).clamp(0.0, totalAmount);

  /// Repayment progress: paidAmount / totalAmount.
  double get progressPercent =>
      totalAmount > 0 ? paidAmount / totalAmount : 0.0;

  /// Clamped to [0.0, 1.0] for progress bar display.
  double get clampedPercent => progressPercent.clamp(0.0, 1.0);

  /// Display string, e.g. "73%".
  String get percentLabel =>
      '${(progressPercent * 100).clamp(0.0, 100.0).toStringAsFixed(0)}%';

  /// True when the debt is unpaid and the due date has passed.
  bool get isOverdue =>
      !isSettled && dueDate.isBefore(DateTime.now());

  // ── Firestore serialization ────────────────────────────────────────────────

  factory DebtModel.fromMap(Map<String, dynamic> map) {
    return DebtModel(
      debtId: map['debtId'] as String,
      title: map['title'] as String,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      remainingAmount: (map['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      monthlyDue: (map['monthlyDue'] as num).toDouble(),
      startDate: (map['startDate'] as Timestamp).toDate(),
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      note: map['note'] as String? ?? '',
      isSettled: map['isSettled'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'debtId': debtId,
      'title': title,
      'totalAmount': totalAmount,
      'remainingAmount': remainingAmount,
      'monthlyDue': monthlyDue,
      'startDate': Timestamp.fromDate(startDate),
      'dueDate': Timestamp.fromDate(dueDate),
      'note': note,
      'isSettled': isSettled,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  DebtModel copyWith({
    String? debtId,
    String? title,
    double? totalAmount,
    double? remainingAmount,
    double? monthlyDue,
    DateTime? startDate,
    DateTime? dueDate,
    String? note,
    bool? isSettled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DebtModel(
      debtId: debtId ?? this.debtId,
      title: title ?? this.title,
      totalAmount: totalAmount ?? this.totalAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      monthlyDue: monthlyDue ?? this.monthlyDue,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      note: note ?? this.note,
      isSettled: isSettled ?? this.isSettled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
