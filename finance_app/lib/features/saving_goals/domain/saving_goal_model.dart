import 'package:cloud_firestore/cloud_firestore.dart';

/// A financial goal the user is saving toward.
///
/// Stored at: users/{uid}/savingGoals/{goalId}
///
/// [savedAmount] is maintained by [SavingGoalService.recalculateSavedAmount],
/// which sums all contribution documents in the subcollection whenever a
/// contribution is added or deleted. It is NOT updated by transactions.
class SavingGoalModel {
  const SavingGoalModel({
    required this.goalId,
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
    required this.targetDate,
    required this.note,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  final String goalId;
  final String title;
  final double targetAmount;

  /// Maintained by [SavingGoalService.recalculateSavedAmount].
  /// Set to sum of all contributions. Never write to this field manually.
  final double savedAmount;

  final DateTime targetDate;

  /// Optional note. Max 200 characters.
  final String note;

  /// Set to true when savedAmount >= targetAmount by recalculateSavedAmount.
  final bool isCompleted;

  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Computed ──────────────────────────────────────────────────────────────

  double get remainingAmount => targetAmount - savedAmount;
  bool get isOverSaved => savedAmount >= targetAmount;

  /// Raw ratio — may exceed 1.0 when over-saved.
  double get progressPercent =>
      targetAmount > 0 ? savedAmount / targetAmount : 0.0;

  /// Clamped to [0.0, 1.0] for progress bar display.
  double get clampedPercent => progressPercent.clamp(0.0, 1.0);

  /// Display string, e.g. "73%" or "100%".
  String get percentLabel =>
      '${(progressPercent * 100).clamp(0.0, 9999.0).toStringAsFixed(0)}%';

  // ── Firestore serialization ────────────────────────────────────────────────

  factory SavingGoalModel.fromMap(Map<String, dynamic> map) {
    return SavingGoalModel(
      goalId: map['goalId'] as String,
      title: map['title'] as String,
      targetAmount: (map['targetAmount'] as num).toDouble(),
      savedAmount: (map['savedAmount'] as num?)?.toDouble() ?? 0.0,
      targetDate: (map['targetDate'] as Timestamp).toDate(),
      note: map['note'] as String? ?? '',
      isCompleted: map['isCompleted'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'goalId': goalId,
      'title': title,
      'targetAmount': targetAmount,
      'savedAmount': savedAmount,
      'targetDate': Timestamp.fromDate(targetDate),
      'note': note,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SavingGoalModel copyWith({
    String? goalId,
    String? title,
    double? targetAmount,
    double? savedAmount,
    DateTime? targetDate,
    String? note,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavingGoalModel(
      goalId: goalId ?? this.goalId,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      targetDate: targetDate ?? this.targetDate,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
