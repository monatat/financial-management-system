import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/saving_goal_service.dart';
import '../domain/saving_contribution_model.dart';
import '../domain/saving_goal_model.dart';

// ── Service provider ───────────────────────────────────────────────────────────

final savingGoalServiceProvider = Provider<SavingGoalService>((ref) {
  return SavingGoalService(FirebaseFirestore.instance);
});

// ── Goals list ─────────────────────────────────────────────────────────────────

/// Streams all saving goals for the current user.
/// Active goals (soonest deadline) appear before completed goals.
final goalsProvider =
    StreamProvider.autoDispose<List<SavingGoalModel>>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return const Stream.empty();
  return ref.watch(savingGoalServiceProvider).getGoals(user.uid);
});

// ── Single goal stream ─────────────────────────────────────────────────────────

/// Streams a single goal in real time.
/// Emits null when the goal is deleted — the detail screen uses this to
/// auto-navigate back to the goals list.
final goalByIdProvider = StreamProvider.autoDispose
    .family<SavingGoalModel?, String>((ref, goalId) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return const Stream.empty();
  return ref
      .watch(savingGoalServiceProvider)
      .streamGoalById(user.uid, goalId);
});

// ── Contributions stream ───────────────────────────────────────────────────────

/// Streams contributions for [goalId], sorted by date descending.
final contributionsProvider = StreamProvider.autoDispose
    .family<List<SavingContributionModel>, String>((ref, goalId) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return const Stream.empty();
  return ref
      .watch(savingGoalServiceProvider)
      .getContributions(user.uid, goalId);
});
