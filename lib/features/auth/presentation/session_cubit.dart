import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_exception.dart';
import '../../profile/domain/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

enum SessionStatus {
  /// Waiting for Firebase to report the auth state.
  unknown,

  /// Nobody is signed in: onboarding intro and the Google button.
  signedOut,

  /// Signed in; loading `users/{uid}`.
  loadingProfile,

  /// Signed in but no profile yet: username, interests and age steps.
  needsOnboarding,

  /// Signed in with a complete profile: the app.
  ready,

  /// Profile couldn't be loaded (e.g. offline). Retryable.
  failure,
}

class SessionState extends Equatable {
  const SessionState({
    this.status = SessionStatus.unknown,
    this.user,
    this.profile,
    this.errorMessage,
  });

  final SessionStatus status;
  final AppUser? user;
  final UserProfile? profile;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, user, profile, errorMessage];
}

/// App-wide session: Firebase auth state + the Firestore profile.
///
/// Drives the root gate: intro, Google sign in, onboarding, home.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit({
    required AuthRepository auth,
    required ProfileRepository profiles,
  }) : _auth = auth,
       _profiles = profiles,
       super(const SessionState()) {
    _sub = _auth.authStateChanges().listen(
      _onUser,
      onError: (Object _) => emit(const SessionState(status: SessionStatus.signedOut)),
    );
  }

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  late final StreamSubscription<AppUser?> _sub;
  int _generation = 0;

  Future<void> _onUser(AppUser? user) async {
    final generation = ++_generation;
    if (user == null) {
      emit(const SessionState(status: SessionStatus.signedOut));
      return;
    }
    emit(SessionState(status: SessionStatus.loadingProfile, user: user));
    try {
      final profile = await _profiles.fetchProfile();
      if (isClosed || generation != _generation) return;
      emit(
        SessionState(
          status: profile == null
              ? SessionStatus.needsOnboarding
              : SessionStatus.ready,
          user: user,
          profile: profile,
        ),
      );
    } catch (e) {
      if (isClosed || generation != _generation) return;
      emit(
        SessionState(
          status: SessionStatus.failure,
          user: user,
          errorMessage: asAppException(e).message,
        ),
      );
    }
  }

  /// Retry loading the profile after a failure.
  Future<void> retry() => _onUser(state.user ?? _auth.currentUser);

  /// Called by onboarding once the profile has been saved.
  void onboardingCompleted(UserProfile profile) {
    _generation++;
    emit(
      SessionState(
        status: SessionStatus.ready,
        user: state.user,
        profile: profile,
      ),
    );
  }

  /// Keeps the cached profile in sync after edits (e.g. preferences).
  void profileUpdated(UserProfile profile) {
    if (state.status != SessionStatus.ready) return;
    emit(
      SessionState(
        status: SessionStatus.ready,
        user: state.user,
        profile: profile,
      ),
    );
  }

  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
