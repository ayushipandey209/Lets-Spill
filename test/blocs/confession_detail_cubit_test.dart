import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import '../fakes/local_content_store.dart';
import 'package:let_s_spill/core/errors/app_exception.dart';
import 'package:let_s_spill/features/confession_detail/presentation/bloc/confession_detail_cubit.dart';
import 'package:let_s_spill/features/confessions/domain/confession.dart';
import 'package:let_s_spill/features/confessions/domain/confession_repository.dart';

import '../helpers.dart';

/// Delegating repository that counts writes and can be told to fail likes.
class SpyConfessionRepository implements ConfessionRepository {
  SpyConfessionRepository(this.inner);

  final ConfessionRepository inner;
  int recordViewCalls = 0;
  int setLikedCalls = 0;
  bool failLikes = false;

  @override
  Stream<ConfessionChange> get changes => inner.changes;

  @override
  Future<Confession> create({
    required String text,
    required String categoryId,
    required String displayName,
    bool mature = false,
  }) => inner.create(
    text: text,
    categoryId: categoryId,
    displayName: displayName,
    mature: mature,
  );

  @override
  Future<void> delete(String id) => inner.delete(id);

  @override
  Future<Confession> fetchById(String id) => inner.fetchById(id);

  @override
  Future<List<Confession>> fetchMine() => inner.fetchMine();

  @override
  Future<ConfessionPage> fetchPage(
    FeedQuery query, {
    Object? cursor,
    required int limit,
  }) => inner.fetchPage(query, cursor: cursor, limit: limit);

  @override
  Future<Confession?> confessionOfTheDay({
    Set<String>? preferredCategoryIds,
    required bool includeMature,
  }) => inner.confessionOfTheDay(
    preferredCategoryIds: preferredCategoryIds,
    includeMature: includeMature,
  );

  @override
  Future<bool> hasViewed(String id) => inner.hasViewed(id);

  @override
  Future<bool> isLiked(String id) => inner.isLiked(id);

  @override
  Future<Set<String>> likedIds(Iterable<String> ids) => inner.likedIds(ids);

  @override
  Future<List<Confession>> fetchLiked() => inner.fetchLiked();

  @override
  Future<Reaction?> myReaction(String id) => inner.myReaction(id);

  @override
  Future<Confession> setReaction(String id, Reaction? reaction) =>
      inner.setReaction(id, reaction);

  @override
  Future<bool> isSaved(String id) => inner.isSaved(id);

  @override
  Future<void> setSaved(String id, {required bool saved}) =>
      inner.setSaved(id, saved: saved);

  @override
  Future<Set<String>> savedIds() => inner.savedIds();

  @override
  Future<List<Confession>> fetchSaved() => inner.fetchSaved();

  @override
  Future<void> clearUserData() => inner.clearUserData();

  @override
  Future<bool> recordView(String id) {
    recordViewCalls++;
    return inner.recordView(id);
  }

  @override
  Future<Confession> setLiked(String id, {required bool liked}) async {
    setLikedCalls++;
    if (failLikes) throw const NetworkException();
    return inner.setLiked(id, liked: liked);
  }
}

const _id = 'conf-002';
const _threshold = Duration(seconds: 15);

void main() {
  late LocalContentStore db;
  late SpyConfessionRepository repo;

  /// Builds the fixture inside the current fake-async zone.
  ConfessionDetailCubit setUpCubit(FakeAsync async) {
    createStore().then((value) => db = value);
    async.flushMicrotasks();
    repo = SpyConfessionRepository(confessionRepo(db));
    final cubit = ConfessionDetailCubit(
      repository: repo,
      shareService: FakeShareService(),
      confessionId: _id,
      viewThreshold: _threshold,
    );
    cubit.load();
    async.flushMicrotasks();
    return cubit;
  }

  int storedViews() => db.find(_id)!.viewCount;

  group('15-second qualified view', () {
    test('is not counted before 15 seconds', () {
      fakeAsync((async) {
        final cubit = setUpCubit(async);
        final before = storedViews();
        cubit.onVisible();
        expect(cubit.state.viewStatus, ViewTrackingStatus.pending);

        async.elapse(const Duration(seconds: 14, milliseconds: 999));
        expect(repo.recordViewCalls, 0);
        expect(storedViews(), before);
        expect(cubit.state.viewStatus, ViewTrackingStatus.pending);
        cubit.close();
        async.flushMicrotasks();
      });
    });

    test('is counted exactly once at 15 seconds', () {
      fakeAsync((async) {
        final cubit = setUpCubit(async);
        final before = storedViews();
        cubit.onVisible();
        async.elapse(_threshold);
        async.flushMicrotasks();

        expect(repo.recordViewCalls, 1);
        expect(storedViews(), before + 1);
        expect(cubit.state.viewStatus, ViewTrackingStatus.counted);
        expect(cubit.state.confession!.viewCount, before + 1);

        // Staying longer, or hiding and showing again, never writes again.
        async.elapse(const Duration(minutes: 5));
        cubit
          ..onHidden()
          ..onVisible();
        async.elapse(const Duration(minutes: 1));
        expect(repo.recordViewCalls, 1);
        expect(cubit.isViewTimerActive, isFalse);
        cubit.close();
        async.flushMicrotasks();
      });
    });

    test('is cancelled when the reader leaves early', () {
      fakeAsync((async) {
        final cubit = setUpCubit(async);
        final before = storedViews();
        cubit.onVisible();
        async.elapse(const Duration(seconds: 10));
        cubit.close(); // Route popped.
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 30));

        expect(repo.recordViewCalls, 0);
        expect(storedViews(), before);
      });
    });

    test('restarts from zero after backgrounding (continuous dwell)', () {
      fakeAsync((async) {
        final cubit = setUpCubit(async);
        cubit.onVisible();
        async.elapse(const Duration(seconds: 10));
        cubit.onHidden(); // App backgrounded.
        expect(cubit.state.viewStatus, ViewTrackingStatus.idle);
        expect(cubit.isViewTimerActive, isFalse);
        async.elapse(const Duration(seconds: 30));
        expect(repo.recordViewCalls, 0);

        cubit.onVisible(); // Resumed: needs a fresh 15 s.
        async.elapse(const Duration(seconds: 14));
        expect(repo.recordViewCalls, 0);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(repo.recordViewCalls, 1);
        cubit.close();
        async.flushMicrotasks();
      });
    });

    test('is not counted twice for the same reader across visits', () {
      fakeAsync((async) {
        final first = setUpCubit(async);
        final before = storedViews();
        first.onVisible();
        async.elapse(_threshold);
        async.flushMicrotasks();
        first.close();
        async.flushMicrotasks();
        expect(storedViews(), before + 1);

        // Second visit by the same reader.
        final second = ConfessionDetailCubit(
          repository: repo,
          shareService: FakeShareService(),
          confessionId: _id,
          viewThreshold: _threshold,
        );
        second.load();
        async.flushMicrotasks();
        expect(second.state.viewStatus, ViewTrackingStatus.alreadyCounted);
        second.onVisible();
        expect(second.isViewTimerActive, isFalse);
        async.elapse(const Duration(seconds: 20));
        async.flushMicrotasks();
        expect(repo.recordViewCalls, 1);
        expect(storedViews(), before + 1);
        second.close();
        async.flushMicrotasks();
      });
    });

    test('does not start before the confession has loaded', () {
      fakeAsync((async) {
        createStore().then((value) => db = value);
        async.flushMicrotasks();
        repo = SpyConfessionRepository(confessionRepo(db));
        final cubit = ConfessionDetailCubit(
          repository: repo,
          shareService: FakeShareService(),
          confessionId: _id,
          viewThreshold: _threshold,
        );
        cubit.onVisible();
        expect(cubit.isViewTimerActive, isFalse);
        cubit.load();
        async.flushMicrotasks();
        expect(cubit.isViewTimerActive, isTrue);
        cubit.close();
        async.flushMicrotasks();
      });
    });
  });

  group('likes and share', () {
    test('toggle like optimistically and persist', () {
      fakeAsync((async) {
        final cubit = setUpCubit(async);
        final before = cubit.state.confession!.likeCount;
        cubit.toggleLike();
        expect(cubit.state.isLiked, isTrue);
        expect(cubit.state.confession!.likeCount, before + 1);
        // A second tap while in flight is ignored.
        cubit.toggleLike();
        async.flushMicrotasks();
        expect(repo.setLikedCalls, 1);
        expect(db.find(_id)!.likeCount, before + 1);

        cubit.toggleLike();
        async.flushMicrotasks();
        expect(cubit.state.isLiked, isFalse);
        expect(db.find(_id)!.likeCount, before);
        cubit.close();
        async.flushMicrotasks();
      });
    });

    test('reverts the optimistic like on failure', () {
      fakeAsync((async) {
        final cubit = setUpCubit(async);
        final before = cubit.state.confession!.likeCount;
        repo.failLikes = true;
        cubit.toggleLike();
        async.flushMicrotasks();
        expect(cubit.state.isLiked, isFalse);
        expect(cubit.state.confession!.likeCount, before);
        expect(cubit.state.notice?.isError, isTrue);
        cubit.close();
        async.flushMicrotasks();
      });
    });

    test('react picks one reaction; tapping it again removes it', () {
      fakeAsync((async) {
        final cubit = setUpCubit(async);
        final before = cubit.state.confession!.reactionCount(Reaction.same);
        cubit.react(Reaction.same);
        async.flushMicrotasks();
        expect(cubit.state.reaction, Reaction.same);
        expect(cubit.state.confession!.reactionCount(Reaction.same), before + 1);
        cubit.react(Reaction.same);
        async.flushMicrotasks();
        expect(cubit.state.reaction, isNull);
        expect(cubit.state.confession!.reactionCount(Reaction.same), before);
        cubit.close();
        async.flushMicrotasks();
      });
    });

    test('toggleSaved saves and unsaves', () {
      fakeAsync((async) {
        final cubit = setUpCubit(async);
        expect(cubit.state.isSaved, isFalse);
        cubit.toggleSaved();
        async.flushMicrotasks();
        expect(cubit.state.isSaved, isTrue);
        expect(db.activity[testUser.uid]!.saved, contains(_id));
        cubit.toggleSaved();
        async.flushMicrotasks();
        expect(cubit.state.isSaved, isFalse);
        cubit.close();
        async.flushMicrotasks();
      });
    });

    test('shares only the text plus a generic attribution', () async {
      final share = FakeShareService();
      db = await createStore();
      final cubit = ConfessionDetailCubit(
        repository: confessionRepo(db),
        shareService: share,
        confessionId: _id,
      );
      await cubit.load();
      await cubit.share();
      expect(share.shared, hasLength(1));
      expect(share.shared.single, contains(cubit.state.confession!.text));
      expect(share.shared.single, contains("Let's Spill"));
      expect(share.shared.single, isNot(contains('http')));
      await cubit.close();
    });
  });
}
