import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:let_s_spill/app/app.dart';
import 'package:let_s_spill/features/confessions/presentation/confession_widgets.dart';
import 'package:let_s_spill/features/onboarding/presentation/pages/onboarding_page.dart';

import 'helpers.dart';

/// End-to-end widget tests with fake Google auth, an in-memory profile and
/// confession store, and the bundled sample content.
void main() {
  Future<TestHarness> boot(
    WidgetTester tester,
    TestHarness harness, {
    Size size = const Size(400, 860),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      LetsSpillApp(
        config: testConfig,
        createServices: harness.create,
        minimumSplash: Duration.zero,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    return harness;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('signed out: intro, Google, tap-only onboarding, home', (
    tester,
  ) async {
    final harness = await boot(tester, TestHarness());
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tapVisible(tester, find.byKey(const ValueKey('google-sign-in')));

    // Step 1: anonymous username. Choose, never type.
    expect(find.text('Pick your anonymous name'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    final options = find.byType(ChoiceTile, skipOffstage: false);
    expect(options, findsNWidgets(6));
    await tapVisible(tester, options.first);
    await tapVisible(tester, find.byKey(const ValueKey('onboarding-continue')));

    // Step 2: interests.
    expect(find.text('What do you like to read?'), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('interest-life'), skipOffstage: false),
    );
    await tapVisible(
      tester,
      find.byKey(const ValueKey('interest-family'), skipOffstage: false),
    );
    await tapVisible(tester, find.byKey(const ValueKey('onboarding-continue')));

    // Step 3: age range.
    expect(find.text('How old are you?'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('age-young'), skipOffstage: false),
    );
    await tapVisible(tester, find.byKey(const ValueKey('onboarding-continue')));

    // Saved to the (fake) database and landed on home.
    final saved = harness.profiles.profiles[testUser.uid]!;
    expect(saved.preferredCategoryIds, ['life', 'family']);
    expect(find.textContaining(saved.handle), findsWidgets);
    expect(find.text('For you'), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-explore')), findsOneWidget);
  });

  testWidgets('home: featured, tabs, open, react and save', (tester) async {
    await boot(tester, TestHarness(signedIn: true, profile: adultProfile()));

    expect(find.textContaining('@QuietComet27'), findsWidgets);
    expect(find.textContaining('CONFESSION OF THE DAY'), findsOneWidget);
    expect(find.text('Hot'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-latest')));
    await tester.pumpAndSettle();
    expect(find.textContaining('emotional affair'), findsOneWidget);

    // The newest post is 18+, so it starts blurred: the first tap reveals
    // it and the second opens it. Tap directly (ensureVisible would tuck it
    // under the pinned tabs header).
    await tester.tap(find.text('18+  Tap to view').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('emotional affair'));
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('How does this land?'), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('reaction-hugs')));
    await tester.tap(find.byKey(const ValueKey('detail-save')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.bookmark), findsWidgets);

    // Leave before 15 s so the pending view timer is cancelled.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsNothing);
  });

  testWidgets('teen readers never see mature confessions', (tester) async {
    await boot(
      tester,
      TestHarness(
        signedIn: true,
        profile: teenProfile(),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('tab-latest')));
    await tester.pumpAndSettle();
    expect(find.textContaining('emotional affair'), findsNothing);
    expect(find.textContaining('18+'), findsNothing);
  });

  testWidgets('create a confession with the anonymous handle', (tester) async {
    await boot(tester, TestHarness(signedIn: true, profile: adultProfile()));

    await tester.tap(find.byKey(const ValueKey('nav-spill')));
    await tester.pumpAndSettle();
    expect(find.text('New confession'), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('create-life')));
    await tester.enterText(
      find.byKey(const ValueKey('confession-text')),
      'I reorganised my bookshelf by colour and told no one.',
    );
    await tester.pump();
    await tapVisible(tester, find.byKey(const ValueKey('post-as-handle')));
    expect(find.text('Posted as @QuietComet27'), findsOneWidget);

    await tapVisible(tester, find.text('Spill it'));
    expect(find.text('New confession'), findsNothing);
    expect(find.textContaining('bookshelf by colour'), findsOneWidget);
  });

  testWidgets('wide layouts keep a readable column', (tester) async {
    await boot(
      tester,
      TestHarness(signedIn: true, profile: adultProfile()),
      size: const Size(1280, 900),
    );
    final card = tester.getSize(find.byType(ConfessionCard).first);
    expect(card.width, lessThanOrEqualTo(700));
  });

  testWidgets('dark mode and settings', (tester) async {
    await boot(tester, TestHarness(signedIn: true, profile: adultProfile()));
    await tester.tap(find.byKey(const ValueKey('nav-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
