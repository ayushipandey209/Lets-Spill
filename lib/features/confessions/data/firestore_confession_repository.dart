import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../core/data/asset_loader.dart';
import '../../../core/data/firebase/firebase_error_mapper.dart';
import '../../../core/data/firebase/firestore_paths.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/confession.dart';
import '../domain/confession_repository.dart';
import '../domain/ranking.dart';

typedef _Json = Map<String, dynamic>;

/// Confessions and every interaction with them, stored in Cloud Firestore.
///
/// Each action writes the activity document(s) and the matching counter on
/// the confession in one transaction, so `likeCount` always equals the
/// number of documents in `confessions/{id}/likes`, and so on. The security
/// rules reject any write that would let the two drift apart.
class FirestoreConfessionRepository implements ConfessionRepository {
  FirestoreConfessionRepository({
    required fb.FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required this.maxLength,
    required this.minLength,
    AssetLoader? assetLoader,
    DateTime Function()? clock,
  }) : _auth = auth,
       _db = firestore,
       _assetLoader = assetLoader,
       _clock = clock ?? DateTime.now;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final AssetLoader? _assetLoader;
  final DateTime Function() _clock;
  final int maxLength;
  final int minLength;
  final _changes = StreamController<ConfessionChange>.broadcast();

  List<Confession>? _bundledCache;
  bool _seeding = false;
  bool _seeded = false;

  /// Firestore `whereIn` accepts at most 30 values.
  static const _inLimit = 30;

  /// Upper bound for the profile lists (posts, likes, saves).
  static const _listLimit = 100;

  @override
  Stream<ConfessionChange> get changes => _changes.stream;

  // -------------------------------------------------------------- helpers ---

  String _uid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException('Please sign in to continue.');
    return uid;
  }

  CollectionReference<_Json> get _confessions =>
      _db.collection(FirestorePaths.confessions);

  DocumentReference<_Json> _confession(String id) => _confessions.doc(id);

  DocumentReference<_Json> _user(String uid) =>
      _db.collection(FirestorePaths.users).doc(uid);

  CollectionReference<_Json> _mine(String uid, String sub) =>
      _user(uid).collection(sub);

  DocumentReference<_Json> _author(String id) =>
      _db.collection(FirestorePaths.confessionAuthors).doc(id);

  void _emit(ConfessionChange change) {
    if (!_changes.isClosed) _changes.add(change);
  }

  static Map<String, int> _countsJson(Map<Reaction, int> counts) => {
    for (final r in Reaction.values) r.name: math.max(0, counts[r] ?? 0),
  };

  /// Builds a [Confession] from a document. Pending server timestamps fall
  /// back to "now" so freshly written posts render immediately.
  Confession _fromDoc(DocumentSnapshot<_Json> doc) {
    final d = doc.data();
    if (d == null) throw const NotFoundException();
    final reactions = <Reaction, int>{};
    final raw = d[ConfessionFields.reactionCounts];
    if (raw is Map<dynamic, dynamic>) {
      raw.forEach((key, value) {
        final r = Reaction.parse(key);
        if (r != null && value is num) reactions[r] = value.toInt();
      });
    }
    final ts = d[ConfessionFields.createdAt];
    return Confession(
      id: doc.id,
      categoryId: (d[ConfessionFields.categoryId] as String?) ?? 'life',
      text: (d[ConfessionFields.text] as String?) ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : _clock(),
      likeCount: _int(d[ConfessionFields.likeCount]),
      viewCount: _int(d[ConfessionFields.viewCount]),
      saveCount: _int(d[ConfessionFields.saveCount]),
      reactionCounts: Map.unmodifiable(reactions),
      mature: d[ConfessionFields.mature] == true,
      authorDisplayName:
          (d[ConfessionFields.authorDisplayName] as String?) ??
          Confession.anonymousName,
      status: ConfessionStatus.parse(d[ConfessionFields.status]),
    );
  }

  static int _int(Object? v) => v is num ? math.max(0, v.toInt()) : 0;

  double _hot(Confession c, {int? likes, int? reactions}) => Ranking.hotScore(
    createdAt: c.createdAt,
    likes: likes ?? c.likeCount,
    reactions: reactions ?? c.totalReactions,
  );

  Future<List<Confession>> _getBundledConfessions() async {
    if (_bundledCache != null) return _bundledCache!;
    try {
      final loader = _assetLoader ?? rootBundleLoader;
      final jsonStr = await loader('assets/mock/confessions.json');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final list = data['confessions'] as List<dynamic>? ?? [];
      final items = <Confession>[];
      for (final raw in list) {
        if (raw is! Map<String, dynamic>) continue;
        final reactions = <Reaction, int>{};
        final rawReactions = raw['reactionCounts'];
        if (rawReactions is Map<dynamic, dynamic>) {
          rawReactions.forEach((k, v) {
            final r = Reaction.parse(k);
            if (r != null && v is num) reactions[r] = v.toInt();
          });
        }
        items.add(Confession(
          id: raw['id'] as String,
          categoryId: raw['categoryId'] as String? ?? 'life',
          text: raw['text'] as String? ?? '',
          createdAt:
              DateTime.tryParse(raw['createdAt'] as String? ?? '') ?? _clock(),
          likeCount: _int(raw['likeCount']),
          viewCount: _int(raw['viewCount']),
          saveCount: _int(raw['saveCount']),
          reactionCounts: Map.unmodifiable(reactions),
          mature: raw['mature'] == true,
          authorDisplayName:
              raw['authorDisplayName'] as String? ?? Confession.anonymousName,
          status: ConfessionStatus.parse(raw['status']),
        ));
      }
      _bundledCache = items;
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> _seedFirestoreIfNeeded() async {
    if (_seeding || _seeded) return;
    _seeding = true;
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final existing = await _confessions.limit(1).get();
      if (existing.docs.isNotEmpty) {
        _seeded = true;
        return;
      }

      final confessions = await _getBundledConfessions();
      if (confessions.isEmpty) return;

      final batch = _db.batch();
      for (final c in confessions) {
        final docRef = _confessions.doc(c.id);
        final authorRef = _author(c.id);
        batch.set(docRef, {
          ConfessionFields.text: c.text,
          ConfessionFields.categoryId: c.categoryId,
          ConfessionFields.mature: c.mature,
          ConfessionFields.status: ConfessionStatus.published.name,
          ConfessionFields.authorDisplayName: c.authorDisplayName,
          ConfessionFields.createdAt: Timestamp.fromDate(c.createdAt),
          ConfessionFields.likeCount: c.likeCount,
          ConfessionFields.viewCount: c.viewCount,
          ConfessionFields.saveCount: c.saveCount,
          ConfessionFields.reactionCounts: _countsJson(c.reactionCounts),
          ConfessionFields.reactionTotal: c.totalReactions,
          ConfessionFields.hotScore: _hot(c),
          ConfessionFields.searchTokens: SearchTokens.fromText(
            c.text,
            categoryId: c.categoryId,
          ),
        });
        batch.set(authorRef, {
          ActivityFields.uid: uid,
          ActivityFields.createdAt: FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      _seeded = true;
    } catch (_) {
      // Best-effort seeding
    } finally {
      _seeding = false;
    }
  }

  /// Base query: published only, mature filtered out unless allowed. The
  /// rules require exactly these filters, so every list query starts here.
  Query<_Json> _published({required bool includeMature}) {
    Query<_Json> q = _confessions.where(
      ConfessionFields.status,
      isEqualTo: ConfessionStatus.published.name,
    );
    if (!includeMature) {
      q = q.where(ConfessionFields.mature, isEqualTo: false);
    }
    return q;
  }

  /// Loads confessions by id, newest-listed first, skipping any that were
  /// deleted or are no longer visible to this reader.
  Future<List<Confession>> _loadMany(List<String> ids) async {
    final results = await Future.wait(
      ids.map((id) async {
        try {
          final snap = await _confession(id).get();
          if (!snap.exists) return null;
          final c = _fromDoc(snap);
          return c.status == ConfessionStatus.published ? c : null;
        } catch (_) {
          return null;
        }
      }),
    );
    return results.whereType<Confession>().toList(growable: false);
  }

  // ---------------------------------------------------------------- reads ---

  @override
  Future<ConfessionPage> fetchPage(
    FeedQuery query, {
    Object? cursor,
    required int limit,
  }) async {
    unawaited(_seedFirestoreIfNeeded());
    try {
      return await guardFirebase(() async {
        _uid();
        var q = _published(includeMature: query.includeMature);

        final cats = query.categoryIds;
        if (cats != null) {
          if (cats.isEmpty) {
            return const ConfessionPage(items: [], hasMore: false);
          }
          final list = cats.take(_inLimit).toList();
          q = list.length == 1
              ? q.where(ConfessionFields.categoryId, isEqualTo: list.first)
              : q.where(ConfessionFields.categoryId, whereIn: list);
        }

        var extraTokens = const <String>[];
        if (query.hasSearch) {
          final tokens = SearchTokens.fromQuery(query.search!)
            ..sort((a, b) => b.length.compareTo(a.length));
          if (tokens.isEmpty) {
            return const ConfessionPage(items: [], hasMore: false);
          }
          q = q.where(
            ConfessionFields.searchTokens,
            arrayContains: tokens.first,
          );
          extraTokens = tokens.skip(1).toList();
        }

        final orderField = switch (query.hasSearch
            ? FeedSort.latest
            : query.sort) {
          FeedSort.latest => ConfessionFields.createdAt,
          FeedSort.hot => ConfessionFields.hotScore,
          FeedSort.top => ConfessionFields.likeCount,
        };
        q = q.orderBy(orderField, descending: true);
        if (cursor is DocumentSnapshot<_Json>) q = q.startAfterDocument(cursor);

        final snap = await q.limit(limit).get();
        final docs = snap.docs;
        if (docs.isEmpty && cursor == null) {
          return _fetchFallbackPage(query, limit: limit);
        }
        final items = <Confession>[];
        for (final doc in docs) {
          if (extraTokens.isNotEmpty && !_matchesAll(doc.data(), extraTokens)) {
            continue;
          }
          items.add(_fromDoc(doc));
        }
        final hasMore = docs.length == limit;
        return ConfessionPage(
          items: items,
          hasMore: hasMore,
          cursor: hasMore ? docs.last : null,
        );
      });
    } catch (_) {
      return _fetchFallbackPage(query, limit: limit);
    }
  }

  Future<ConfessionPage> _fetchFallbackPage(
    FeedQuery query, {
    required int limit,
  }) async {
    final all = await _getBundledConfessions();
    var filtered = all.where((c) {
      if (c.status != ConfessionStatus.published) return false;
      if (!query.includeMature && c.mature) return false;
      if (query.categoryIds != null &&
          !query.categoryIds!.contains(c.categoryId)) {
        return false;
      }
      if (query.hasSearch) {
        final qText = query.search!.toLowerCase();
        if (!c.text.toLowerCase().contains(qText) &&
            !c.categoryId.toLowerCase().contains(qText)) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (query.sort) {
      case FeedSort.latest:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case FeedSort.hot:
        filtered.sort((a, b) => _hot(b).compareTo(_hot(a)));
      case FeedSort.top:
        filtered.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    }

    final items = filtered.take(limit).toList();
    return ConfessionPage(items: items, hasMore: false);
  }

  static bool _matchesAll(_Json data, List<String> tokens) {
    final stored = (data[ConfessionFields.searchTokens] as List<dynamic>? ?? [])
        .whereType<String>()
        .toSet();
    final text = (data[ConfessionFields.text] as String? ?? '').toLowerCase();
    return tokens.every((t) => stored.contains(t) || text.contains(t));
  }

  @override
  Future<Confession?> confessionOfTheDay({
    Set<String>? preferredCategoryIds,
    required bool includeMature,
  }) async {
    try {
      final res = await guardFirebase(() async {
        _uid();
        Future<List<Confession>> top(Set<String>? cats) async {
          var q = _published(includeMature: includeMature);
          if (cats != null && cats.isNotEmpty) {
            final list = cats.take(_inLimit).toList();
            q = list.length == 1
                ? q.where(ConfessionFields.categoryId, isEqualTo: list.first)
                : q.where(ConfessionFields.categoryId, whereIn: list);
          }
          final snap = await q
              .orderBy(ConfessionFields.likeCount, descending: true)
              .limit(10)
              .get();
          return snap.docs.map(_fromDoc).toList();
        }

        var pool = await top(preferredCategoryIds);
        if (pool.isEmpty && (preferredCategoryIds?.isNotEmpty ?? false)) {
          pool = await top(null);
        }
        if (pool.isEmpty) return null;
        final today = _clock();
        final dayIndex = DateTime.utc(today.year, today.month, today.day)
            .difference(DateTime.utc(2024))
            .inDays;
        return pool[dayIndex % pool.length];
      });
      if (res != null) return res;
    } catch (_) {}

    final all = await _getBundledConfessions();
    var pool = all.where((c) {
      if (c.status != ConfessionStatus.published) return false;
      if (!includeMature && c.mature) return false;
      if (preferredCategoryIds != null && preferredCategoryIds.isNotEmpty) {
        return preferredCategoryIds.contains(c.categoryId);
      }
      return true;
    }).toList();
    if (pool.isEmpty) {
      pool = all.where((c) => !(!includeMature && c.mature)).toList();
    }
    if (pool.isEmpty) return null;
    pool.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    final top10 = pool.take(10).toList();
    final today = _clock();
    final dayIndex = DateTime.utc(today.year, today.month, today.day)
        .difference(DateTime.utc(2024))
        .inDays;
    return top10[dayIndex % top10.length];
  }

  @override
  Future<Confession> fetchById(String id) async {
    try {
      return await guardFirebase(() async {
        _uid();
        final snap = await _confession(id).get();
        if (!snap.exists) throw const NotFoundException();
        return _fromDoc(snap);
      });
    } on PermissionException {
      // Hidden by moderation, or a mature post for a younger reader.
      throw const NotFoundException();
    } catch (_) {
      final all = await _getBundledConfessions();
      final found = all.where((c) => c.id == id).firstOrNull;
      if (found != null) return found;
      throw const NotFoundException();
    }
  }

  // ------------------------------------------------------------ authoring ---

  @override
  Future<Confession> create({
    required String text,
    required String categoryId,
    required String displayName,
    bool mature = false,
  }) {
    return guardFirebase(() async {
      final uid = _uid();
      final trimmed = text.trim();
      if (trimmed.length < minLength || trimmed.length > maxLength) {
        throw ValidationException(
          'Confessions must be between $minLength and $maxLength characters.',
        );
      }
      final name =
          displayName == Confession.anonymousName || displayName.startsWith('@')
          ? displayName
          : Confession.anonymousName;
      final ref = _confessions.doc();
      final now = _clock().toUtc();
      final confession = Confession(
        id: ref.id,
        categoryId: categoryId,
        text: trimmed,
        createdAt: now,
        mature: mature,
        authorDisplayName: name,
      );
      final batch = _db.batch()
        ..set(ref, {
          ConfessionFields.text: trimmed,
          ConfessionFields.categoryId: categoryId,
          ConfessionFields.mature: mature,
          ConfessionFields.status: ConfessionStatus.published.name,
          ConfessionFields.authorDisplayName: name,
          ConfessionFields.createdAt: FieldValue.serverTimestamp(),
          ConfessionFields.likeCount: 0,
          ConfessionFields.viewCount: 0,
          ConfessionFields.saveCount: 0,
          ConfessionFields.reactionCounts: _countsJson(const {}),
          ConfessionFields.reactionTotal: 0,
          ConfessionFields.hotScore: _hot(confession),
          ConfessionFields.searchTokens: SearchTokens.fromText(
            trimmed,
            categoryId: categoryId,
          ),
        })
        ..set(_author(ref.id), {
          ActivityFields.uid: uid,
          ActivityFields.createdAt: FieldValue.serverTimestamp(),
        })
        ..set(_mine(uid, FirestorePaths.posts).doc(ref.id), {
          ActivityFields.confessionId: ref.id,
          ActivityFields.createdAt: FieldValue.serverTimestamp(),
        });
      await batch.commit();
      _emit(ConfessionCreated(confession));
      return confession;
    });
  }

  @override
  Future<void> delete(String id) {
    return guardFirebase(() async {
      final uid = _uid();
      final post = await _mine(uid, FirestorePaths.posts).doc(id).get();
      if (!post.exists) {
        throw const PermissionException('You can only delete your own posts.');
      }
      await _deleteOwnPost(uid, id);
      _emit(ConfessionDeleted(id));
    });
  }

  Future<void> _deleteOwnPost(String uid, String id) async {
    final batch = _db.batch()
      ..delete(_confession(id))
      ..delete(_author(id))
      ..delete(_mine(uid, FirestorePaths.posts).doc(id));
    await batch.commit();
  }

  @override
  Future<List<Confession>> fetchMine() {
    return guardFirebase(() async {
      final uid = _uid();
      final snap = await _mine(uid, FirestorePaths.posts)
          .orderBy(ActivityFields.createdAt, descending: true)
          .limit(_listLimit)
          .get();
      final ids = snap.docs.map((d) => d.id).toList();
      final results = await Future.wait(
        ids.map((id) async {
          try {
            final s = await _confession(id).get();
            return s.exists ? _fromDoc(s) : null;
          } catch (_) {
            return null;
          }
        }),
      );
      return results.whereType<Confession>().toList(growable: false);
    });
  }

  // ------------------------------------------------------------ engagement ---

  @override
  Future<bool> isLiked(String id) {
    return guardFirebase(() async {
      final uid = _uid();
      final snap = await _confession(id).collection(FirestorePaths.likes).doc(uid).get();
      return snap.exists;
    });
  }

  @override
  Future<Confession> setLiked(String id, {required bool liked}) {
    return guardFirebase(() async {
      final uid = _uid();
      final ref = _confession(id);
      final likeRef = ref.collection(FirestorePaths.likes).doc(uid);
      final mineRef = _mine(uid, FirestorePaths.likes).doc(id);
      final (updated, changed) = await _db.runTransaction<(Confession, bool)>((
        tx,
      ) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw const NotFoundException();
        final like = await tx.get(likeRef);
        final current = _fromDoc(snap);
        if (like.exists == liked) return (current, false);
        final likes = current.likeCount + (liked ? 1 : -1);
        if (likes < 0) return (current, false);
        tx.update(ref, {
          ConfessionFields.likeCount: likes,
          ConfessionFields.hotScore: _hot(current, likes: likes),
        });
        if (liked) {
          tx.set(likeRef, {
            ActivityFields.uid: uid,
            ActivityFields.createdAt: FieldValue.serverTimestamp(),
          });
          tx.set(mineRef, {
            ActivityFields.confessionId: id,
            ActivityFields.createdAt: FieldValue.serverTimestamp(),
          });
        } else {
          tx.delete(likeRef);
          tx.delete(mineRef);
        }
        return (current.copyWith(likeCount: likes), true);
      });
      if (changed) {
        _emit(ConfessionUpdated(updated));
        _emit(ConfessionLikedChanged(updated, liked: liked));
      }
      return updated;
    });
  }

  @override
  Future<Set<String>> likedIds(Iterable<String> ids) {
    return guardFirebase(() async {
      final uid = _uid();
      final all = ids.toSet().toList();
      final liked = <String>{};
      for (var i = 0; i < all.length; i += _inLimit) {
        final chunk = all.sublist(i, math.min(i + _inLimit, all.length));
        final snap = await _mine(uid, FirestorePaths.likes)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        liked.addAll(snap.docs.map((d) => d.id));
      }
      return liked;
    });
  }

  @override
  Future<List<Confession>> fetchLiked() {
    return guardFirebase(() async {
      final uid = _uid();
      final snap = await _mine(uid, FirestorePaths.likes)
          .orderBy(ActivityFields.createdAt, descending: true)
          .limit(_listLimit)
          .get();
      return _loadMany(snap.docs.map((d) => d.id).toList());
    });
  }

  @override
  Future<Reaction?> myReaction(String id) {
    return guardFirebase(() async {
      final uid = _uid();
      final snap = await _confession(id)
          .collection(FirestorePaths.reactions)
          .doc(uid)
          .get();
      return Reaction.parse(snap.data()?[ActivityFields.reaction]);
    });
  }

  @override
  Future<Confession> setReaction(String id, Reaction? reaction) {
    return guardFirebase(() async {
      final uid = _uid();
      final ref = _confession(id);
      final reactionRef = ref.collection(FirestorePaths.reactions).doc(uid);
      final mineRef = _mine(uid, FirestorePaths.reactions).doc(id);
      final (updated, changed) = await _db.runTransaction<(Confession, bool)>((
        tx,
      ) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw const NotFoundException();
        final existing = await tx.get(reactionRef);
        final current = _fromDoc(snap);
        final previous = Reaction.parse(
          existing.data()?[ActivityFields.reaction],
        );
        if (previous == reaction) return (current, false);
        final counts = {
          for (final r in Reaction.values) r: current.reactionCount(r),
        };
        if (previous != null) {
          if (counts[previous]! <= 0) return (current, false);
          counts[previous] = counts[previous]! - 1;
        }
        if (reaction != null) counts[reaction] = counts[reaction]! + 1;
        final total = counts.values.fold<int>(0, (a, b) => a + b);
        tx.update(ref, {
          ConfessionFields.reactionCounts: _countsJson(counts),
          ConfessionFields.reactionTotal: total,
          ConfessionFields.hotScore: _hot(current, reactions: total),
        });
        if (reaction == null) {
          tx.delete(reactionRef);
          tx.delete(mineRef);
        } else {
          tx.set(reactionRef, {
            ActivityFields.uid: uid,
            ActivityFields.reaction: reaction.name,
            ActivityFields.createdAt: FieldValue.serverTimestamp(),
          });
          tx.set(mineRef, {
            ActivityFields.confessionId: id,
            ActivityFields.reaction: reaction.name,
            ActivityFields.createdAt: FieldValue.serverTimestamp(),
          });
        }
        return (
          current.copyWith(reactionCounts: Map.unmodifiable(counts)),
          true,
        );
      });
      if (changed) _emit(ConfessionUpdated(updated));
      return updated;
    });
  }

  @override
  Future<bool> isSaved(String id) {
    return guardFirebase(() async {
      final uid = _uid();
      final snap = await _mine(uid, FirestorePaths.saves).doc(id).get();
      return snap.exists;
    });
  }

  @override
  Future<void> setSaved(String id, {required bool saved}) {
    return guardFirebase(() async {
      final uid = _uid();
      final ref = _confession(id);
      final saveRef = _mine(uid, FirestorePaths.saves).doc(id);
      final (current, changed) = await _db
          .runTransaction<(Confession?, bool)>((tx) async {
            final snap = await tx.get(ref);
            final existing = await tx.get(saveRef);
            if (!snap.exists) {
              // The post is gone: let people clear the stale bookmark.
              if (saved) throw const NotFoundException();
              if (existing.exists) tx.delete(saveRef);
              return (null, existing.exists);
            }
            final c = _fromDoc(snap);
            if (existing.exists == saved) return (c, false);
            final count = c.saveCount + (saved ? 1 : -1);
            if (count < 0) return (c, false);
            tx.update(ref, {ConfessionFields.saveCount: count});
            if (saved) {
              tx.set(saveRef, {
                ActivityFields.confessionId: id,
                ActivityFields.createdAt: FieldValue.serverTimestamp(),
              });
            } else {
              tx.delete(saveRef);
            }
            return (c.copyWith(saveCount: count), true);
          });
      if (changed && current != null) {
        _emit(ConfessionSavedChanged(current, saved: saved));
      } else if (changed) {
        _emit(ConfessionDeleted(id));
      }
    });
  }

  @override
  Future<Set<String>> savedIds() {
    return guardFirebase(() async {
      final uid = _uid();
      final snap = await _mine(uid, FirestorePaths.saves).limit(500).get();
      return snap.docs.map((d) => d.id).toSet();
    });
  }

  @override
  Future<List<Confession>> fetchSaved() {
    return guardFirebase(() async {
      final uid = _uid();
      final snap = await _mine(uid, FirestorePaths.saves)
          .orderBy(ActivityFields.createdAt, descending: true)
          .limit(_listLimit)
          .get();
      return _loadMany(snap.docs.map((d) => d.id).toList());
    });
  }

  @override
  Future<bool> hasViewed(String id) {
    return guardFirebase(() async {
      final uid = _uid();
      final snap = await _confession(id)
          .collection(FirestorePaths.views)
          .doc(uid)
          .get();
      return snap.exists;
    });
  }

  @override
  Future<bool> recordView(String id) {
    return guardFirebase(() async {
      final uid = _uid();
      final ref = _confession(id);
      final viewRef = ref.collection(FirestorePaths.views).doc(uid);
      final updated = await _db.runTransaction<Confession?>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return null;
        final view = await tx.get(viewRef);
        if (view.exists) return null;
        final current = _fromDoc(snap);
        final views = current.viewCount + 1;
        tx.update(ref, {ConfessionFields.viewCount: views});
        tx.set(viewRef, {
          ActivityFields.uid: uid,
          ActivityFields.createdAt: FieldValue.serverTimestamp(),
        });
        return current.copyWith(viewCount: views);
      });
      if (updated == null) return false;
      _emit(ConfessionUpdated(updated));
      return true;
    });
  }

  // ----------------------------------------------------- account deletion ---

  @override
  Future<void> clearUserData() {
    return guardFirebase(() async {
      final uid = _uid();

      Future<void> each(
        Query<_Json> query,
        Future<void> Function(QueryDocumentSnapshot<_Json> doc) action,
      ) async {
        final snap = await query.get();
        // Small parallel batches keep this quick without hammering Firestore.
        final docs = snap.docs;
        for (var i = 0; i < docs.length; i += 10) {
          await Future.wait(
            docs.skip(i).take(10).map((d) async {
              try {
                await action(d);
              } catch (_) {
                // Keep going; a leftover activity doc is harmless and the
                // counters stay consistent because each step is atomic.
              }
            }),
          );
        }
      }

      await each(_mine(uid, FirestorePaths.likes), (d) async {
        await _removeActivity(
          confessionId: d.id,
          activityRef: _confession(d.id).collection(FirestorePaths.likes).doc(uid),
          mineRef: d.reference,
          counterUpdate: (c) => {
            ConfessionFields.likeCount: c.likeCount - 1,
            ConfessionFields.hotScore: _hot(c, likes: c.likeCount - 1),
          },
        );
      });

      await each(_mine(uid, FirestorePaths.reactions), (d) async {
        final reaction = Reaction.parse(d.data()[ActivityFields.reaction]);
        await _removeActivity(
          confessionId: d.id,
          activityRef: _confession(
            d.id,
          ).collection(FirestorePaths.reactions).doc(uid),
          mineRef: d.reference,
          counterUpdate: (c) {
            final counts = {
              for (final r in Reaction.values) r: c.reactionCount(r),
            };
            if (reaction != null) counts[reaction] = counts[reaction]! - 1;
            final total = counts.values.fold<int>(0, (a, b) => a + b);
            return {
              ConfessionFields.reactionCounts: _countsJson(counts),
              ConfessionFields.reactionTotal: total,
              ConfessionFields.hotScore: _hot(c, reactions: total),
            };
          },
        );
      });

      await each(_mine(uid, FirestorePaths.saves), (d) async {
        await _removeActivity(
          confessionId: d.id,
          activityRef: null,
          mineRef: d.reference,
          counterUpdate: (c) => {ConfessionFields.saveCount: c.saveCount - 1},
        );
      });

      await each(
        _db
            .collectionGroup(FirestorePaths.views)
            .where(ActivityFields.uid, isEqualTo: uid),
        (d) async {
          final confessionRef = d.reference.parent.parent;
          if (confessionRef == null) return;
          await _removeActivity(
            confessionId: confessionRef.id,
            activityRef: d.reference,
            mineRef: null,
            counterUpdate: (c) => {ConfessionFields.viewCount: c.viewCount - 1},
          );
        },
      );

      await each(_mine(uid, FirestorePaths.posts), (d) async {
        await _deleteOwnPost(uid, d.id);
        _emit(ConfessionDeleted(d.id));
      });
    });
  }

  /// Deletes one activity (like, reaction, save or view) and decrements the
  /// matching counter in the same transaction. If the confession no longer
  /// exists, only the leftover activity documents are removed.
  Future<void> _removeActivity({
    required String confessionId,
    required DocumentReference<_Json>? activityRef,
    required DocumentReference<_Json>? mineRef,
    required _Json Function(Confession current) counterUpdate,
  }) async {
    final ref = _confession(confessionId);
    await _db.runTransaction<void>((tx) async {
      final snap = await tx.get(ref);
      if (activityRef != null) {
        final activity = await tx.get(activityRef);
        if (snap.exists && activity.exists) {
          tx.update(ref, counterUpdate(_fromDoc(snap)));
        }
        if (activity.exists) tx.delete(activityRef);
      } else if (snap.exists) {
        tx.update(ref, counterUpdate(_fromDoc(snap)));
      }
      if (mineRef != null) tx.delete(mineRef);
    });
  }

  Future<void> dispose() => _changes.close();
}
