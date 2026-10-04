import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/ui_notice.dart';
import '../domain/report.dart';
import '../domain/report_repository.dart';

class ReportState extends Equatable {
  const ReportState({
    this.reason,
    this.details = '',
    this.status = SubmitStatus.idle,
    this.errorMessage,
  });

  final ReportReason? reason;
  final String details;
  final SubmitStatus status;
  final String? errorMessage;

  bool get canSubmit => reason != null && status != SubmitStatus.submitting;

  ReportState copyWith({
    ReportReason? reason,
    String? details,
    SubmitStatus? status,
    String? Function()? errorMessage,
  }) {
    return ReportState(
      reason: reason ?? this.reason,
      details: details ?? this.details,
      status: status ?? this.status,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [reason, details, status, errorMessage];
}

class ReportCubit extends Cubit<ReportState> {
  ReportCubit({
    required ReportRepository repository,
    required this.confessionId,
    required this.maxDetailsLength,
  }) : _repository = repository,
       super(const ReportState());

  final ReportRepository _repository;
  final String confessionId;
  final int maxDetailsLength;

  void reasonSelected(ReportReason reason) =>
      emit(state.copyWith(reason: reason, errorMessage: () => null));

  void detailsChanged(String value) => emit(state.copyWith(details: value));

  Future<void> submit() async {
    final reason = state.reason;
    if (reason == null) {
      emit(state.copyWith(errorMessage: () => 'Choose a reason.'));
      return;
    }
    if (state.status == SubmitStatus.submitting) return;
    if (state.details.trim().length > maxDetailsLength) {
      emit(
        state.copyWith(
          errorMessage: () => 'Keep details under $maxDetailsLength characters.',
        ),
      );
      return;
    }
    emit(
      state.copyWith(status: SubmitStatus.submitting, errorMessage: () => null),
    );
    try {
      await _repository.submit(
        confessionId: confessionId,
        reason: reason,
        details: state.details,
      );
      if (!isClosed) emit(state.copyWith(status: SubmitStatus.success));
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
