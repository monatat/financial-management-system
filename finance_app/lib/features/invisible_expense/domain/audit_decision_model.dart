import 'package:cloud_firestore/cloud_firestore.dart';

/// Stores a user's review decision for a detected subscription item.
///
/// Firestore path: users/{uid}/auditDecisions/{decisionId}
///
/// [decisionId] is derived from the normalized description so the same
/// subscription always maps to the same document regardless of which month
/// the audit ran.
///
/// Valid [status] values:
///   'keep'   — user confirms this recurring expense is expected
///   'review' — user wants to check it later
///   'ignore' — user does not want this item highlighted
class AuditDecisionModel {
  const AuditDecisionModel({
    required this.description,
    required this.status,
    required this.month,
    required this.updatedAt,
  });

  /// Display description as returned by the audit.
  final String description;

  /// 'keep' | 'review' | 'ignore'
  final String status;

  /// 'YYYY-MM' of the audit month when the decision was made.
  final String month;

  final DateTime updatedAt;

  // ── Firestore key ────────────────────────────────────────────────────────────

  /// Stable document ID: normalized description, safe for Firestore paths.
  static String decisionId(String description) => description
      .trim()
      .toLowerCase()
      .replaceAll('/', '_')
      .replaceAll('.', '_')
      .replaceAll('#', '_')
      .replaceAll('[', '_')
      .replaceAll(']', '_');

  // ── Serialisation ────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'description': description,
        'status': status,
        'month': month,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory AuditDecisionModel.fromMap(Map<String, dynamic> map) =>
      AuditDecisionModel(
        description: map['description'] as String,
        status: map['status'] as String,
        month: map['month'] as String,
        updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      );
}
