import 'confession.dart';

/// Contract used by every BLoC that touches confessions.
///
/// Production implementation: `FirestoreConfessionRepository`. Every post,
/// like, reaction, save and qualified view is a Firestore document, and the
/// counters on each confession are kept in step with them inside
/// transactions (enforced by `firebase/firestore.rules`).
abstract interface class ConfessionRepository {
  /// One page of published confessions matching [query].
  Future<ConfessionPage> fetchPage(
    FeedQuery query, {
    Object? cursor,
    required int limit,
  });

  /// A featured confession that changes once per day.
  Future<Confession?> confessionOfTheDay({
    Set<String>? preferredCategoryIds,
    required bool includeMature,
  });

  /// Throws `NotFoundException` if missing.
  Future<Confession> fetchById(String id);

  /// Creates a confession shown as [displayName] ("Anonymous" or "@handle").
  Future<Confession> create({
    required String text,
    required String categoryId,
    required String displayName,
    bool mature = false,
  });

  /// Deletes one of the signed-in user's own confessions.
  Future<void> delete(String id);

  /// The signed-in user's own confessions, newest first.
  Future<List<Confession>> fetchMine();

  Future<bool> isLiked(String id);
  Future<Confession> setLiked(String id, {required bool liked});

  /// Which of [ids] the signed-in user has liked.
  Future<Set<String>> likedIds(Iterable<String> ids);

  /// Confessions the signed-in user liked, most recent like first.
  Future<List<Confession>> fetchLiked();

  Future<Reaction?> myReaction(String id);

  /// Sets (or clears, with `null`) the user's single reaction.
  Future<Confession> setReaction(String id, Reaction? reaction);

  Future<bool> isSaved(String id);
  Future<void> setSaved(String id, {required bool saved});
  Future<Set<String>> savedIds();

  /// Saved confessions, most recently saved first.
  Future<List<Confession>> fetchSaved();

  Future<bool> hasViewed(String id);

  /// Records a qualifying view. `false` if this user was already counted.
  Future<bool> recordView(String id);

  /// Removes everything stored for the signed-in user (account deletion):
  /// their posts, and their likes, reactions, saves and views with the
  /// matching counters decremented.
  Future<void> clearUserData();

  Stream<ConfessionChange> get changes;
}
