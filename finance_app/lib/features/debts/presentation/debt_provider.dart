import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/debt_service.dart';
import '../domain/debt_model.dart';
import '../domain/debt_payment_model.dart';

// ── Service provider ───────────────────────────────────────────────────────────

final debtServiceProvider = Provider<DebtService>((ref) {
  return DebtService(FirebaseFirestore.instance);
});

// ── Debt list provider ─────────────────────────────────────────────────────────

/// Streams all debts for the current user.
/// Unsettled debts (by due date) appear before settled debts.
final debtsProvider =
    StreamProvider.autoDispose<List<DebtModel>>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return const Stream.empty();
  return ref.watch(debtServiceProvider).getDebts(user.uid);
});

// ── Single debt stream ─────────────────────────────────────────────────────────

/// Streams a single debt in real time.
/// Emits null when the debt is deleted — the detail screen uses this to
/// auto-navigate back to the debt list.
final debtByIdProvider = StreamProvider.autoDispose
    .family<DebtModel?, String>((ref, debtId) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return const Stream.empty();
  return ref.watch(debtServiceProvider).streamDebtById(user.uid, debtId);
});

// ── Payments stream ────────────────────────────────────────────────────────────

/// Streams payments for [debtId], sorted by date descending.
final paymentsProvider = StreamProvider.autoDispose
    .family<List<DebtPaymentModel>, String>((ref, debtId) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return const Stream.empty();
  return ref.watch(debtServiceProvider).getPayments(user.uid, debtId);
});
