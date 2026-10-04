/// Single source of truth for Firestore collection / field names.
/// Mirrors `firebase/firestore.rules` and docs/FIREBASE_SETUP.md.
abstract final class FirestorePaths {
  static const users = 'users';
  static const usernames = 'usernames';
  static const reports = 'reports';

  /// Report ids are deterministic: one report per user per confession.
  static String reportId(String confessionId, String uid) =>
      '${confessionId}_$uid';
}

abstract final class UserFields {
  static const username = 'username';
  static const usernameLower = 'usernameLower';
  static const ageRange = 'ageRange';
  static const preferredCategoryIds = 'preferredCategoryIds';
  static const onboardingComplete = 'onboardingComplete';
  static const createdAt = 'createdAt';
  static const updatedAt = 'updatedAt';
}
