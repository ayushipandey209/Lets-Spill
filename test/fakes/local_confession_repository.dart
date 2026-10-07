import 'dart:async';
import 'dart:math' as math;

import 'package:let_s_spill/core/errors/app_exception.dart';
import 'package:let_s_spill/features/confessions/domain/confession.dart';
import 'package:let_s_spill/features/confessions/domain/confession_repository.dart';
import 'package:let_s_spill/features/confessions/domain/ranking.dart';

import 'local_content_store.dart';

/// In-memory [ConfessionRepository] for tests. Same behaviour as the
/// Firestore implementation: counters move with activity, one like / view /
/// reaction per reader.
class LocalConfessionRepository implements ConfessionRepository {
  LocalConfessionRepository(
    this._store, {
    required this.maxLength,
    required this.minLength,
  });

  final LocalContentStore _store;
  final int maxLength;
  final int minLength;
  final _changes = StreamController<ConfessionChange>.broadcast();

  @override
  Stream<ConfessionChange> get changes => _changes.stream;

  // ---------------------------------------------------------------- reads ---

  Iterable<Confession> _visible(FeedQuery q) {
    final search = q.search?.trim().toLowerCase();
    return _store.confessions.where((c) {
      if (c.status != ConfessionStatus.published) return false;
      if (!q.includeMature && c.mature) return false;
      final cats = q.categoryIds;
      if (cats != null && !cats.contains(c.categoryId)) return false;
      if (search != null && search.isNotEmpty) {
        final hay = '${c.text} ${c.categoryId}'.toLowerCase();
        if (!search.split(RegExp(r'\s+')).every(hay.contains)) return false;
      }
      return true;
    });
  }

  /// Same ranking the Firestore implementation stores on each document.
  double hotScore(Confession c) => Ranking.hotScore(
    createdAt: c.createdAt,
    likes: c.likeCount,
    reactions: c.totalReactions,
  );

  @override
  Future<ConfessionPage> fetchPage(
    FeedQuery query, {
    Object? cursor,
    required int limit,
  }) async {
    await _store.simulateLatency();
    final offset = cursor is int ? cursor : 0;
    final items = _visible(query).toList();
    if (!query.hasSearch) {
      switch (query.sort) {
        case FeedSort.latest:
          break;
        case FeedSort.hot:
          items.sort((a, b) => hotScore(b).compareTo(hotScore(a)));
        case FeedSort.top:
          items.sort((a, b) => b.likeCount.compareTo(a.likeCount));
      }
    }
    final end = math.min(offset + limit, items.length);
    final page = offset >= items.length
        ? const <Confession>[]
        : items.sublist(offset, end);
    final hasMore = end < items.length;
    return ConfessionPage(
      items: page,
      hasMore: hasMore,
      cursor: hasMore ? end : null,
    );
  }

  @override
  Future<Confession?> confessionOfTheDay({
    Set<String>? preferredCategoryIds,
    required bool includeMature,
  }) async {
    var pool = _visible(
      FeedQuery(
        categoryIds: preferredCategoryIds == null || preferredCategoryIds.isEmpty
            ? null
            : preferredCategoryIds,
        includeMature: includeMature,
      ),
    ).toList();
    if (pool.isEmpty) {
      pool = _visible(FeedQuery(includeMature: includeMature)).toList();
    }
    if (pool.isEmpty) return null;
    pool.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    final top = pool.take(10).toList();
    final today = _store.now();
    final dayIndex = DateTime.utc(today.year, today.month, today.day)
        .difference(DateTime.utc(2024))
        .inDays;
    return top[dayIndex % top.length];
  }

  @override
  Future<Confession> fetchById(String id) async {
    await _store.simulateLatency();
    final c = _store.find(id);
    if (c == null) throw const NotFoundException();
    return c;
  }

  // ------------------------------------------------------------- authoring ---

  @override
  Future<Confession> create({
    required String text,
    required String categoryId,
    required String displayName,
    bool mature = false,
  }) async {
    final me = _store.requireActivity();
    final trimmed = text.trim();
    if (trimmed.length < minLength || trimmed.length > maxLength) {
      throw ValidationException(
        'Confessions must be between $minLength and $maxLength characters.',
      );
    }
    final name = displayName == Confession.anonymousName ||
            displayName.startsWith('@')
        ? displayName
        : Confession.anonymousName;
    await _store.simulateLatency();
    final confession = Confession(
      id: _store.newId('local'),
      categoryId: categoryId,
      text: trimmed,
      createdAt: _store.now().toUtc(),
      authorDisplayName: name,
      mature: mature,
    );
    _store.confessions.insert(0, confession);
    me.owned.add(confession.id);
    await _store.persist();
    _changes.add(ConfessionCreated(confession));
    return confession;
  }

  @override
  Future<void> delete(String id) async {
    final me = _store.requireActivity();
    if (!me.owned.contains(id)) {
      throw const PermissionException('You can only delete your own posts.');
    }
    await _store.simulateLatency();
    _removeConfession(id);
    await _store.persist();
    _changes.add(ConfessionDeleted(id));
  }

  void _removeConfession(String id) {
    _store.confessions.removeWhere((c) => c.id == id);
    for (final a in _store.activity.values) {
      a.likes.remove(id);
      a.views.remove(id);
      a.reactions.remove(id);
      a.saved.remove(id);
      a.owned.remove(id);
    }
  }

  @override
  Future<List<Confession>> fetchMine() async {
    final me = _store.requireActivity();
    await _store.simulateLatency();
    return _store.confessions
        .where((c) => me.owned.contains(c.id))
        .toList(growable: false);
  }

  // ------------------------------------------------------------ engagement ---

  Confession _require(String id) {
    final c = _store.find(id);
    if (c == null) throw const NotFoundException();
    return c;
  }

  Future<Confession> _commit(Confession updated) async {
    _store.replace(updated);
    await _store.persist();
    _changes.add(ConfessionUpdated(updated));
    return updated;
  }

  @override
  Future<bool> isLiked(String id) async =>
      _store.requireActivity().likes.contains(id);

  @override
  Future<Confession> setLiked(String id, {required bool liked}) async {
    final me = _store.requireActivity();
    final current = _require(id);
    if (me.likes.contains(id) == liked) return current;
    final Confession updated;
    if (liked) {
      me.likes.add(id);
      updated = await _commit(current.copyWith(likeCount: current.likeCount + 1));
    } else {
      me.likes.remove(id);
      updated = await _commit(
        current.copyWith(likeCount: math.max(0, current.likeCount - 1)),
      );
    }
    _changes.add(ConfessionLikedChanged(updated, liked: liked));
    return updated;
  }

  @override
  Future<Set<String>> likedIds(Iterable<String> ids) async {
    final me = _store.requireActivity();
    return ids.where(me.likes.contains).toSet();
  }

  @override
  Future<List<Confession>> fetchLiked() async {
    final me = _store.requireActivity();
    await _store.simulateLatency();
    return me.likes
        .toList()
        .reversed
        .map(_store.find)
        .whereType<Confession>()
        .toList(growable: false);
  }

  @override
  Future<Reaction?> myReaction(String id) async =>
      _store.requireActivity().reactions[id];

  @override
  Future<Confession> setReaction(String id, Reaction? reaction) async {
    final me = _store.requireActivity();
    final current = _require(id);
    final previous = me.reactions[id];
    if (previous == reaction) return current;
    final counts = Map<Reaction, int>.of(current.reactionCounts);
    if (previous != null) {
      counts[previous] = math.max(0, (counts[previous] ?? 0) - 1);
    }
    if (reaction != null) {
      counts[reaction] = (counts[reaction] ?? 0) + 1;
      me.reactions[id] = reaction;
    } else {
      me.reactions.remove(id);
    }
    return _commit(current.copyWith(reactionCounts: Map.unmodifiable(counts)));
  }

  @override
  Future<bool> isSaved(String id) async =>
      _store.requireActivity().saved.contains(id);

  @override
  Future<void> setSaved(String id, {required bool saved}) async {
    final me = _store.requireActivity();
    final current = _require(id);
    if (me.saved.contains(id) == saved) return;
    saved ? me.saved.add(id) : me.saved.remove(id);
    final updated = current.copyWith(
      saveCount: math.max(0, current.saveCount + (saved ? 1 : -1)),
    );
    _store.replace(updated);
    await _store.persist();
    _changes.add(ConfessionSavedChanged(updated, saved: saved));
  }

  @override
  Future<Set<String>> savedIds() async =>
      Set.unmodifiable(_store.requireActivity().saved);

  @override
  Future<List<Confession>> fetchSaved() async {
    final me = _store.requireActivity();
    await _store.simulateLatency();
    // Newest saves first.
    return me.saved
        .toList()
        .reversed
        .map(_store.find)
        .whereType<Confession>()
        .toList(growable: false);
  }

  @override
  Future<bool> hasViewed(String id) async =>
      _store.requireActivity().views.contains(id);

  @override
  Future<bool> recordView(String id) async {
    final me = _store.requireActivity();
    if (me.views.contains(id)) return false;
    final current = _store.find(id);
    if (current == null) return false;
    me.views.add(id);
    await _commit(current.copyWith(viewCount: current.viewCount + 1));
    return true;
  }

  @override
  Future<void> clearUserData() async {
    final uid = _store.currentUid;
    if (uid == null) return;
    final me = _store.activity.remove(uid);
    if (me == null) return;
    for (final id in me.owned) {
      _store.confessions.removeWhere((c) => c.id == id);
    }
    for (final id in me.likes) {
      final c = _store.find(id);
      if (c != null) _store.replace(c.copyWith(likeCount: math.max(0, c.likeCount - 1)));
    }
    for (final id in me.saved) {
      final c = _store.find(id);
      if (c != null) _store.replace(c.copyWith(saveCount: math.max(0, c.saveCount - 1)));
    }
    for (final id in me.views) {
      final c = _store.find(id);
      if (c != null) _store.replace(c.copyWith(viewCount: math.max(0, c.viewCount - 1)));
    }
    me.reactions.forEach((id, reaction) {
      final c = _store.find(id);
      if (c == null) return;
      final counts = Map<Reaction, int>.of(c.reactionCounts);
      counts[reaction] = math.max(0, (counts[reaction] ?? 0) - 1);
      _store.replace(c.copyWith(reactionCounts: Map.unmodifiable(counts)));
    });
    await _store.persist();
  }

  Future<void> dispose() => _changes.close();
}
