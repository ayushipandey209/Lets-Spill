import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:let_s_spill/core/data/key_value_store.dart';
import 'package:let_s_spill/core/errors/app_exception.dart';
import 'package:let_s_spill/features/confessions/domain/confession.dart';

import '../helpers.dart';

void main() {
  test('seed JSON is valid, fictional and author-free', () {
    final confessions =
        (jsonDecode(File('assets/mock/confessions.json').readAsStringSync())
                as Map<String, dynamic>)['confessions']
            as List<dynamic>;
    final categories =
        ((jsonDecode(File('assets/mock/categories.json').readAsStringSync())
                    as Map<String, dynamic>)['categories']
                as List<dynamic>)
            .map((c) => (c as Map<String, dynamic>)['id'])
            .toSet();
    expect(confessions.length, seedConfessionCount);
    expect(File('assets/mock/users.json').existsSync(), isFalse);
    final ids = <String>{};
    for (final raw in confessions.cast<Map<String, dynamic>>()) {
      expect(ids.add(raw['id'] as String), isTrue);
      expect(categories, contains(raw['categoryId']));
      expect(raw.keys, isNot(contains('authorUid')));
      expect(raw.keys, isNot(contains('email')));
      final c = Confession.fromJson(raw);
      expect(c.totalReactions, greaterThanOrEqualTo(0));
    }
    expect(
      confessions.where((c) => (c as Map<String, dynamic>)['mature'] == true),
      hasLength(seedMatureCount),
    );
  });

  group('LocalConfessionRepository', () {
    test('paginates newest-first without loading everything', () async {
      final repo = confessionRepo(await createStore());
      final first = await repo.fetchPage(const FeedQuery(), limit: 10);
      expect(first.items, hasLength(10));
      expect(first.hasMore, isTrue);
      final second = await repo.fetchPage(
        const FeedQuery(),
        limit: 10,
        cursor: first.cursor,
      );
      final third = await repo.fetchPage(
        const FeedQuery(),
        limit: 10,
        cursor: second.cursor,
      );
      final all = [...first.items, ...second.items, ...third.items];
      expect(all.map((c) => c.id).toSet(), hasLength(seedConfessionCount));
      expect(third.hasMore, isFalse);
    });

    test('hides mature confessions from readers under 18', () async {
      final repo = confessionRepo(await createStore());
      final teen = await repo.fetchPage(
        const FeedQuery(includeMature: false),
        limit: 100,
      );
      expect(teen.items.any((c) => c.mature), isFalse);
      expect(teen.items, hasLength(seedConfessionCount - seedMatureCount));
    });

    test('filters by categories and searches by keyword', () async {
      final repo = confessionRepo(await createStore());
      final school = await repo.fetchPage(
        const FeedQuery(categoryIds: {'school'}),
        limit: 100,
      );
      expect(school.items.every((c) => c.categoryId == 'school'), isTrue);

      final hits = await repo.fetchPage(
        const FeedQuery(search: 'Grandmother'),
        limit: 100,
      );
      expect(hits.items, hasLength(1));
      expect(hits.items.single.text, contains('grandmother'));
    });

    test('trending ranks by engagement and recency', () async {
      final repo = confessionRepo(await createStore());
      final page = await repo.fetchPage(
        const FeedQuery(sort: FeedSort.trending),
        limit: 100,
      );
      for (var i = 1; i < page.items.length; i++) {
        expect(
          repo.trendingScore(page.items[i - 1]),
          greaterThanOrEqualTo(repo.trendingScore(page.items[i])),
        );
      }
    });

    test('confession of the day is stable and respects age', () async {
      final repo = confessionRepo(await createStore());
      final a = await repo.confessionOfTheDay(includeMature: false);
      final b = await repo.confessionOfTheDay(includeMature: false);
      expect(a, isNotNull);
      expect(a!.id, b!.id);
      expect(a.mature, isFalse);
      final picked = await repo.confessionOfTheDay(
        preferredCategoryIds: {'family'},
        includeMature: true,
      );
      expect(picked!.categoryId, 'family');
    });

    test('likes, reactions and saves are idempotent and per user', () async {
      var uid = 'uid-alice';
      final store = await createStore(uid: () => uid);
      final repo = confessionRepo(store);
      final before = await repo.fetchById('conf-001');

      await repo.setLiked('conf-001', liked: true);
      await repo.setLiked('conf-001', liked: true);
      expect((await repo.fetchById('conf-001')).likeCount, before.likeCount + 1);

      await repo.setReaction('conf-001', Reaction.hugs);
      await repo.setReaction('conf-001', Reaction.wow); // replaces hugs
      final reacted = await repo.fetchById('conf-001');
      expect(reacted.reactionCount(Reaction.hugs), before.reactionCount(Reaction.hugs));
      expect(reacted.reactionCount(Reaction.wow), before.reactionCount(Reaction.wow) + 1);
      expect(await repo.myReaction('conf-001'), Reaction.wow);

      await repo.setSaved('conf-001', saved: true);
      await repo.setSaved('conf-005', saved: true);
      expect((await repo.fetchSaved()).map((c) => c.id), ['conf-005', 'conf-001']);

      uid = 'uid-bob';
      expect(await repo.isLiked('conf-001'), isFalse);
      expect(await repo.myReaction('conf-001'), isNull);
      expect(await repo.fetchSaved(), isEmpty);
    });

    test('records a view once per user', () async {
      final repo = confessionRepo(await createStore());
      final before = await repo.fetchById('conf-002');
      expect(await repo.recordView('conf-002'), isTrue);
      expect(await repo.recordView('conf-002'), isFalse);
      expect((await repo.fetchById('conf-002')).viewCount, before.viewCount + 1);
    });

    test('creates as Anonymous or @handle, deletes only own posts', () async {
      final repo = confessionRepo(await createStore());
      final anon = await repo.create(
        text: 'A brand new secret for testing.',
        categoryId: 'life',
        displayName: Confession.anonymousName,
      );
      final named = await repo.create(
        text: 'Another one, posted with my handle.',
        categoryId: 'school',
        displayName: '@QuietComet27',
      );
      final sneaky = await repo.create(
        text: 'Trying to post with a real name here.',
        categoryId: 'life',
        displayName: 'Alice Example',
      );
      expect(anon.authorDisplayName, 'Anonymous');
      expect(named.authorDisplayName, '@QuietComet27');
      expect(sneaky.authorDisplayName, 'Anonymous');
      expect((await repo.fetchMine()), hasLength(3));

      await expectLater(
        repo.delete('conf-001'),
        throwsA(isA<PermissionException>()),
      );
      await repo.delete(anon.id);
      await expectLater(
        repo.fetchById(anon.id),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('requires a signed-in user for activity', () async {
      final repo = confessionRepo(await createStore(uid: () => null));
      await expectLater(
        repo.setLiked('conf-001', liked: true),
        throwsA(isA<AuthException>()),
      );
    });

    test('persists per-user activity and can clear it', () async {
      final kv = InMemoryKeyValueStore();
      final repo = confessionRepo(await createStore(store: kv));
      final before = (await repo.fetchById('conf-003')).likeCount;
      await repo.setLiked('conf-003', liked: true);
      await repo.create(
        text: 'Something only I wrote here.',
        categoryId: 'life',
        displayName: 'Anonymous',
      );

      final reloaded = confessionRepo(await createStore(store: kv));
      expect(await reloaded.isLiked('conf-003'), isTrue);
      expect(await reloaded.fetchMine(), hasLength(1));

      await reloaded.clearUserData();
      expect(await reloaded.isLiked('conf-003'), isFalse);
      expect(await reloaded.fetchMine(), isEmpty);
      expect((await reloaded.fetchById('conf-003')).likeCount, before);
    });
  });
}
