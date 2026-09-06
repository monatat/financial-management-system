import 'package:cloud_firestore/cloud_firestore.dart';

/// A monthly spending limit for one expense category.
///
/// Stored at: users/{uid}/budgets/{budgetId}
///
/// IMPORTANT: [spentAmount] is intentionally NOT stored here.
/// Spending is calculated at query time by summing expense transactions
/// where transaction.categoryId == this.categoryId and
/// transaction.month == this.month.
/// This keeps the data consistent without requiring updates on every
/// transaction add/edit/delete.
///
/// Budget categories come from expense categories only.
/// Never create a budget for an income category.
class BudgetModel {
  const BudgetModel({
    required this.budgetId,
    required this.month,
    required this.categoryId,
    required this.categoryName,
    required this.allocatedAmount,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
  });

  final String budgetId;

  /// "YYYY-MM" — the month this budget covers.
  final String month;

  /// FK → users/{uid}/categories/{categoryId} (expense type only).
  final String categoryId;

  /// Denormalized category name for fast display.
  /// TODO Phase 6: If a category is renamed, update this field via batch write.
  final String categoryName;

  /// The spending limit for this category in this month.
  final double allocatedAmount;

  /// ISO 4217 currency code (e.g. "MYR").
  final String currency;

  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Firestore serialization ────────────────────────────────────────────────

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      budgetId: map['budgetId'] as String,
      month: map['month'] as String,
      categoryId: map['categoryId'] as String,
      categoryName: map['categoryName'] as String,
      allocatedAmount: (map['allocatedAmount'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'MYR',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'budgetId': budgetId,
      'month': month,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'allocatedAmount': allocatedAmount,
      'currency': currency,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // ── Immutable update ───────────────────────────────────────────────────────

  BudgetModel copyWith({
    String? budgetId,
    String? month,
    String? categoryId,
    String? categoryName,
    double? allocatedAmount,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetModel(
      budgetId: budgetId ?? this.budgetId,
      month: month ?? this.month,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
