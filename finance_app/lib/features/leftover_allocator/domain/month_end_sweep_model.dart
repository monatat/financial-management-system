import 'package:cloud_firestore/cloud_firestore.dart';

// ── Allocation item ───────────────────────────────────────────────────────────

/// Records where a portion of the leftover was directed.
class AllocationItem {
  const AllocationItem({
    required this.label,
    required this.amount,
    required this.destinationType,
    required this.destinationId,
  });

  final String label;
  final double amount;

  /// "savingGoal" or "debt"
  final String destinationType;

  /// The Firestore document ID of the target goal or debt.
  final String destinationId;

  Map<String, dynamic> toMap() => {
        'label': label,
        'amount': amount,
        'destinationType': destinationType,
        'destinationId': destinationId,
      };

  factory AllocationItem.fromMap(Map<String, dynamic> map) => AllocationItem(
        label: map['label'] as String,
        amount: (map['amount'] as num).toDouble(),
        destinationType: map['destinationType'] as String,
        destinationId: map['destinationId'] as String,
      );
}

// ── Month-end sweep ───────────────────────────────────────────────────────────

/// Stored at: users/{uid}/monthEndSweeps/{month}
///
/// Document key = month ("YYYY-MM") so there is at most one sweep per month.
///
/// Lifecycle: pending → completed | skipped
///
/// [status] values:
///   "pending"   – created, waiting for user action
///   "completed" – user allocated the leftover
///   "skipped"   – user dismissed without allocating
class MonthEndSweepModel {
  const MonthEndSweepModel({
    required this.sweepId,
    required this.month,
    required this.totalIncome,
    required this.totalExpenses,
    required this.allocatedSavings,
    required this.allocatedDebt,
    required this.leftoverAmount,
    required this.allocations,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.remainingUnallocatedAmount = 0.0,
  });

  /// Same as [month]; used as the Firestore document ID.
  final String sweepId;

  /// "YYYY-MM" — the month whose leftover is being swept.
  final String month;

  final double totalIncome;
  final double totalExpenses;

  /// Sum of saving contributions made during [month].
  final double allocatedSavings;

  /// Sum of debt payments made during [month].
  final double allocatedDebt;

  /// totalIncome − totalExpenses − allocatedSavings − allocatedDebt.
  final double leftoverAmount;

  /// Populated on completion — empty list while pending.
  final List<AllocationItem> allocations;

  /// "pending" | "completed" | "skipped"
  final String status;

  final DateTime createdAt;
  final DateTime? completedAt;

  /// leftoverAmount minus the sum of all allocation amounts.
  /// May be > 0 when the user does a partial allocation (allowed by design).
  final double remainingUnallocatedAmount;

  // ── Computed ──────────────────────────────────────────────────────────────

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isSkipped => status == 'skipped';

  // ── Firestore ─────────────────────────────────────────────────────────────

  factory MonthEndSweepModel.fromMap(Map<String, dynamic> map) {
    return MonthEndSweepModel(
      sweepId: map['sweepId'] as String,
      month: map['month'] as String,
      totalIncome: (map['totalIncome'] as num).toDouble(),
      totalExpenses: (map['totalExpenses'] as num).toDouble(),
      allocatedSavings: (map['allocatedSavings'] as num?)?.toDouble() ?? 0.0,
      allocatedDebt: (map['allocatedDebt'] as num?)?.toDouble() ?? 0.0,
      leftoverAmount: (map['leftoverAmount'] as num).toDouble(),
      allocations: (map['allocations'] as List? ?? [])
          .map((e) => AllocationItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      status: map['status'] as String? ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      remainingUnallocatedAmount:
          (map['remainingUnallocatedAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
        'sweepId': sweepId,
        'month': month,
        'totalIncome': totalIncome,
        'totalExpenses': totalExpenses,
        'allocatedSavings': allocatedSavings,
        'allocatedDebt': allocatedDebt,
        'leftoverAmount': leftoverAmount,
        'allocations': allocations.map((a) => a.toMap()).toList(),
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        'completedAt':
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'remainingUnallocatedAmount': remainingUnallocatedAmount,
      };

  MonthEndSweepModel copyWith({
    List<AllocationItem>? allocations,
    String? status,
    DateTime? completedAt,
    double? remainingUnallocatedAmount,
  }) {
    return MonthEndSweepModel(
      sweepId: sweepId,
      month: month,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      allocatedSavings: allocatedSavings,
      allocatedDebt: allocatedDebt,
      leftoverAmount: leftoverAmount,
      allocations: allocations ?? this.allocations,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      remainingUnallocatedAmount:
          remainingUnallocatedAmount ?? this.remainingUnallocatedAmount,
    );
  }
}
