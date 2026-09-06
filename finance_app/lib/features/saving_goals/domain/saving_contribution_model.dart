import 'package:cloud_firestore/cloud_firestore.dart';

/// A single saving contribution for one goal.
///
/// Stored at: users/{uid}/savingGoals/{goalId}/contributions/{contributionId}
///
/// Each time a contribution is added or deleted, the parent goal's
/// [savedAmount] is recalculated by summing all contribution amounts.
class SavingContributionModel {
  const SavingContributionModel({
    required this.contributionId,
    required this.amount,
    required this.date,
    required this.note,
    required this.createdAt,
  });

  final String contributionId;
  final double amount;
  final DateTime date;

  /// Optional note. Max 200 characters.
  final String note;

  final DateTime createdAt;

  // ── Firestore serialization ────────────────────────────────────────────────

  factory SavingContributionModel.fromMap(Map<String, dynamic> map) {
    return SavingContributionModel(
      contributionId: map['contributionId'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contributionId': contributionId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
