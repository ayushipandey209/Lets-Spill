import 'dart:math';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:let_s_spill/app/init/app_init_cubit.dart';
import '../fakes/local_content_store.dart';
import 'package:let_s_spill/core/errors/app_exception.dart';
import 'package:let_s_spill/core/utils/ui_notice.dart';
import 'package:let_s_spill/features/auth/presentation/session_cubit.dart';
import '../fakes/local_confession_repository.dart';
import 'package:let_s_spill/features/confessions/domain/confession.dart';
import 'package:let_s_spill/features/create_confession/presentation/bloc/create_confession_cubit.dart';
import 'package:let_s_spill/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:let_s_spill/features/onboarding/domain/username_generator.dart';
import 'package:let_s_spill/features/onboarding/presentation/bloc/onboarding_cubit.dart';
import 'package:let_s_spill/features/profile/domain/user_profile.dart';
import 'package:let_s_spill/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:let_s_spill/features/settings/presentation/bloc/account_deletion_cubit.dart';

import '../helpers.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  group('SessionCubit', () {
    test('signed out, Google, needs onboarding, ready', () async {
      final auth = FakeAuthRepository();
      final profiles = FakeProfileRepository(auth);
      final cubit = SessionCubit(auth: auth, profiles: profiles);
      await settle();
      expect(cubit.state.status, SessionStatus.signedOut);

      await auth.signInWithGoogle();
      await settle();
      expect(cubit.state.status, SessionStatus.needsOnboarding);
      expect(cubit.state.user, testUser);

      final profile = await profiles.completeOnboarding(
        const OnboardingChoices(
          username: 'QuietComet27',
          ageRange: AgeRange.young,
          preferredCategoryIds: ['life'],
        ),
      );
      cubit.onboardingCompleted(profile);
      expect(cubit.state.status, SessionStatus.ready);

      await cubit.signOut();
      await settle();
      expect(cubit.state.status, SessionStatus.signedOut);
      await cubit.close();
    });

    test('returning users with a profile go straight to ready', () async {
      final auth = FakeAuthRepository(signedIn: testUser);
      final profiles = FakeProfileRepository(auth)
        ..profiles[testUser.uid] = adultProfile();
      final cubit = SessionCubit(auth: auth, profiles: profiles);
      await settle();
      expect(cubit.state.status, SessionStatus.ready);
      expect(cubit.state.profile!.username, 'QuietComet27');
      await cubit.close();
    });
  });

  group('OnboardingCubit (tap-only)', () {
    late FakeAuthRepository auth;
    late FakeProfileRepository profiles;

    setUp(() {
      auth = FakeAuthRepository(signedIn: testUser);
      profiles = FakeProfileRepository(auth);
    });

    OnboardingCubit build({Set<String> taken = const {}}) => OnboardingCubit(
      profiles: FakeProfileRepository(auth, takenUsernames: taken),
      generator: UsernameGenerator(Random(1)),
    );

    test('offers generated names and cannot advance without a choice', () async {
      final cubit = OnboardingCubit(
        profiles: profiles,
        generator: UsernameGenerator(Random(1)),
      );
      expect(cubit.state.usernameOptions, hasLength(6));
      expect(cubit.state.canContinue, isFalse);
      await cubit.next();
      expect(cubit.state.step, OnboardingStep.username);

      cubit.selectUsername('NotAnOption99'); // Can't inject a typed name.
      expect(cubit.state.username, isNull);

      final first = cubit.state.usernameOptions.first;
      cubit.shuffleUsernames();
      expect(cubit.state.usernameOptions, isNot(contains(first)));
      await cubit.close();
    });

    test('full flow saves username, interests and age', () async {
      final cubit = OnboardingCubit(
        profiles: profiles,
        generator: UsernameGenerator(Random(1)),
      );
      final name = cubit.state.usernameOptions[2];
      cubit.selectUsername(name);
      await cubit.next();
      expect(cubit.state.step, OnboardingStep.interests);

      expect(cubit.state.canContinue, isFalse);
      cubit
        ..toggleCategory('school')
        ..toggleCategory('life')
        ..toggleCategory('school');
      expect(cubit.state.categoryIds, ['life']);
      await cubit.next();
      expect(cubit.state.step, OnboardingStep.age);

      cubit.selectAge(AgeRange.teen);
      await cubit.next();
      expect(cubit.state.status, SubmitStatus.success);
      final saved = profiles.profiles[testUser.uid]!;
      expect(saved.username, name);
      expect(saved.ageRange, AgeRange.teen);
      expect(saved.preferredCategoryIds, ['life']);
      expect(saved.canSeeMature, isFalse);
      await cubit.close();
    });

    test('a taken name reshuffles and stays on the username step', () async {
      final probe = OnboardingCubit(
        profiles: profiles,
        generator: UsernameGenerator(Random(1)),
      );
      final taken = probe.state.usernameOptions.first;
      await probe.close();

      final cubit = build(taken: {taken});
      cubit.selectUsername(taken);
      await cubit.next();
      expect(cubit.state.step, OnboardingStep.username);
      expect(cubit.state.username, isNull);
      expect(cubit.state.errorMessage, contains('taken'));
      await cubit.close();
    });

    test('back moves to the previous step', () async {
      final cubit = build();
      cubit.selectUsername(cubit.state.usernameOptions.first);
      await cubit.next();
      cubit.back();
      expect(cubit.state.step, OnboardingStep.username);
      await cubit.close();
    });
  });

  group('FeedBloc', () {
    late LocalContentStore store;
    late LocalConfessionRepository repo;

    setUp(() async {
      store = await createStore();
      repo = confessionRepo(store);
    });

    blocTest<FeedBloc, FeedState>(
      'For you shows preferred categories plus a featured confession',
      build: () => FeedBloc(
        repository: repo,
        pageSize: 10,
        preferences: const FeedPreferences(
          preferredCategoryIds: ['family', 'school'],
        ),
      ),
      act: (bloc) => bloc.add(const FeedStarted()),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.status, FeedStatus.success);
        expect(bloc.state.tab, FeedTab.forYou);
        expect(
          bloc.state.items.every(
            (c) => c.categoryId == 'family' || c.categoryId == 'school',
          ),
          isTrue,
        );
        expect(bloc.state.featured, isNotNull);
      },
    );

    blocTest<FeedBloc, FeedState>(
      'Latest shows everything; teens never see mature posts',
      build: () => FeedBloc(
        repository: repo,
        pageSize: 50,
        preferences: const FeedPreferences(includeMature: false),
      ),
      act: (bloc) async {
        bloc.add(const FeedStarted());
        await settle();
        bloc.add(const FeedTabSelected(FeedTab.latest));
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(bloc.state.tab, FeedTab.latest);
        expect(bloc.state.items, hasLength(seedConfessionCount - seedMatureCount));
        expect(bloc.state.items.any((c) => c.mature), isFalse);
        expect(bloc.state.featured?.mature ?? false, isFalse);
      },
    );

    blocTest<FeedBloc, FeedState>(
      'Hot tab + category filter',
      build: () => FeedBloc(repository: repo, pageSize: 50),
      act: (bloc) async {
        bloc.add(const FeedStarted());
        await settle();
        bloc.add(const FeedTabSelected(FeedTab.hot));
        await settle();
        bloc.add(const FeedCategorySelected('workplace'));
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(bloc.state.tab, FeedTab.hot);
        expect(bloc.state.items, isNotEmpty);
        expect(bloc.state.items.every((c) => c.categoryId == 'workplace'), isTrue);
      },
    );

    blocTest<FeedBloc, FeedState>(
      'save toggles are reflected immediately and persisted',
      build: () => FeedBloc(repository: repo, pageSize: 10),
      act: (bloc) async {
        bloc.add(const FeedStarted());
        await settle();
        bloc.add(FeedSaveToggled(bloc.state.items.first.id));
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        final id = bloc.state.items.first.id;
        expect(bloc.state.savedIds, contains(id));
        expect(store.activity[testUser.uid]!.saved, contains(id));
      },
    );

    blocTest<FeedBloc, FeedState>(
      'loads more pages without duplicates',
      build: () => FeedBloc(repository: repo, pageSize: 10),
      act: (bloc) async {
        bloc.add(const FeedTabSelected(FeedTab.latest));
        await settle();
        bloc.add(const FeedLoadMoreRequested());
        await settle();
        bloc.add(const FeedLoadMoreRequested());
        await settle();
        bloc.add(const FeedLoadMoreRequested());
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(bloc.state.items.map((c) => c.id).toSet(), hasLength(seedConfessionCount));
        expect(bloc.state.hasMore, isFalse);
      },
    );
  });

  group('CreateConfessionCubit', () {
    test('validates, posts once, and can use the anonymous handle', () async {
      final store = await createStore();
      final repo = confessionRepo(store);
      final cubit = CreateConfessionCubit(
        repository: repo,
        maxLength: 2000,
        minLength: 10,
        handle: '@QuietComet27',
      );
      await cubit.submit();
      expect(cubit.state.textError, isNotNull);
      expect(cubit.state.categoryError, isNotNull);

      cubit
        ..categorySelected('workplace')
        ..textChanged('I finally asked for the raise and got it.')
        ..setPostAsHandle(true);
      await Future.wait([cubit.submit(), cubit.submit(), cubit.submit()]);
      expect(cubit.state.status, SubmitStatus.success);
      expect(cubit.state.created!.authorDisplayName, '@QuietComet27');
      expect(store.confessions, hasLength(seedConfessionCount + 1));
      await cubit.close();
    });
  });

  group('ProfileCubit', () {
    test('lists own, saved and liked posts, and deletes your own', () async {
      final repo = confessionRepo(await createStore());
      await repo.setSaved('conf-004', saved: true);
      await repo.setLiked('conf-001', liked: true);
      final mine = await repo.create(
        text: 'My own little secret, here.',
        categoryId: 'life',
        displayName: Confession.anonymousName,
      );
      final cubit = ProfileCubit(
        profile: adultProfile(),
        confessionRepository: repo,
      );
      await cubit.load();
      expect(cubit.state.myConfessions.map((c) => c.id), [mine.id]);
      expect(cubit.state.saved.map((c) => c.id), ['conf-004']);
      expect(cubit.state.liked.map((c) => c.id), ['conf-001']);

      cubit.selectSection(ProfileSection.liked);
      expect(cubit.state.current.map((c) => c.id), ['conf-001']);

      await cubit.deleteConfession(mine.id);
      expect(cubit.state.myConfessions, isEmpty);
      await cubit.close();
    });
  });

  group('AccountDeletionCubit', () {
    test('re-authenticates, deletes activity, profile and the account', () async {
      final auth = FakeAuthRepository(signedIn: testUser);
      final profiles = FakeProfileRepository(auth)
        ..profiles[testUser.uid] = adultProfile()
        ..claims['quietcomet27'] = testUser.uid;
      final store = await createStore(uid: () => auth.currentUser?.uid);
      final repo = confessionRepo(store);
      await repo.setLiked('conf-001', liked: true);

      final cubit = AccountDeletionCubit(
        auth: auth,
        profiles: profiles,
        confessions: repo,
      );
      await cubit.deleteAccount(); // Not confirmed yet, so ignored.
      expect(auth.reauthCount, 0);

      cubit.setConfirmed(true);
      await cubit.deleteAccount();
      expect(cubit.state.status, SubmitStatus.success);
      expect(auth.reauthCount, 1);
      expect(auth.deleted, isTrue);
      expect(profiles.profiles, isEmpty);
      expect(profiles.claims, isEmpty);
      expect(store.activity.containsKey(testUser.uid), isFalse);
      await cubit.close();
    });
  });

  group('AppInitCubit', () {
    test('ready with injected services', () async {
      final harness = TestHarness(signedIn: true, profile: adultProfile());
      final cubit = AppInitCubit(
        config: testConfig,
        createServices: harness.create,
        minimumSplash: Duration.zero,
      );
      await cubit.initialize();
      expect(cubit.state.status, AppInitStatus.ready);
      await cubit.close();
    });

    test('surfaces Firebase setup steps when not configured', () async {
      final cubit = AppInitCubit(
        config: testConfig,
        createServices: (_) async => throw const ConfigurationException(
          'Not connected to Firebase.',
          setupSteps: ['Run flutterfire configure'],
        ),
        minimumSplash: Duration.zero,
      );
      await cubit.initialize();
      expect(cubit.state.status, AppInitStatus.failure);
      expect(cubit.state.setupSteps, isNotEmpty);
      await cubit.close();
    });
  });
}
