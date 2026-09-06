import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_service.dart';
import '../data/user_service.dart';
import '../domain/user_model.dart';

// ── Service providers ─────────────────────────────────────────────────────────

/// Provides the [AuthService] backed by [FirebaseAuth].
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(FirebaseAuth.instance);
});

/// Provides the [UserService] backed by [FirebaseFirestore].
final userServiceProvider = Provider<UserService>((ref) {
  return UserService(FirebaseFirestore.instance);
});

// ── Auth state ────────────────────────────────────────────────────────────────

/// Streams the current Firebase [User].
///
/// - [AsyncLoading]  → Firebase is still checking the cached session.
/// - [AsyncData(User)] → Signed in.
/// - [AsyncData(null)] → Signed out.
///
/// The router listens to this stream to redirect between login and dashboard.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.read(authServiceProvider).authStateChanges();
});

// ── User profile ──────────────────────────────────────────────────────────────

/// Fetches the Firestore profile for the currently signed-in user (one-off).
///
/// Returns null when no user is signed in or the profile document is missing.
/// Used by transaction and other forms to read saved preferences (e.g. currency).
final currentUserProfileProvider =
    FutureProvider.autoDispose<UserModel?>((ref) async {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return null;
  return ref.read(userServiceProvider).getUserProfile(user.uid);
});

/// Streams the Firestore profile document for the current user in real time.
///
/// Used by the router to react immediately when:
///   - A new user completes the currency setup (currency field changes)
///   - The profile is first created after registration / Google Sign-In
///
/// Emits null when not signed in or the document does not yet exist.
final userProfileStreamProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!);
  });
});
