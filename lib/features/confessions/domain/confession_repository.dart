import 'confession.dart';

/// Contract used by every BLoC that touches confessions.
///
/// Current implementation: `LocalConfessionRepository` — content from the
/// bundled JSON, with the signed-in user's likes, reactions, saves, views and
/// own posts persisted on the device (keyed by their Firebase uid).
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
  });

  /// Deletes one of the signed-in user's own confessions.
  Future<void> delete(String id);

  Future<List<Confession>> fetchMine();

  Future<bool> isLiked(String id);
  Future<Confession> setLiked(String id, {required bool liked});

  Future<Reaction?> myReaction(String id);

  /// Sets (or clears, with `null`) the user's single reaction.
  Future<Confession> setReaction(String id, Reaction? reaction);

  Future<bool> isSaved(String id);
  Future<void> setSaved(String id, {required bool saved});
  Future<Set<String>> savedIds();
  Future<List<Confession>> fetchSaved();

  Future<bool> hasViewed(String id);

  /// Records a qualifying view. `false` if this user was already counted.
  Future<bool> recordView(String id);

  /// Removes everything stored for the signed-in user (account deletion).
  Future<void> clearUserData();

  Stream<ConfessionChange> get changes;
}
