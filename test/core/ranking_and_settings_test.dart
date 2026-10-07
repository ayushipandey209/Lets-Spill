import 'package:flutter_test/flutter_test.dart';
import 'package:let_s_spill/core/data/key_value_store.dart';
import 'package:let_s_spill/features/confessions/domain/ranking.dart';
import 'package:let_s_spill/features/settings/domain/app_settings.dart';
import 'package:let_s_spill/features/settings/presentation/settings_cubit.dart';

void main() {
  group('Ranking.hotScore', () {
    final t0 = DateTime.utc(2026, 10, 1);

    test('newer posts rank higher at equal engagement', () {
      final older = Ranking.hotScore(createdAt: t0, likes: 10, reactions: 0);
      final newer = Ranking.hotScore(
        createdAt: t0.add(const Duration(hours: 1)),
        likes: 10,
        reactions: 0,
      );
      expect(newer, greaterThan(older));
    });

    test('10x engagement is worth 12.5 hours', () {
      final a = Ranking.hotScore(createdAt: t0, likes: 100, reactions: 0);
      final b = Ranking.hotScore(
        createdAt: t0.add(const Duration(seconds: Ranking.decaySeconds)),
        likes: 10,
        reactions: 0,
      );
      expect((a - b).abs(), lessThan(1e-6));
    });

    test('one more like moves the score by at most log10(2)', () {
      for (final n in [0, 1, 2, 5, 50, 999]) {
        final before = Ranking.hotScore(createdAt: t0, likes: n, reactions: 0);
        final after = Ranking.hotScore(createdAt: t0, likes: n + 1, reactions: 0);
        // Must stay within the bound checked by firestore.rules.
        expect(after - before, inInclusiveRange(0, 0.31));
      }
    });
  });

  group('SearchTokens', () {
    test('lower-cases, de-duplicates and drops short words', () {
      final tokens = SearchTokens.fromText(
        "I told my Boss. My boss didn't care, a b",
        categoryId: 'workplace',
      );
      expect(tokens, containsAll(['told', 'boss', 'didnt', 'care', 'workplace']));
      expect(tokens.where((t) => t == 'boss'), hasLength(1));
      expect(tokens, isNot(contains('a')));
    });

    test('caps the number of tokens', () {
      final text = List.generate(200, (i) => 'word$i').join(' ');
      expect(SearchTokens.fromText(text), hasLength(SearchTokens.maxTokens));
    });

    test('queries are normalised the same way', () {
      expect(SearchTokens.fromQuery("Didn't  BOSS"), ['didnt', 'boss']);
    });
  });

  group('AppSettings', () {
    test('round-trips through JSON', () {
      const s = AppSettings(
        theme: AppThemePreference.dark,
        textSize: TextSizePreference.small,
        feedLayout: FeedLayout.compact,
        defaultFeed: DefaultFeed.top,
        showMature: false,
        blurMature: false,
        postIdentity: PostIdentity.handle,
        mutedCategoryIds: ['school'],
        showConfessionOfDay: false,
        haptics: false,
        reduceMotion: true,
        analyticsEnabled: false,
      );
      expect(AppSettings.fromJson(s.toJson()), s);
    });

    test('unknown or missing values fall back to defaults', () {
      final s = AppSettings.fromJson({'theme': 'purple', 'haptics': 'yes'});
      expect(s, const AppSettings());
      expect(AppSettings.fromJson(null), const AppSettings());
    });

    test('SettingsCubit persists and reloads', () async {
      final store = InMemoryKeyValueStore();
      final cubit = SettingsCubit(store: store);
      AppSettings? pushed;
      cubit.remoteSaver = (s) async => pushed = s;
      await cubit.update(
        const AppSettings(theme: AppThemePreference.dark),
      );
      expect(pushed?.theme, AppThemePreference.dark);
      await cubit.close();

      final reloaded = SettingsCubit(store: store);
      await reloaded.load();
      expect(reloaded.state.theme, AppThemePreference.dark);
      await reloaded.close();
    });
  });
}
