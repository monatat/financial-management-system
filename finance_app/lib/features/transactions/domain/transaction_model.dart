import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents one income or expense transaction.
///
/// Stored at: users/{uid}/transactions/{transactionId}
///
/// The [month] field (format "YYYY-MM") is denormalized from [date] so that
/// monthly queries can use a simple equality filter without a composite index.
///
/// [categoryName] is denormalized from the category document so list views
/// render without secondary lookups. If the category is later renamed,
/// Phase 4 notes this in the update path (see TransactionService.updateTransaction).
class TransactionModel {
  const TransactionModel({
    required this.transactionId,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.note,
    required this.date,
    required this.month,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
  });

  final String transactionId;

  /// "income" or "expense"
  final String type;

  /// Always positive. Direction is conveyed by [type].
  final double amount;

  /// FK → users/{uid}/categories/{categoryId}
  final String categoryId;

  /// Denormalized snapshot of the category name at the time of the transaction.
  /// TODO Phase 6: When a category is renamed, batch-update this field on all
  /// transactions referencing that categoryId.
  final String categoryName;

  /// Selected preset or free-typed description. Required.
  final String description;

  /// Optional user note. Max 200 characters.
  final String note;

  final DateTime date;

  /// "YYYY-MM" — computed from [date] for efficient monthly queries.
  final String month;

  /// ISO 4217 currency code, e.g. "MYR".
  final String currency;

  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Convenience ───────────────────────────────────────────────────────────

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';

  /// Returns the signed amount: negative for expenses, positive for income.
  double get signedAmount => isExpense ? -amount : amount;

  // ── Firestore serialization ────────────────────────────────────────────────

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      transactionId: map['transactionId'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'] as String,
      categoryName: map['categoryName'] as String,
      description: map['description'] as String,
      note: map['note'] as String? ?? '',
      date: (map['date'] as Timestamp).toDate(),
      month: map['month'] as String,
      currency: map['currency'] as String? ?? 'MYR',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'type': type,
      'amount': amount,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'description': description,
      'note': note,
      'date': Timestamp.fromDate(date),
      'month': month,
      'currency': currency,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // ── Immutable update ───────────────────────────────────────────────────────

  TransactionModel copyWith({
    String? transactionId,
    String? type,
    double? amount,
    String? categoryId,
    String? categoryName,
    String? description,
    String? note,
    DateTime? date,
    String? month,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      transactionId: transactionId ?? this.transactionId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      description: description ?? this.description,
      note: note ?? this.note,
      date: date ?? this.date,
      month: month ?? this.month,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
