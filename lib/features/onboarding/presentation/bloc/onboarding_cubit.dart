import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/ui_notice.dart';
import '../../../profile/domain/profile_repository.dart';
import '../../../profile/domain/user_profile.dart';
import '../../domain/username_generator.dart';

/// The three tap-only steps after Google sign-in.
enum OnboardingStep { username, interests, age }

class OnboardingState extends Equatable {
  const OnboardingState({
    this.step = OnboardingStep.username,
    this.usernameOptions = const [],
    this.username,
    this.categoryIds = const [],
    this.ageRange,
    this.status = SubmitStatus.idle,
    this.checkingUsername = false,
    this.errorMessage,
    this.profile,
  });

  final OnboardingStep step;
  final List<String> usernameOptions;
  final String? username;
  final List<String> categoryIds;
  final AgeRange? ageRange;
  final SubmitStatus status;
  final bool checkingUsername;
  final String? errorMessage;

  /// Set once the profile was saved.
  final UserProfile? profile;

  int get stepIndex => step.index;
  int get stepCount => OnboardingStep.values.length;

  bool get canContinue => switch (step) {
    OnboardingStep.username => username != null && !checkingUsername,
    OnboardingStep.interests => categoryIds.isNotEmpty,
    OnboardingStep.age => ageRange != null && status != SubmitStatus.submitting,
  };

  OnboardingState copyWith({
    OnboardingStep? step,
    List<String>? usernameOptions,
    String? Function()? username,
    List<String>? categoryIds,
    AgeRange? ageRange,
    SubmitStatus? status,
    bool? checkingUsername,
    String? Function()? errorMessage,
    UserProfile? profile,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      usernameOptions: usernameOptions ?? this.usernameOptions,
      username: username != null ? username() : this.username,
      categoryIds: categoryIds ?? this.categoryIds,
      ageRange: ageRange ?? this.ageRange,
      status: status ?? this.status,
      checkingUsername: checkingUsername ?? this.checkingUsername,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      profile: profile ?? this.profile,
    );
  }

  @override
  List<Object?> get props => [
    step,
    usernameOptions,
    username,
    categoryIds,
    ageRange,
    status,
    checkingUsername,
    errorMessage,
    profile,
  ];
}

/// Onboarding with no typing: every answer is a tap.
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({
    required ProfileRepository profiles,
    UsernameGenerator? generator,
    this.optionCount = 6,
  }) : _profiles = profiles,
       _generator = generator ?? UsernameGenerator(),
       super(const OnboardingState()) {
    emit(state.copyWith(usernameOptions: _generator.suggestions(optionCount)));
  }

  final ProfileRepository _profiles;
  final UsernameGenerator _generator;
  final int optionCount;

  /// Fresh batch of anonymous names.
  void shuffleUsernames() {
    emit(
      state.copyWith(
        usernameOptions: _generator.suggestions(
          optionCount,
          exclude: state.usernameOptions.toSet(),
        ),
        username: () => null,
        errorMessage: () => null,
      ),
    );
  }

  void selectUsername(String name) {
    if (!state.usernameOptions.contains(name)) return;
    emit(state.copyWith(username: () => name, errorMessage: () => null));
  }

  void toggleCategory(String id) {
    final next = List<String>.of(state.categoryIds);
    if (!next.remove(id)) next.add(id);
    emit(
      state.copyWith(
        categoryIds: List.unmodifiable(next),
        errorMessage: () => null,
      ),
    );
  }

  void selectAge(AgeRange range) =>
      emit(state.copyWith(ageRange: range, errorMessage: () => null));

  void back() {
    if (state.step == OnboardingStep.username) return;
    emit(
      state.copyWith(
        step: OnboardingStep.values[state.step.index - 1],
        errorMessage: () => null,
      ),
    );
  }

  /// Advances one step; on the last step saves everything.
  Future<void> next() async {
    if (!state.canContinue) return;
    switch (state.step) {
      case OnboardingStep.username:
        await _confirmUsername();
      case OnboardingStep.interests:
        emit(state.copyWith(step: OnboardingStep.age));
      case OnboardingStep.age:
        await _submit();
    }
  }

  Future<void> _confirmUsername() async {
    final name = state.username;
    if (name == null) return;
    emit(state.copyWith(checkingUsername: true, errorMessage: () => null));
    try {
      final free = await _profiles.isUsernameAvailable(name);
      if (isClosed) return;
      if (!free) {
        emit(
          state.copyWith(
            checkingUsername: false,
            usernameOptions: _generator.suggestions(
              optionCount,
              exclude: {...state.usernameOptions},
            ),
            username: () => null,
            errorMessage: () => '$name is taken. Here are some fresh ones.',
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          checkingUsername: false,
          step: OnboardingStep.interests,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          checkingUsername: false,
          errorMessage: () => asAppException(e).message,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (state.status == SubmitStatus.submitting) return;
    final username = state.username;
    final age = state.ageRange;
    if (username == null || age == null || state.categoryIds.isEmpty) return;
    emit(state.copyWith(status: SubmitStatus.submitting, errorMessage: () => null));
    try {
      final profile = await _profiles.completeOnboarding(
        OnboardingChoices(
          username: username,
          ageRange: age,
          preferredCategoryIds: state.categoryIds,
        ),
      );
      if (isClosed) return;
      emit(state.copyWith(status: SubmitStatus.success, profile: profile));
    } on UsernameTakenException catch (e) {
      if (isClosed) return;
      // Someone grabbed it in the meantime: go back and pick again.
      emit(
        state.copyWith(
          status: SubmitStatus.idle,
          step: OnboardingStep.username,
          usernameOptions: _generator.suggestions(optionCount),
          username: () => null,
          errorMessage: () => e.message,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: SubmitStatus.failure,
          errorMessage: () => asAppException(e).message,
        ),
      );
    }
  }
}
