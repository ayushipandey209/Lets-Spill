/// Base type for every expected, user-presentable failure.
///
/// Repositories translate SDK/platform errors into these so BLoCs and widgets
/// never depend on Firebase or JSON specifics.
sealed class AppException implements Exception {
  const AppException(this.message);

  /// Human-readable, safe-to-display message.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Invalid credentials, email in use, weak password, etc.
class AuthException extends AppException {
  const AuthException(super.message, {this.code});
  final String? code;
}

/// The user closed the Google account picker. Not an error worth showing.
class SignInCancelledException extends AppException {
  const SignInCancelledException() : super('Sign-in was cancelled.');
}

/// The chosen anonymous username was claimed by someone else.
class UsernameTakenException extends AppException {
  const UsernameTakenException()
    : super('That name was just taken. Pick another one.');
}

/// The device appears to be offline or the service is unreachable.
class NetworkException extends AppException {
  const NetworkException([
    super.message = 'You seem to be offline. Check your connection and retry.',
  ]);
}

/// The signed-in user is not allowed to perform the action.
class PermissionException extends AppException {
  const PermissionException([
    super.message = "You don't have permission to do that.",
  ]);
}

/// The requested item no longer exists (e.g. deleted confession).
class NotFoundException extends AppException {
  const NotFoundException([super.message = 'This confession is no longer available.']);
}

/// Input rejected before or by the data layer.
class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// An operation is only available in a particular data mode.
class UnsupportedOperationException extends AppException {
  const UnsupportedOperationException(super.message);
}

/// Firebase mode was selected but the app has not been configured.
class ConfigurationException extends AppException {
  const ConfigurationException(super.message, {this.setupSteps = const []});
  final List<String> setupSteps;
}

/// Anything unexpected. The original error is kept for logging only.
class UnknownException extends AppException {
  const UnknownException([
    super.message = 'Something went wrong. Please try again.',
    this.cause,
  ]);
  final Object? cause;
}

/// Converts any thrown object into an [AppException].
AppException asAppException(Object error) {
  if (error is AppException) return error;
  return UnknownException('Something went wrong. Please try again.', error);
}
