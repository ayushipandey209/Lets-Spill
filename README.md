# Let's Spill 🖤

**Your secrets. Their stories.**
Read confessions, share secrets, and discover real-life stories.

Let's Spill is a text-only, anonymous confession journal built with
**Flutter + flutter_bloc + Firebase Authentication (Google) + Cloud Firestore**.

- Flutter package name: `let_s_spill` · App name: *Let's Spill*
- Developed against Flutter **3.38.5** / Dart **3.10.4** (minimum Flutter 3.35)
- No custom backend, no REST API, no media uploads, no comments, no paid services.

## What's real and what's JSON (for now)

| Area | Source |
|---|---|
| Sign-in | **Real** — Google via Firebase Authentication |
| User profile (anonymous username, age range, reading preferences) | **Real** — Cloud Firestore `users/{uid}` + `usernames/{name}` |
| Reports | **Real** — Cloud Firestore `reports/` |
| Confessions (feed, search, Confession of the Day) | **Bundled JSON** — `assets/mock/confessions.json` (28 fictional posts) |
| Your likes, reactions, saves, views and own posts | On this device (`shared_preferences`), keyed by your Firebase uid |

There is no demo account any more: you sign in with Google to use the app.

## The flow

1. **Intro** — three swipeable slides, one button: *Continue with Google*.
2. **Onboarding** (only the first time, and there's nothing to type):
   1. **Anonymous name**: pick one of six generated handles such as
      `@QuietComet27`, or shuffle for more. They can't contain real names.
   2. **What you like to read**: choose one or more categories.
   3. **Age range**: 13–17, 18–24, 25–34, 35–44 or 45+. Readers aged 13–17
      never see confessions marked as mature (`"mature": true`).

   Your choices are saved to Firestore, and the username is claimed atomically
   so no two people get the same one.
3. **Home**:
   - a greeting with your handle
   - a **Confession of the Day** card, which changes daily
   - **For you / Trending / Latest** tabs
   - category filters and infinite scroll
   - **bookmarks**, a **search** screen, and a **Spill** button to write a confession
4. **Reading**: like, the reactions **Same / Hugs / Wow / Oof** (one per person), save, share and
   report. A view counts after **15 continuous seconds** on screen, once per
   reader.
5. **Writing**: post as **Anonymous** or as your **@handle**.
6. **Profile**:
   - your handle, age range and Google account details, which only you can see
   - reading preferences
   - **Your confessions** and **Saved**
   - guidelines, privacy and support links, sign out, and **Delete account**

## Run it

```sh
cd LetsSpill-App
flutter pub get

# One-time Firebase setup (Google sign-in won't work without it):
#   see docs/FIREBASE_SETUP.md — flutterfire configure, enable Google,
#   add Android SHA fingerprints, create Firestore, deploy rules.

flutter run
```

If Firebase isn't configured yet, the splash screen shows the exact setup steps
and a **Try again** button instead of crashing.

Optional production links (shown as placeholders until set):

```sh
flutter run --dart-define=PRIVACY_POLICY_URL=https://example.com/privacy \
            --dart-define=SUPPORT_CONTACT=support@example.com
```

## Checks

```sh
dart format .
flutter analyze
flutter test                                   # uses fake auth/profile repos

cd firebase/rules-tests && npm install && npm test   # rules, needs Java 11+
```

## Architecture

```
lib/
  main.dart                 entry point
  firebase_options.dart     placeholder → replaced by `flutterfire configure`
  app/
    app.dart                MaterialApp, providers, session gate
                            (intro → onboarding → home)
    bootstrap.dart          wires Firebase auth/profile + local JSON content
    router.dart             named routes
    init/                   AppInitCubit + splash (loading / setup error / retry)
    theme/                  design tokens + ThemeData (beige & black, Figtree)
  core/
    config/app_config.dart  limits (2,000 chars, 15 s views, page size), links
    data/                   asset loader, key-value store, LocalContentStore,
                            Firebase error mapping + Firestore paths
    errors/ services/ utils/ widgets/
  features/
    auth/                   AuthRepository (Google/Firebase) + SessionCubit
    onboarding/             UsernameGenerator, OnboardingCubit, intro + steps UI
    profile/                ProfileRepository (Firestore), ProfileCubit + page
    confessions/            Confession model, ConfessionRepository (local JSON),
                            shared card / filter widgets
    feed/                   FeedBloc (tabs, filters, featured, saves) + HomePage
    confession_detail/      ConfessionDetailCubit (like, react, save, share,
                            15 s view) + page
    create_confession/      CreateConfessionCubit (+ post as handle) + page
    search/                 SearchCubit + page
    reports/                ReportRepository (Firestore), ReportCubit + sheet
    settings/               AccountDeletionCubit, guidelines, info, delete page
assets/mock/                categories.json · confessions.json
assets/fonts/               Figtree variable font (OFL)
firebase/                   firestore.rules · firestore.indexes.json · rules-tests/
docs/                       FIREBASE_SETUP.md · MOCK_DATA.md
test/                       unit, bloc and widget tests (with fakes)
```

The UI and BLoCs only use repository **interfaces**. Moving the confessions
to Firestore later means adding a `FirestoreConfessionRepository` and changing
one line in `bootstrap.dart`; no screen changes.

## Design system

Beige & black only, defined once in `lib/app/theme/app_tokens.dart`:
background `#F2E8D8`, ink `#171717`, surface `#E7D8C3`, border `#CBBBA5`,
muted text `#5C5246`, and a muted oxblood `#7A2E22` used only for errors.
Typography: **Figtree** (variable, bundled). The Confession of the Day and the
profile identity card invert to black-on-beige for emphasis.

## Privacy highlights

- No passwords anywhere: Google handles credentials.
- Firestore stores **no real name, email, photo or birthday**. It holds only the
  generated handle, the age *range* and the categories you picked.
- Usernames are chosen from generated options, never typed. The rules enforce
  the same pattern, so a real name can't be saved even by a modified client.
- Confessions show "Anonymous" or your generated handle, never your Google
  identity.
- Account deletion asks Google to confirm it's you, then deletes the profile,
  releases the username, clears your on-device activity and posts, and deletes
  the Firebase account.

## Before production

- [ ] Real Privacy Policy, Community Guidelines and support contact.
- [ ] Legal review of the 13–17 age range for your markets (COPPA/GDPR-K etc.)
      and of mature-content labelling.
- [ ] Move confessions + engagement to Firestore (shared across users).
- [ ] Firebase App Check, budget alerts, and a moderation workflow for `reports`.
# Lets-Spill
