import 'package:equatable/equatable.dart';

/// The signed-in Google account. Private, never rendered on public content.
class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    this.displayName = '',
    this.email = '',
  });

  /// Stable Firebase Auth UID.
  final String uid;

  /// Google account name and email, shown only on the private profile.
  final String displayName;
  final String email;

  @override
  List<Object?> get props => [uid, displayName, email];
}
