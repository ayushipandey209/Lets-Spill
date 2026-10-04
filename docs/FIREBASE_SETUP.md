# Firebase setup — Let's Spill

Let's Spill uses Firebase for **Google sign-in** and for the user's **profile**
(anonymous username, age range and reading preferences). Confession content is
bundled JSON for now. Nothing here is pre-configured: no project IDs, keys or
credentials are committed. Steps marked **(you)** need your Google account.

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

<https://console.firebase.google.com> → **Add project** (e.g. `lets-spill-dev`).
Analytics is optional. Use separate projects for dev and prod.

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
firebase deploy --only firestore:rules,firestore:indexes
```

> Never use "test mode" rules with real users.

## 6. Run

```sh
flutter run
```

You should now see the intro screen, then Google sign-in, then the three
onboarding steps, then the home screen.

---

## Firestore schema

```
users/{uid}                          PRIVATE (owner only)
  username              "QuietComet27"   generated handle, chosen not typed
  usernameLower         "quietcomet27"
  ageRange              teen | young | adult | mid | senior
                        (13–17 | 18–24 | 25–34 | 35–44 | 45+)
  preferredCategoryIds  ["life", "family"]  (1–6 known ids)
  onboardingComplete    true
  createdAt, updatedAt  server timestamps

usernames/{usernameLower}            uniqueness claim
  uid, createdAt

reports/{confessionId}_{uid}         create-only
  confessionId, reporterUid, reason, details (≤500), createdAt,
  reviewStatus: "open"
```

**Not stored:** passwords, real name, email, photo, birthday, phone number.
Firebase Auth keeps the Google account details; the app shows them only on
the private profile screen.

### What the rules enforce (`firebase/firestore.rules`)

- Every read and write requires sign-in. Profiles are readable only by their
  owner.
- A profile can only be created together with a matching username claim, so
  usernames are unique.
- Usernames must match `^[A-Za-z]{6,24}[0-9]{2}$`, the generator's format. A
  typed name with spaces or a real "First Last" is rejected.
- `ageRange` and categories must come from the fixed lists. After onboarding,
  only the preferences can change; the username and age are locked.
- A user can delete only their own profile and only their own username claim.
- Reports are create-only, one per user per confession, and can't be read back
  by others.
- Everything else is denied.

Test the rules with `cd firebase/rules-tests && npm install && npm test`. This
needs Java 11+ for the emulator.

## Account deletion

Profile → **Delete account**:

1. Google asks the user to confirm it's them (re-authentication).
2. The app deletes `users/{uid}` and `usernames/{name}`, which releases the handle.
3. It clears on-device likes, reactions, saves, views and own posts.
4. It deletes the Firebase Auth user and disconnects Google.

Reports stay for moderation; they contain no name or email. Say this in
your privacy policy.

## About the 13–17 age range

The app lets teens sign up, and it hides confessions marked `"mature": true`
from them. Before launch, get legal advice for your markets: COPPA in the US
(under 13 is not allowed), GDPR-K and the UK Children's Code (age-appropriate
design), and the app store age ratings. Also consider whether teens should be
able to post at all.

## App Check, costs and monitoring

- **App Check** (recommended): register Play Integrity, App Attest or
  DeviceCheck, and reCAPTCHA in Console → App Check. Then
  `flutter pub add firebase_app_check` and call `activate()` after
  `Firebase.initializeApp` in `lib/app/bootstrap.dart`. Enforce it once the
  metrics look healthy.
- **Costs today are tiny**: each session reads one profile document, and
  writes happen only during onboarding, preference edits and reports.
  Confessions don't touch Firestore yet.
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
| Web popup blocked or closed | Allow popups. Closing the popup is treated as a cancel, not an error |
