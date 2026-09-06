import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/saving_contribution_model.dart';
import '../domain/saving_goal_model.dart';

/// Manages saving goals and their contribution subcollections.
///
/// Goals path:          users/{uid}/savingGoals/{goalId}
/// Contributions path:  users/{uid}/savingGoals/{goalId}/contributions/{id}
class SavingGoalService {
  SavingGoalService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _goals(String uid) =>
      _firestore.collection('users').doc(uid).collection('savingGoals');

  CollectionReference<Map<String, dynamic>> _contributions(
    String uid,
    String goalId,
  ) =>
      _goals(uid).doc(goalId).collection('contributions');

  // ── Goal CRUD ──────────────────────────────────────────────────────────────

  /// Creates a new saving goal with savedAmount = 0 and isCompleted = false.
  Future<void> createGoal(String uid, SavingGoalModel goal) async {
    final docRef = _goals(uid).doc();
    await docRef.set(goal.copyWith(goalId: docRef.id).toMap());
  }

  /// Updates fields on an existing goal document.
  Future<void> updateGoal(
    String uid,
    String goalId,
    Map<String, dynamic> data,
  ) async {
    await _goals(uid).doc(goalId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Permanently deletes a goal and all of its contributions.
  ///
  /// Firestore does not cascade-delete subcollections, so contributions
  /// are deleted explicitly in a batch before the goal document is removed.
  Future<void> deleteGoal(String uid, String goalId) async {
    final batch = _firestore.batch();

    // Delete all contributions first
    final contribSnap = await _contributions(uid, goalId).get();
    for (final doc in contribSnap.docs) {
      batch.delete(doc.reference);
    }

    // Delete the goal document
    batch.delete(_goals(uid).doc(goalId));

    await batch.commit();
  }

  // ── Goal reads ─────────────────────────────────────────────────────────────

  /// Streams all goals for [uid], sorted: active goals (soonest deadline
  /// first) then completed goals (alphabetically).
  Stream<List<SavingGoalModel>> getGoals(String uid) {
    return _goals(uid).snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => SavingGoalModel.fromMap(doc.data()))
          .toList()
        ..sort((a, b) {
          if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
          if (!a.isCompleted) return a.targetDate.compareTo(b.targetDate);
          return a.title.compareTo(b.title);
        });
      return list;
    });
  }

  /// Returns a snapshot of one goal, or null if it does not exist.
  Future<SavingGoalModel?> getGoalById(String uid, String goalId) async {
    final doc = await _goals(uid).doc(goalId).get();
    if (!doc.exists || doc.data() == null) return null;
    return SavingGoalModel.fromMap(doc.data()!);
  }

  /// Streams a single goal document in real time.
  /// Emits null when the goal is deleted — used by the detail screen to
  /// auto-navigate back when the goal no longer exists.
  Stream<SavingGoalModel?> streamGoalById(String uid, String goalId) {
    return _goals(uid).doc(goalId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return SavingGoalModel.fromMap(doc.data()!);
    });
  }

  // ── Contribution CRUD ──────────────────────────────────────────────────────

  /// Adds a contribution and then recalculates the goal's [savedAmount]
  /// and [isCompleted] fields.
  Future<void> addContribution(
    String uid,
    String goalId,
    SavingContributionModel contribution,
  ) async {
    final docRef = _contributions(uid, goalId).doc();
    await docRef.set(
      contribution.copyWith(contributionId: docRef.id).toMap(),
    );
    await recalculateSavedAmount(uid, goalId);
  }

  /// Streams contributions for [goalId] sorted by date descending.
  Stream<List<SavingContributionModel>> getContributions(
    String uid,
    String goalId,
  ) {
    return _contributions(uid, goalId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SavingContributionModel.fromMap(doc.data()))
            .toList());
  }

  /// Deletes one contribution and then recalculates [savedAmount].
  Future<void> deleteContribution(
    String uid,
    String goalId,
    String contributionId,
  ) async {
    await _contributions(uid, goalId).doc(contributionId).delete();
    await recalculateSavedAmount(uid, goalId);
  }

  // ── Recalculate saved amount ───────────────────────────────────────────────

  /// Sums all contribution amounts for [goalId] and updates the goal's
  /// [savedAmount] and [isCompleted] in a single Firestore write.
  ///
  /// Called automatically by [addContribution] and [deleteContribution].
  Future<void> recalculateSavedAmount(String uid, String goalId) async {
    // Step 1: Sum all contributions
    final contribSnap = await _contributions(uid, goalId).get();
    final totalSaved = contribSnap.docs
        .map((doc) => (doc.data()['amount'] as num).toDouble())
        .fold<double>(0.0, (total, amount) => total + amount);

    // Step 2: Read the goal's targetAmount to determine isCompleted
    final goalDoc = await _goals(uid).doc(goalId).get();
    if (!goalDoc.exists || goalDoc.data() == null) return;

    final targetAmount =
        (goalDoc.data()!['targetAmount'] as num).toDouble();

    // Step 3: Update savedAmount and isCompleted atomically
    await _goals(uid).doc(goalId).update({
      'savedAmount': totalSaved,
      'isCompleted': totalSaved >= targetAmount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

// ── SavingContributionModel copyWith extension ────────────────────────────────
// Placed here so the model itself stays free of unnecessary methods,
// keeping the domain model focused on data only.

extension SavingContributionModelCopyWith on SavingContributionModel {
  SavingContributionModel copyWith({
    String? contributionId,
    double? amount,
    DateTime? date,
    String? note,
    DateTime? createdAt,
  }) {
    return SavingContributionModel(
      contributionId: contributionId ?? this.contributionId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
