import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/ui_notice.dart';
import '../../../auth/domain/auth_repository.dart';
import '../../../confessions/domain/confession_repository.dart';
import '../../../profile/domain/profile_repository.dart';

class AccountDeletionState extends Equatable {
  const AccountDeletionState({
    this.confirmed = false,
    this.status = SubmitStatus.idle,
    this.errorMessage,
  });

  final bool confirmed;
  final SubmitStatus status;
  final String? errorMessage;

  AccountDeletionState copyWith({
    bool? confirmed,
    SubmitStatus? status,
    String? Function()? errorMessage,
  }) {
    return AccountDeletionState(
      confirmed: confirmed ?? this.confirmed,
      status: status ?? this.status,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [confirmed, status, errorMessage];
}

/// Deletes, in order: confirm with Google → Firestore profile + username
/// claim → on-device activity and own posts → the Firebase Auth account.
class AccountDeletionCubit extends Cubit<AccountDeletionState> {
  AccountDeletionCubit({
    required AuthRepository auth,
    required ProfileRepository profiles,
    required ConfessionRepository confessions,
  }) : _auth = auth,
       _profiles = profiles,
       _confessions = confessions,
       super(const AccountDeletionState());

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  final ConfessionRepository _confessions;

  void setConfirmed(bool value) =>
      emit(state.copyWith(confirmed: value, errorMessage: () => null));

  Future<void> deleteAccount() async {
    if (!state.confirmed || state.status == SubmitStatus.submitting) return;
    emit(
      state.copyWith(status: SubmitStatus.submitting, errorMessage: () => null),
    );
    try {
      await _auth.reauthenticate();
      await _profiles.deleteProfile();
      await _confessions.clearUserData();
      await _auth.deleteAccount();
      if (!isClosed) emit(state.copyWith(status: SubmitStatus.success));
    } on SignInCancelledException {
      if (!isClosed) emit(state.copyWith(status: SubmitStatus.idle));
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: SubmitStatus.failure,
            errorMessage: () => asAppException(e).message,
          ),
        );
      }
    }
  }
}
