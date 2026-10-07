# Firebase setup for Let's Spill

Let's Spill uses Firebase for **Google sign in**, **Cloud Firestore** (profiles,
settings, confessions, likes, reactions, saves, reads and reports) and
**Google Analytics**. Steps marked **(you)** need your Google account.

---

## 1. Prerequisites

```sh
flutter --version                 # 3.35+ (developed on 3.38.5)
npm install -g firebase-tools
dart pub global activate flutterfire_cli
export PATH="$PATH:$HOME/.pub-cache/bin"
firebase login                    # (you)
```

## 2. Create the Firebase project (you)

In the [Firebase console](https://console.firebase.google.com), add a project
(for example `lets-spill`) and **turn on Google Analytics** when asked. If the
project already exists without it, open Project settings, Integrations,
Google Analytics and link it, then re-run `flutterfire configure` so the
config files include the measurement ids. Use separate projects for dev and
prod.

## 3. Connect the app

From the project root:

```sh
flutterfire configure --project=<your-project-id> --platforms=android,ios,web
```

This overwrites `lib/firebase_options.dart`, which is currently a placeholder.
It also writes `android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist`. These hold **public client
identifiers, not secrets**. Make sure `firebase.json` still has the
`firestore` block that points to `firebase/firestore.rules`.

> If `flutterfire configure` times out, run `firebase login --reauth`, then
> retry. Check `firebase-debug.log` for details.

## 4. Enable Google sign-in (you)

Console → **Authentication → Get started → Sign-in method → Google →
Enable**. Choose a support email and save.

### Android

1. Get your debug (and later release) fingerprints:
   ```sh
   cd android && ./gradlew signingReport
   ```
2. Console → **Project settings → Your apps → Android app → Add
   fingerprint**: add both **SHA-1** and **SHA-256**.
3. Re-run `flutterfire configure`, so `google-services.json` includes the OAuth
   client.
4. `minSdkVersion` must be **23 or higher**. In `android/app/build.gradle.kts`,
   set `minSdk = 23` if your template uses a lower value.

### iOS

1. Open `ios/Runner/GoogleService-Info.plist` and copy the value of
   **REVERSED_CLIENT_ID**.
2. In `ios/Runner/Info.plist`, add a URL type with that value:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleTypeRole</key><string>Editor</string>
       <key>CFBundleURLSchemes</key>
       <array><string>com.googleusercontent.apps.YOUR-REVERSED-ID</string></array>
     </dict>
   </array>
   ```
3. The app passes the iOS client id from `firebase_options.dart` to
   `GoogleSignIn.initialize()` automatically.
4. Set the iOS deployment target required by the current FlutterFire and
   google_sign_in releases (see `ios/Podfile`), then `cd ios && pod install`.

### Web

Google sign-in uses Firebase's popup. In Console → Authentication →
Settings → **Authorized domains**, add `localhost` for development and your
production domain.

## 5. Create Cloud Firestore and deploy the rules (you)

Console → **Firestore Database → Create database** → pick a region (this is
permanent) → **production mode**. Then:

```sh
firebase use --add                          # pick the project
firebase deploy --only firestore            # rules and indexes
```

Indexes take a few minutes to build. Until they are ready, feeds show
"The database needs an index"; the console shows progress under Firestore,
Indexes.

> Never use "test mode" rules with real users.

### Load the sample confessions (optional)

```sh
gcloud auth application-default login       # (you) once
cd firebase/seed && npm install
npm run seed -- --project <your-project-id>
```

This adds the 28 fictional posts from `assets/mock/confessions.json` with
fresh dates and zero likes, so the feed isn't empty on day one. Remove them
later with `npm run seed -- --project <id> --delete`.

## 6. Run

```sh
flutter run
```

You should now see the intro screen, then Google sign-in, then the three
onboarding steps, then the home screen.

---

## Firestore schema

See [DATABASE.md](DATABASE.md) for every collection and field, how a like is
written, the ranking and the indexes.

**Not stored:** passwords, real name, email, photo, birthday, phone number.
Firebase Auth keeps the Google account details; the app shows them only in
the user's own Settings.

### What the rules enforce (`firebase/firestore.rules`)

- Every read and write requires sign-in. Profiles are readable only by their
  owner.
- A profile can only be created together with a matching username claim, so
  usernames are unique.
- Usernames must match `^[A-Za-z]{6,24}[0-9]{2}$`, the generator's format. A
  typed name with spaces or a real "First Last" is rejected.
- `ageRange` and categories must come from the fixed lists. After onboarding,
  only interests and settings can change; the username and age are locked.
- Confessions are created together with their private author link and the
  author's post mirror, with every counter at zero.
- Counters move by exactly one, and only in the same write as the like,
  reaction, read or save document behind them. One per person.
- Readers under 18 can't read or post 18+ confessions, even with a crafted
  query.
- Only the author can delete a confession.
- A user can delete only their own profile and only their own username claim.
- Reports are create-only, one per user per confession, and can't be read back
  by others.
- Everything else is denied.

Test the rules with `cd firebase/rules-tests && npm install && npm test`. This
needs Java 11+ for the emulator.

## Account deletion

Settings, **Delete account**:

1. Google asks the user to confirm it's them (re-authentication).
2. The app removes their likes, reactions, saves and reads, decrementing each
   counter, then deletes their posts.
3. It deletes `users/{uid}` and `usernames/{name}`, which releases the handle.
4. It deletes the Firebase Auth user and disconnects Google.

Reports stay for moderation; they contain no name or email. Say this in
your privacy policy.

## About the 13 to 17 age range

The app lets teens sign up, hides 18+ confessions from them (in the app and
in the rules), stops them marking posts 18+, and collects no advertising ID. Before launch, get legal advice for your markets: COPPA in the US
(under 13 is not allowed), GDPR-K and the UK Children's Code (age-appropriate
design), and the app store age ratings. Also consider whether teens should be
able to post at all.

## App Check, costs and monitoring

- **App Check** (recommended): register Play Integrity, App Attest or
  DeviceCheck, and reCAPTCHA in Console → App Check. Then
  `flutter pub add firebase_app_check` and call `activate()` after
  `Firebase.initializeApp` in `lib/app/bootstrap.dart`. Enforce it once the
  metrics look healthy.
- **Costs**: a feed page reads 15 confessions plus one query for liked
  state; a like or reaction is one transaction with three or four writes; a
  qualified read is two writes. The free Spark plan covers early usage.
- Monitor usage in **Firestore → Usage** and in **Firebase Console → Usage
  and billing**. On the **Blaze** plan you pay as you go, and **budget alerts
  only notify you; they don't cap spending**. Set alerts at 50/90/100% of a
  small budget.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Splash: "isn't connected to a Firebase project yet" | Run `flutterfire configure` (step 3) |
| Android: `clientConfigurationError` / developer error 10 | Add SHA-1 and SHA-256 fingerprints, then re-run `flutterfire configure` |
| iOS crashes on sign-in | Add the REVERSED_CLIENT_ID URL scheme (step 4) |
| `operation-not-allowed` | Enable the Google provider (step 4) |
| `permission-denied` when finishing onboarding | Deploy the rules (step 5) |
| "The database needs an index" | `firebase deploy --only firestore:indexes`, then wait for the build |
| Empty feed on a new project | Load the sample confessions (step 5) or post one |
| Web popup blocked or closed | Allow popups. Closing the popup is treated as a cancel, not an error |
