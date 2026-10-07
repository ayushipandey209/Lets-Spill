import 'package:equatable/equatable.dart';

import '../../settings/domain/app_settings.dart';

/// Age bracket picked during onboarding. Only the bracket is stored,
/// never a birth date.
enum AgeRange {
  teen('13 to 17'),
  young('18 to 24'),
  adult('25 to 34'),
  mid('35 to 44'),
  senior('45+');

  const AgeRange(this.label);
  final String label;

  /// Readers under 18 don't see confessions marked as mature.
  bool get isMinor => this == AgeRange.teen;

  static AgeRange? parse(Object? raw) {
    for (final r in AgeRange.values) {
      if (r.name == raw) return r;
    }
    return null;
  }
}

/// The user's private profile, stored at `users/{uid}` in Firestore.
///
/// [username] is a generated, anonymous handle (e.g. "QuietComet27") that the
/// user picked during onboarding. It never contains their real name.
class UserProfile extends Equatable {
  const UserProfile({
    required this.uid,
    required this.username,
    required this.ageRange,
    required this.preferredCategoryIds,
    this.createdAt,
    this.settings,
  });

  final String uid;
  final String username;
  final AgeRange ageRange;
  final List<String> preferredCategoryIds;
  final DateTime? createdAt;

  /// Settings saved on the account, or `null` if never synced.
  final AppSettings? settings;

  String get handle => '@$username';

  /// Whether mature confessions may be shown to this reader.
  bool get canSeeMature => !ageRange.isMinor;

  UserProfile copyWith({
    List<String>? preferredCategoryIds,
    AppSettings? settings,
  }) {
    return UserProfile(
      uid: uid,
      username: username,
      ageRange: ageRange,
      preferredCategoryIds: preferredCategoryIds ?? this.preferredCategoryIds,
      createdAt: createdAt,
      settings: settings ?? this.settings,
    );
  }

  @override
  List<Object?> get props => [
    uid,
    username,
    ageRange,
    preferredCategoryIds,
    createdAt,
    settings,
  ];
}

/// Everything collected by the tap-only onboarding flow.
class OnboardingChoices extends Equatable {
  const OnboardingChoices({
    required this.username,
    required this.ageRange,
    required this.preferredCategoryIds,
  });

  final String username;
  final AgeRange ageRange;
  final List<String> preferredCategoryIds;

  @override
  List<Object?> get props => [username, ageRange, preferredCategoryIds];
}
