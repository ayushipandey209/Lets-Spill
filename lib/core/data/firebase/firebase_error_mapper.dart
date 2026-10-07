import 'package:firebase_auth/firebase_auth.dart';

import '../../errors/app_exception.dart';

/// Translates Firebase SDK errors into presentation-safe [AppException]s.
abstract final class FirebaseErrorMapper {
  static AppException map(Object error) {
    if (error is AppException) return error;
    if (error is FirebaseAuthException) return _auth(error);
    if (error is FirebaseException) return _firestore(error);
    return UnknownException('Something went wrong. Please try again.', error);
  }

  static AppException _auth(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return AuthException('That email address looks invalid.', code: e.code);
      case 'user-disabled':
        return AuthException('This account has been disabled.', code: e.code);
      case 'user-mismatch':
        return AuthException(
          'Please choose the same Google account you signed in with.',
          code: e.code,
        );
      case 'invalid-credential':
        return AuthException('Google sign-in failed. Please try again.', code: e.code);
      case 'too-many-requests':
        return AuthException(
          'Too many attempts. Wait a moment and try again.',
          code: e.code,
        );
      case 'requires-recent-login':
        return AuthException(
          'For your security, please sign in again and retry.',
          code: e.code,
        );
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'web-context-canceled':
        return const SignInCancelledException();
      case 'account-exists-with-different-credential':
        return AuthException(
          'This email is already linked to another sign-in method.',
          code: e.code,
        );
      case 'operation-not-allowed':
        return AuthException(
          'Google sign-in is not enabled for this Firebase project. '
          'Enable it in the Firebase Console under Authentication, Sign-in method.',
          code: e.code,
        );
      case 'network-request-failed':
        return const NetworkException();
      default:
        return AuthException(
          e.message ?? 'Authentication failed. Please try again.',
          code: e.code,
        );
    }
  }

  static AppException _firestore(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
      case 'unauthenticated':
        return const PermissionException();
      case 'not-found':
        return const NotFoundException();
      case 'unavailable':
      case 'deadline-exceeded':
        return const NetworkException();
      case 'resource-exhausted':
        return const UnknownException(
          'The service is busy right now. Please try again shortly.',
        );
      case 'failed-precondition':
        return UnknownException(
          'The database needs an index or setup step. See docs/FIREBASE_SETUP.md.',
          e,
        );
      default:
        return UnknownException('Something went wrong. Please try again.', e);
    }
  }
}

/// Wraps an async Firebase call and rethrows mapped errors.
Future<T> guardFirebase<T>(Future<T> Function() body) async {
  try {
    return await body();
  } catch (e) {
    throw FirebaseErrorMapper.map(e);
  }
}
