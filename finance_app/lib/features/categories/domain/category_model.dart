import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show Color;

/// Represents one category (expense or income).
///
/// IMPORTANT — Budget relationship:
/// Expense categories are the single source of truth for budget categories.
/// There is NO separate budget-category collection. When the Budget module
/// needs a list of budget categories it must call
/// CategoryService.getExpenseCategories(uid).
class CategoryModel {
  const CategoryModel({
    required this.categoryId,
    required this.name,
    required this.type,
    required this.isDefault,
    required this.isDeleted,
    required this.iconCode,
    required this.colorHex,
    required this.createdAt,
    required this.updatedAt,
  });

  final String categoryId;
  final String name;

  /// "expense" or "income"
  final String type;

  /// True for the 17 seeded defaults. Default categories cannot be hard-deleted.
  final bool isDefault;

  /// Soft-delete flag. Always filter isDeleted == false when querying.
  final bool isDeleted;

  /// codePoint of a Material icon (e.g. Icons.restaurant_rounded.codePoint).
  final int iconCode;

  /// Hex colour string in #RRGGBB format (e.g. '#8B5CF6').
  final String colorHex;

  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Convenience getters ────────────────────────────────────────────────────

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';

  /// Reconstructs the [Color] from [colorHex].
  Color get color {
    final hex = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  // Note: IconData is intentionally not provided here to avoid lint warnings
  // from non-const codePoint usage. Widgets should create it directly:
  //   IconData(category.iconCode, fontFamily: 'MaterialIcons')

  // ── Firestore serialization ────────────────────────────────────────────────

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      categoryId: map['categoryId'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      isDefault: map['isDefault'] as bool? ?? false,
      isDeleted: map['isDeleted'] as bool? ?? false,
      iconCode: map['iconCode'] as int,
      colorHex: map['colorHex'] as String,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'name': name,
      'type': type,
      'isDefault': isDefault,
      'isDeleted': isDeleted,
      'iconCode': iconCode,
      'colorHex': colorHex,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // ── Immutable update ───────────────────────────────────────────────────────

  CategoryModel copyWith({
    String? categoryId,
    String? name,
    String? type,
    bool? isDefault,
    bool? isDeleted,
    int? iconCode,
    String? colorHex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      isDeleted: isDeleted ?? this.isDeleted,
      iconCode: iconCode ?? this.iconCode,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
