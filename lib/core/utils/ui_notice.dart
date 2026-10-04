import 'package:equatable/equatable.dart';

/// A one-shot message (e.g. for a SnackBar) carried in immutable state.
///
/// Each notice has a unique [id], so emitting the same text twice still
/// produces a distinct state that `BlocListener` will react to.
class UiNotice extends Equatable {
  UiNotice(this.message, {this.isError = false}) : id = _next++;

  static int _next = 0;

  final int id;
  final String message;
  final bool isError;

  @override
  List<Object?> get props => [id, message, isError];
}

/// Status shared by simple submit-style forms.
enum SubmitStatus { idle, submitting, success, failure }
