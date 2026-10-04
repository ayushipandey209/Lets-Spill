import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/ui_notice.dart';
import '../../../../core/utils/validators.dart';
import '../../../confessions/domain/confession.dart';
import '../../../confessions/domain/confession_repository.dart';

class CreateConfessionState extends Equatable {
  const CreateConfessionState({
    this.text = '',
    this.categoryId,
    this.status = SubmitStatus.idle,
    this.textError,
    this.categoryError,
    this.errorMessage,
    this.created,
    this.showValidation = false,
    this.postAsHandle = false,
  });

  final String text;
  final String? categoryId;
  final SubmitStatus status;
  final String? textError;
  final String? categoryError;

  /// Submission failure from the data layer.
  final String? errorMessage;
  final Confession? created;

  /// Inline errors appear only after the first submit attempt.
  final bool showValidation;

  /// Show the author's anonymous handle instead of "Anonymous".
  final bool postAsHandle;

  /// Character count used for the counter and the length limit.
  int get length => text.trim().length;

  bool get isSubmitting => status == SubmitStatus.submitting;
  bool get hasDraft => text.trim().isNotEmpty;

  CreateConfessionState copyWith({
    String? text,
    String? categoryId,
    SubmitStatus? status,
    String? Function()? textError,
    String? Function()? categoryError,
    String? Function()? errorMessage,
    Confession? created,
    bool? showValidation,
    bool? postAsHandle,
  }) {
    return CreateConfessionState(
      text: text ?? this.text,
      categoryId: categoryId ?? this.categoryId,
      status: status ?? this.status,
      textError: textError != null ? textError() : this.textError,
      categoryError: categoryError != null
          ? categoryError()
          : this.categoryError,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      created: created ?? this.created,
      showValidation: showValidation ?? this.showValidation,
      postAsHandle: postAsHandle ?? this.postAsHandle,
    );
  }

  @override
  List<Object?> get props => [
    text,
    categoryId,
    status,
    textError,
    categoryError,
    errorMessage,
    created,
    showValidation,
    postAsHandle,
  ];
}

class CreateConfessionCubit extends Cubit<CreateConfessionState> {
  CreateConfessionCubit({
    required ConfessionRepository repository,
    required this.maxLength,
    required this.minLength,
    this.handle,
    String? initialCategoryId,
  }) : _repository = repository,
       super(CreateConfessionState(categoryId: initialCategoryId));

  final ConfessionRepository _repository;
  final int maxLength;
  final int minLength;

  /// The user's anonymous handle (e.g. "@QuietComet27"), if they have one.
  final String? handle;

  void setPostAsHandle(bool value) {
    if (handle == null) return;
    emit(state.copyWith(postAsHandle: value));
  }

  void textChanged(String value) {
    emit(
      state.copyWith(
        text: value,
        textError: () => state.showValidation ? _validateText(value) : null,
        errorMessage: () => null,
        status: state.status == SubmitStatus.failure
            ? SubmitStatus.idle
            : state.status,
      ),
    );
  }

  void categorySelected(String id) {
    emit(state.copyWith(categoryId: id, categoryError: () => null));
  }

  String? _validateText(String value) =>
      Validators.confession(value, min: minLength, max: maxLength);

  Future<void> submit() async {
    // Duplicate-submission guard: ignore taps while a post is in flight or
    // after it has already succeeded.
    if (state.isSubmitting || state.status == SubmitStatus.success) return;

    final textError = _validateText(state.text);
    final categoryError = state.categoryId == null
        ? 'Choose a category.'
        : null;
    if (textError != null || categoryError != null) {
      emit(
        state.copyWith(
          showValidation: true,
          textError: () => textError,
          categoryError: () => categoryError,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: SubmitStatus.submitting,
        showValidation: true,
        errorMessage: () => null,
      ),
    );
    try {
      final created = await _repository.create(
        text: state.text,
        categoryId: state.categoryId!,
        displayName: state.postAsHandle && handle != null
            ? handle!
            : Confession.anonymousName,
      );
      if (!isClosed) {
        emit(state.copyWith(status: SubmitStatus.success, created: created));
      }
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
