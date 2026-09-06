import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/audit_service.dart';
import '../domain/audit_decision_model.dart';
import '../domain/audit_result_model.dart';

// ── Service provider ───────────────────────────────────────────────────────────

final auditServiceProvider = Provider<AuditService>((ref) {
  return AuditService(FirebaseFirestore.instance);
});

// ── Existing audit result ──────────────────────────────────────────────────────

/// Loads a previously saved audit result for [month].
/// Returns null if no audit has been run for that month yet.
final auditResultProvider = FutureProvider.autoDispose
    .family<AuditResultModel?, String>((ref, month) async {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return null;
  return ref.read(auditServiceProvider).getAuditResult(user.uid, month);
});

// ── Audit decisions ────────────────────────────────────────────────────────────

/// Loads all user decisions for [month] keyed by normalised description.
///
/// Returns an empty map when the user is not signed in or has made no decisions
/// for that month yet.
final auditDecisionsProvider = FutureProvider.autoDispose
    .family<Map<String, AuditDecisionModel>, String>((ref, month) async {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return {};
  return ref.read(auditServiceProvider).getDecisions(user.uid, month);
});
