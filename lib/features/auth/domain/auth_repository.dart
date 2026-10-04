import 'app_user.dart';

/// Real authentication (Google via Firebase Authentication).
///
/// No passwords exist anywhere in the app: Google handles credentials, and
/// Firebase issues the session.
abstract interface class AuthRepository {
  /// Emits the current user (or `null`) immediately and on every change.
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  /// Opens Google sign-in. Throws `SignInCancelledException` if the user
  /// closes the picker.
  Future<AppUser> signInWithGoogle();

  /// Asks Google to confirm the account again. Firebase requires a recent
  /// sign-in before an account can be deleted.
  Future<void> reauthenticate();

  Future<void> signOut();

  /// Deletes the Firebase Auth account. Call [reauthenticate] first and
  /// remove the user's data (profile, local content) before this.
  Future<void> deleteAccount();
}
