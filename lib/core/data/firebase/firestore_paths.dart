/// Single source of truth for Firestore collection and field names.
/// Mirrors `firebase/firestore.rules` and docs/FIREBASE_SETUP.md.
///
/// ```
/// users/{uid}                          private profile + settings
///   posts/{confessionId}               confessions this user wrote
///   likes/{confessionId}               confessions this user liked
///   reactions/{confessionId}           this user's reaction per confession
///   saves/{confessionId}               this user's bookmarks
/// usernames/{usernameLower}            { uid } uniqueness claim
/// confessions/{confessionId}           public post + live counters
///   likes/{uid}                        one doc per person who liked it
///   reactions/{uid}                    one doc per person who reacted
///   views/{uid}                        one doc per qualified reader
/// confessionAuthors/{confessionId}     { uid } private author mapping
/// reports/{confessionId}_{uid}         moderation reports
/// ```
abstract final class FirestorePaths {
  static const users = 'users';
  static const usernames = 'usernames';
  static const reports = 'reports';
  static const confessions = 'confessions';
  static const confessionAuthors = 'confessionAuthors';

  // Subcollections.
  static const likes = 'likes';
  static const reactions = 'reactions';
  static const views = 'views';
  static const posts = 'posts';
  static const saves = 'saves';

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
  static const settings = 'settings';
  static const createdAt = 'createdAt';
  static const updatedAt = 'updatedAt';
}

abstract final class ConfessionFields {
  static const text = 'text';
  static const categoryId = 'categoryId';
  static const mature = 'mature';
  static const status = 'status';
  static const authorDisplayName = 'authorDisplayName';
  static const createdAt = 'createdAt';
  static const likeCount = 'likeCount';
  static const viewCount = 'viewCount';
  static const saveCount = 'saveCount';
  static const reactionCounts = 'reactionCounts';
  static const reactionTotal = 'reactionTotal';
  static const hotScore = 'hotScore';
  static const searchTokens = 'searchTokens';
}

/// Fields on the per-user and per-confession activity documents.
abstract final class ActivityFields {
  static const uid = 'uid';
  static const confessionId = 'confessionId';
  static const reaction = 'reaction';
  static const createdAt = 'createdAt';
}
