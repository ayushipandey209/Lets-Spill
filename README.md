# Let's Spill

**Your secrets. Their stories.**
Read confessions, share secrets, and discover real-life stories.

Let's Spill is a text-only, anonymous confession app built with
**Flutter, flutter_bloc and Firebase** (Authentication with Google, Cloud
Firestore and Google Analytics).

- Flutter package `let_s_spill`, app name *Let's Spill*, version 1.0.0
- Developed against Flutter 3.38 / Dart 3.10 (minimum Flutter 3.35)
- No custom backend and no paid services: everything runs on the Firebase
  free tier with security rules doing the enforcement.

## What's stored where

Everything a user does is stored in Cloud Firestore and mapped to their
account. Full schema: [docs/DATABASE.md](docs/DATABASE.md).

| Data | Where |
|---|---|
| Sign in | Firebase Authentication (Google) |
| Profile: anonymous name, age range, interests, settings | `users/{uid}` |
| Confessions with live counters (likes, views, saves, reactions) | `confessions/{id}` |
| Who liked / reacted / read a confession | `confessions/{id}/likes\|reactions\|views/{uid}` |
| A user's own posts, likes, reactions and saves | `users/{uid}/posts\|likes\|reactions\|saves/{id}` |
| Private link from a post to its author | `confessionAuthors/{id}` |
| Reports | `reports/{id}_{uid}` |
| Usage analytics | Google Analytics for Firebase |
| Theme and other settings (copy, so they apply before sign in) | the device |

Every counter moves in the same transaction as the document behind it, and
the security rules reject any write that would let them drift. So
`likeCount` always equals the number of `likes/{uid}` documents.

## The app

1. **Intro**: three slides and *Continue with Google*.
2. **Onboarding** (first time only, nothing to type): pick a generated
   anonymous name, your interests, and your age range. Readers aged 13 to 17
   never see 18+ confessions (enforced by the rules too).
3. **Home** (Reddit style):
   - bottom bar: Home, Explore, Spill, You
   - Confession of the Day
   - sort tabs: For you, Hot, New, Top
   - category chips and endless scroll
   - inline like, share and save on every card
   - card or compact layout; 18+ posts blurred until tapped
4. **Explore**: search, popular searches and every category. Each category
   has its own page with Hot / New / Top and a mute button.
5. **Reading**: like, react (Same, Hugs, Wow, Oof), save, share, report. A
   read counts after 15 seconds on screen, once per reader.
6. **Spill**: write a confession, post as Anonymous or your handle, mark it
   18+ (adults only).
7. **You**: karma, posts and reads, plus your Posts, Saved and Liked lists.
8. **Settings**: theme (light, dark, match device), text size, feed layout,
   reduce motion, Home default sort, Confession of the Day, 18+ visibility
   and blur, interests, muted categories, default posting identity,
   haptics, usage analytics, privacy, guidelines, support, sign out and
   delete account. Settings sync to the account.

## Run it

```sh
cd LetsSpill-App
flutter pub get
flutter run
```

First time on a new Firebase project, follow
[docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md): enable Google sign in, add
the Android SHA fingerprints and the iOS URL scheme, create Firestore, deploy
the rules and indexes, and optionally load the sample posts:

```sh
firebase deploy --only firestore
cd firebase/seed && npm install && npm run seed -- --project lets-spill
```

If Firebase isn't configured, the splash screen lists the setup steps and a
**Try again** button instead of crashing.

Production links (shown as "before launch" notes until set):

```sh
flutter build appbundle \
  --dart-define=PRIVACY_POLICY_URL=https://your.site/privacy \
  --dart-define=SUPPORT_CONTACT=support@your.site
```

## Checks

```sh
dart format .
flutter analyze
flutter test                                        # fakes, no Firebase needed
cd firebase/rules-tests && npm install && npm test  # rules, needs Java 11+
```

## Architecture

```
lib/
  main.dart                 entry point (opens device settings, then runs)
  app/
    app.dart                MaterialApp (light + dark), providers, session gate
    bootstrap.dart          wires Firebase Auth, Firestore and Analytics
    router.dart             named routes
    init/                   start up cubit and splash
    theme/                  design tokens (light and dark) and ThemeData
  core/
    analytics/              Analytics interface, Firebase implementation,
                            route observer, event names
    config/                 limits, links, version
    data/                   Firestore paths, error mapping, key-value store
    errors/ services/ utils/ widgets/
  features/
    auth/                   Google sign in and SessionCubit
    onboarding/             generated names, OnboardingCubit, intro and steps
    home/                   bottom navigation shell
    feed/                   FeedBloc (sorts, filters, likes, saves), Home and
                            category pages
    explore/                search entry and categories
    confessions/            model, ranking and search tokens,
                            FirestoreConfessionRepository, cards and actions
    confession_detail/      reading screen (like, react, save, share, 15 s view)
    create_confession/      composer
    search/                 search
    profile/                profile repository, You tab
    reports/                report sheet
    settings/               AppSettings, SettingsCubit, Settings, guidelines,
                            info and delete account pages
firebase/                   firestore.rules, firestore.indexes.json,
                            rules-tests/, seed/
docs/                       FIREBASE_SETUP.md, DATABASE.md, ANALYTICS.md
test/                       unit, bloc and widget tests with in-memory fakes
```

## Design

Defined once in `lib/app/theme/app_tokens.dart`.

- Light: warm beige page `#F2E8D8`, cards `#FAF4EA`, ink `#171717`.
- Dark: warm near-black `#121110`, cards `#1B1A18`, off-white text `#EDE6DA`.
- One accent (terracotta) for likes and the selected tab; a muted red only
  for errors and 18+ tags.
- Typography: Figtree, a compact reading scale (body 15.5, metadata 12.5),
  scaled by the Text size setting and the device's own setting.

## Privacy

- No passwords: Google handles credentials.
- No real name, email, photo or birthday in Firestore.
- Who wrote a post is stored only in `confessionAuthors`, readable by the
  author alone.
- Analytics never includes confession text or search words, collects no
  advertising ID and can be turned off in Settings.
- Deleting an account removes the profile, every post, and every like,
  reaction, save and read (with counters decremented), then the sign in.

## Before launch

- [ ] Publish the privacy policy, guidelines and support contact; pass them
      with `--dart-define`.
- [ ] Legal review of the 13 to 17 age range for your markets.
- [ ] Turn on Firebase App Check and budget alerts.
- [ ] A moderation workflow for `reports` (set a post's `status` to `hidden`).
- [ ] App icons and store listings.
