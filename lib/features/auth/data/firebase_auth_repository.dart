import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/data/firebase/firebase_error_mapper.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

/// Google sign-in through Firebase Authentication.
///
/// * Web uses Firebase's popup flow.
/// * Android/iOS use the `google_sign_in` package to get a Google ID token,
///   which is exchanged for a Firebase credential.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({required fb.FirebaseAuth auth, GoogleSignIn? google})
    : _auth = auth,
      _google = google ?? GoogleSignIn.instance;

  final fb.FirebaseAuth _auth;
  final GoogleSignIn _google;
  Future<void>? _googleInit;

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_map);

  @override
  Future<AppUser> signInWithGoogle() {
    return guardFirebase(() async {
      final fb.UserCredential result;
      if (kIsWeb) {
        result = await _auth.signInWithPopup(_provider());
      } else {
        result = await _auth.signInWithCredential(await _googleCredential());
      }
      final user = _map(result.user);
      if (user == null) throw const AuthException('Sign-in failed. Try again.');
      return user;
    });
  }

  @override
  Future<void> reauthenticate() {
    return guardFirebase(() async {
      final user = _auth.currentUser;
      if (user == null) throw const AuthException('Please sign in again.');
      if (kIsWeb) {
        await user.reauthenticateWithPopup(_provider());
      } else {
        await user.reauthenticateWithCredential(await _googleCredential());
      }
    });
  }

  @override
  Future<void> signOut() {
    return guardFirebase(() async {
      if (!kIsWeb) {
        try {
          await _ensureGoogleInitialized();
          await _google.signOut();
        } catch (_) {
          // Google session cleanup is best-effort; Firebase sign-out matters.
        }
      }
      await _auth.signOut();
    });
  }

  @override
  Future<void> deleteAccount() {
    return guardFirebase(() async {
      final user = _auth.currentUser;
      if (user == null) throw const AuthException('Please sign in again.');
      await user.delete();
      if (!kIsWeb) {
        try {
          await _google.disconnect();
        } catch (_) {}
      }
    });
  }

  fb.GoogleAuthProvider _provider() =>
      fb.GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});

  Future<void> _ensureGoogleInitialized() {
    return _googleInit ??= _google.initialize(
      // iOS needs the OAuth client id; it's in the generated Firebase options.
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? Firebase.app().options.iosClientId
          : null,
    );
  }

  Future<fb.OAuthCredential> _googleCredential() async {
    await _ensureGoogleInitialized();
    final GoogleSignInAccount account;
    try {
      account = await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw const SignInCancelledException();
      }
      throw AuthException(
        e.code == GoogleSignInExceptionCode.clientConfigurationError ||
                e.code == GoogleSignInExceptionCode.providerConfigurationError
            ? 'Google sign-in is not configured for this build. '
                  'See docs/FIREBASE_SETUP.md (SHA fingerprints / iOS URL scheme).'
            : 'Google sign-in failed. Please try again.',
        code: e.code.name,
      );
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google did not return a sign-in token.');
    }
    return fb.GoogleAuthProvider.credential(idToken: idToken);
  }

  AppUser? _map(fb.User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      displayName: user.displayName ?? '',
      email: user.email ?? '',
    );
  }
}
