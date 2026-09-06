import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/user_model.dart';

class UserService {
  UserService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Creates a new user document at users/{uid}.
  /// Called once immediately after Firebase Auth registration succeeds.
  Future<void> createUserProfile(UserModel user) async {
    await _users.doc(user.uid).set(user.toMap());
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns the user profile, or null if the document does not exist.
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!);
  }

  // ── Update ────────────────────────────────────────────────────────────────

  /// Merges [data] into users/{uid} and stamps updatedAt.
  Future<void> updateUserProfile(
    String uid,
    Map<String, dynamic> data,
  ) async {
    final updates = Map<String, dynamic>.from(data)
      ..['updatedAt'] = Timestamp.now();
    await _users.doc(uid).update(updates);
  }

  /// Called once by [CurrencySetupScreen] when the user selects their base
  /// currency for the first time.
  ///
  /// Sets [currency] and flips [hasCompletedCurrencySetup] to true atomically.
  /// After this call the router allows access to all app routes.
  ///
  /// Existing transactions are NOT changed — each transaction stores its own
  /// currency field set at the time it was recorded.
  Future<void> completeCurrencySetup(String uid, String currency) async {
    await updateUserProfile(uid, {
      'currency': currency,
      'hasCompletedCurrencySetup': true,
    });
  }
}
