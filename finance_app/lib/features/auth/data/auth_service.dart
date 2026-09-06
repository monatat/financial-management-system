import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  // Tracks whether GoogleSignIn.instance.initialize() has been called.
  // initialize() must be called exactly once before authenticate() on mobile.
  Future<void>? _googleInitFuture;

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Stream that emits a [User] when logged in, null when logged out.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Returns the currently signed-in user, or null if none.
  User? getCurrentUser() => _auth.currentUser;

  // ── Email / Password ──────────────────────────────────────────────────────

  /// Creates a new Firebase Auth account.
  /// Email is normalised to lowercase before the request.
  Future<UserCredential> registerWithEmail(
    String email,
    String password,
  ) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  /// Signs in an existing email/password account.
  /// Email is normalised to lowercase before the request.
  Future<UserCredential> loginWithEmail(
    String email,
    String password,
  ) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────

  /// Signs in (or creates an account) using Google OAuth.
  ///
  /// On Web   → uses Firebase's built-in popup (GoogleAuthProvider).
  /// On Mobile → uses google_sign_in 7.x singleton:
  ///               1. initialize() once
  ///               2. authenticate() → GoogleSignInAccount
  ///               3. Exchange idToken for Firebase credential
  ///
  /// Throws [FirebaseAuthException] with code 'sign-in-cancelled' when the
  /// user dismisses the Google dialog without completing sign-in.
  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      // Web: Firebase handles the Google OAuth popup directly.
      return await _auth.signInWithPopup(GoogleAuthProvider());
    }

    // Mobile: google_sign_in 7.x uses a singleton that must be
    // initialized exactly once before authenticate() is called.
    _googleInitFuture ??= GoogleSignIn.instance.initialize();
    await _googleInitFuture;

    try {
      final account = await GoogleSignIn.instance.authenticate();

      // In google_sign_in 7.x only idToken is available from authentication.
      final credential = GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw FirebaseAuthException(
          code: 'sign-in-cancelled',
          message: 'Google sign-in was cancelled.',
        );
      }
      // Re-throw unexpected Google Sign-In errors so callers can handle them.
      rethrow;
    }
  }

  // ── Password Reset ────────────────────────────────────────────────────────

  /// Sends a Firebase password reset email to [email].
  /// Email is trimmed and lowercased before the request.
  /// Throws [FirebaseAuthException] on failure.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim().toLowerCase(),
    );
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  /// Signs the current user out of Firebase and (on mobile) out of Google,
  /// so the account picker appears again on the next sign-in attempt.
  Future<void> logout() async {
    if (!kIsWeb && _googleInitFuture != null) {
      await _googleInitFuture; // ensure initialization completed
      await GoogleSignIn.instance.signOut();
    }
    await _auth.signOut();
  }

  // ── Error messages ────────────────────────────────────────────────────────

  /// Converts a Firebase Auth error code into a human-readable message.
  static String errorMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 8 characters.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'sign-in-cancelled':
        return 'Sign-in was cancelled.';
      case 'account-exists-with-different-credential':
        return 'An account with this email already exists using a different sign-in method.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  /// Error messages specifically for the forgot password flow.
  static String resetPasswordErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      default:
        return 'Unable to send password reset email. Please try again.';
    }
  }
}
