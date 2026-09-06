import 'package:cloud_firestore/cloud_firestore.dart';

// ── Nested item models ────────────────────────────────────────────────────────

/// A recurring subscription detected across multiple months.
class SubscriptionItem {
  const SubscriptionItem({
    required this.description,
    required this.amount,
    required this.occurrences,
    required this.projectedAnnual,
    required this.transactionIds,
  });

  /// The transaction description used as the matching key.
  final String description;

  /// Average amount charged per occurrence.
  final double amount;

  /// How many times it appeared in the detection window (last 3 months).
  final int occurrences;

  /// Estimated annual cost: amount × 12.
  final double projectedAnnual;

  /// IDs of the transactions that triggered this detection (for reference).
  final List<String> transactionIds;

  Map<String, dynamic> toMap() => {
        'description': description,
        'amount': amount,
        'occurrences': occurrences,
        'projectedAnnual': projectedAnnual,
        'transactionIds': transactionIds,
      };

  factory SubscriptionItem.fromMap(Map<String, dynamic> map) =>
      SubscriptionItem(
        description: map['description'] as String,
        amount: (map['amount'] as num).toDouble(),
        occurrences: map['occurrences'] as int,
        projectedAnnual: (map['projectedAnnual'] as num).toDouble(),
        transactionIds:
            List<String>.from(map['transactionIds'] as List? ?? []),
      );
}

/// A small habitual expense detected by high frequency in the month.
class MicroHabitItem {
  const MicroHabitItem({
    required this.description,
    required this.count,
    required this.totalAmount,
    required this.projectedAnnual,
    required this.transactionIds,
  });

  final String description;

  /// Number of transactions detected.
  final int count;

  /// Sum of all detected transactions.
  final double totalAmount;

  /// Estimated annual cost: totalAmount × 12.
  final double projectedAnnual;

  final List<String> transactionIds;

  Map<String, dynamic> toMap() => {
        'description': description,
        'count': count,
        'totalAmount': totalAmount,
        'projectedAnnual': projectedAnnual,
        'transactionIds': transactionIds,
      };

  factory MicroHabitItem.fromMap(Map<String, dynamic> map) => MicroHabitItem(
        description: map['description'] as String,
        count: map['count'] as int,
        totalAmount: (map['totalAmount'] as num).toDouble(),
        projectedAnnual: (map['projectedAnnual'] as num).toDouble(),
        transactionIds:
            List<String>.from(map['transactionIds'] as List? ?? []),
      );
}

// ── Audit result ──────────────────────────────────────────────────────────────

/// Stored at: users/{uid}/invisibleExpenseAudits/{month}
///
/// Document key = month ("YYYY-MM") so there is always at most one audit
/// result per month per user. Re-running the audit overwrites the document.
///
/// This model only stores detection results — it NEVER modifies transactions.
class AuditResultModel {
  const AuditResultModel({
    required this.auditId,
    required this.month,
    required this.generatedAt,
    required this.subscriptions,
    required this.microHabits,
    required this.totalLeakage,
  });

  /// Same as [month] — used as the Firestore document ID.
  final String auditId;

  /// "YYYY-MM" format.
  final String month;

  final DateTime generatedAt;

  final List<SubscriptionItem> subscriptions;
  final List<MicroHabitItem> microHabits;

  /// subscriptionMonthlyTotal + microHabitMonthlyTotal for the audit month.
  final double totalLeakage;

  // ── Computed ──────────────────────────────────────────────────────────────

  double get subscriptionLeakage =>
      subscriptions.fold(0.0, (s, i) => s + i.amount);

  double get microHabitLeakage =>
      microHabits.fold(0.0, (s, i) => s + i.totalAmount);

  double get estimatedAnnualLeakage =>
      subscriptions.fold(0.0, (s, i) => s + i.projectedAnnual) +
      microHabits.fold(0.0, (s, i) => s + i.projectedAnnual);

  bool get hasFindings =>
      subscriptions.isNotEmpty || microHabits.isNotEmpty;

  // ── Firestore ─────────────────────────────────────────────────────────────

  factory AuditResultModel.fromMap(Map<String, dynamic> map) {
    return AuditResultModel(
      auditId: map['auditId'] as String,
      month: map['month'] as String,
      generatedAt: (map['generatedAt'] as Timestamp).toDate(),
      subscriptions: (map['subscriptions'] as List? ?? [])
          .map((e) => SubscriptionItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      microHabits: (map['microHabits'] as List? ?? [])
          .map((e) => MicroHabitItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      totalLeakage: (map['totalLeakage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
        'auditId': auditId,
        'month': month,
        'generatedAt': Timestamp.fromDate(generatedAt),
        'subscriptions': subscriptions.map((s) => s.toMap()).toList(),
        'microHabits': microHabits.map((m) => m.toMap()).toList(),
        'totalLeakage': totalLeakage,
      };
}
