# Google & Apple Sign-In Setup

This document covers the **one-time console configuration** required to make the
in-app Google and Apple sign-in (added to `LoginView` on iOS and `LoginScreen`
on Android) work. All the code, Info.plist URL scheme, entitlement, the
GoogleSignIn Swift package, and the Android sign-in library are already wired up
in the repo — these steps are the parts that live in Apple's, Google's, and
Firebase's consoles and can't be committed to git.

- iOS needs **nothing** beyond enabling the providers (sections 1–4).
- **Android needs one extra step that iOS does not**: registering the app's
  signing-certificate SHA-1 fingerprints. See [section 5](#5-android--sha-1-fingerprints-required).

## How the integration avoids duplicate accounts

The flow lives in `Geolocation_v1.0.0/Services/AuthenticationManager.swift` on
iOS and `AllimAndroid/src/services/googleAuthService.ts` on Android:

1. **One Firebase Auth account per email.** Firebase's default "one account per
   email address" setting is respected. If someone signs in with Google/Apple
   using an email that already belongs to another account, Firebase returns
   `accountExistsWithDifferentCredential` and we **link** the new provider onto
   the existing account instead of creating a second one:
   - existing **email/password** account → we ask for the password, then link;
   - existing **Google/Apple** account → we ask the user to confirm, re-authenticate
     with that original provider, then link the new credential onto it.
2. **One Firestore `users` profile per email.** After Firebase sign-in we look up
   the profile by email. If it exists we load it; only if none exists do we
   create a single new profile with an auto-generated unique username.

Because Google and Apple return verified emails, `isEmailVerified` is `true`, so
`MainViewModel` routes social users straight to `HomeView` (no email-verification
step needed for them).

## 1. Firebase Console

In the [Firebase Console](https://console.firebase.google.com/) → project
**georeminder-pilot** → **Authentication** → **Sign-in method**:

- Enable **Google** as a provider. Set a support email.
- Enable **Apple** as a provider.

> Keep the default account-handling setting **"Prevent creation of multiple
> accounts with the same email address"** (one account per email). The app's
> linking flow is built around this and it's the more secure choice.

## 2. Apple Developer — Sign in with Apple capability

In the [Apple Developer portal](https://developer.apple.com/account/) →
**Certificates, Identifiers & Profiles** → **Identifiers** → App ID
`com.kor3a.nearbuy`:

- Enable the **Sign in with Apple** capability.
- Regenerate / let Xcode refresh the provisioning profile so it includes the
  capability.

The matching entitlement (`com.apple.developer.applesignin`) is already added in
`AllimRelease.entitlements`.

> For native iOS Sign in with Apple, enabling the Apple provider in Firebase
> (step 1) is sufficient. The Apple **Services ID / private key** configuration
> in Firebase is only required for web or Android Apple sign-in.

## 3. Google (iOS) — already configured in code

No extra Google Cloud steps are needed for iOS:

- The OAuth client ID and `REVERSED_CLIENT_ID` come from the existing
  `GoogleService-Info.plist`.
- The `REVERSED_CLIENT_ID` URL scheme
  (`com.googleusercontent.apps.903190692128-...`) is already added to `Info.plist`.
- `GIDSignIn` is configured at launch in `Geolocation_v1_0_0App.swift`, and its
  OAuth callback URL is handled in the app's `onOpenURL`.

## 4. Swift Package

The **GoogleSignIn-iOS** package (`https://github.com/google/GoogleSignIn-iOS`,
7.x) is referenced in the Xcode project. On the next build, Xcode/SPM will
resolve it automatically (requires network access the first time).

## 5. Android — SHA-1 fingerprints (REQUIRED)

**This is the only manual step Android needs, and Google Sign-In cannot work
without it.** Everything else — the library, the config plugin, the web client
ID, the login button, the linking flow — is already in the repo.

### Why

On iOS, Google identifies the app by its bundle ID and the `REVERSED_CLIENT_ID`
URL scheme. On Android there is no equivalent, so Google identifies the app by
**package name + the SHA-1 fingerprint of the certificate the APK was signed
with**. Any build signed with a certificate Google hasn't been told about is
rejected — the account picker opens, you choose an account, and it closes again
with `DEVELOPER_ERROR` (status code 10) and no explanation.

Today `AllimAndroid/google-services.json` contains only an `oauth_client` of
`client_type: 3` (the shared *web* client). There is no `client_type: 1` entry,
which is exactly what an Android app with no registered fingerprint looks like.
Adding a fingerprint in Firebase creates that entry.

### Which fingerprints to add

Add **every** certificate that will ever sign the app — you need one entry per
keystore, and they are all different:

| Build | Signed with | Where to get the SHA-1 |
|---|---|---|
| `npm run build:dev` / `build:preview` (EAS) | EAS-managed keystore | `cd AllimAndroid && eas credentials -p android` → *Keystore: Manage everything* |
| `npm run build:prod` → Play Store | **Google Play's** app-signing key | Play Console → your app → **Test and release → Setup → App integrity** → *App signing key certificate* |
| `npm run android` (local `expo run:android`) | Local debug keystore | `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android` |

> The Play Store one is easy to miss. Play re-signs your upload with its own key,
> so a build that worked from EAS will fail once it ships unless Play's app
> signing SHA-1 is registered too. Add it before your first release.

### Steps

1. [Firebase Console](https://console.firebase.google.com/) → project
   **georeminder-pilot** → ⚙ **Project settings** → **General** → scroll to
   **Your apps** → the Android app **`com.allimandroid`**.
2. **Add fingerprint** → paste a SHA-1 → Save. Repeat for each certificate
   above. (Adding the SHA-256 as well is harmless and is needed if you ever
   enable App Links or Play Integrity.)
3. Click **Download google-services.json** and replace
   `AllimAndroid/google-services.json` with it. The new file will contain an
   extra `oauth_client` with `"client_type": 1` — that is the confirmation the
   fingerprint registered.
4. Rebuild the app. This is a **native** change, so a JS reload is not enough:
   ```sh
   cd AllimAndroid
   npm install                       # picks up @react-native-google-signin
   npm run build:dev                 # or: npm run prebuild:clean && npm run android
   ```

Nothing else changes: the OAuth consent screen is already configured
project-wide from the iOS setup, and the web client ID the Android code sends
(`extra.googleWebClientId` in `app.config.js`) is the same `client_type: 3`
client that is already in `google-services.json`.

### Verifying / troubleshooting

| Symptom | Cause |
|---|---|
| Picker opens, closes immediately, and the app reports *"Google Sign-In isn't set up for this build"* (`DEVELOPER_ERROR` / code `10`; the console log names the fix) | The signing SHA-1 for *this specific build* is not registered, or `google-services.json` was not re-downloaded after adding it. |
| `Google Sign-In is not configured correctly` | `extra.googleWebClientId` is missing — check `app.config.js` and rebuild. |
| Works in the EAS dev build, fails after Play release | Play's app-signing SHA-1 was never added (see the table above). |
| `Google Play services is required to sign in` | Emulator image has no Play Services — use a *"Google Play"* system image, not a plain AOSP one. |

### What Android does *not* support

Sign in with **Apple** is iOS-only here. Apple sign-in on Android goes through a
web flow that needs an Apple **Services ID** and private key configured in
Firebase, which this project deliberately hasn't set up (see the note in
section 2). If an Android user tries Google with an email that already belongs
to an Apple account, `LoginScreen` says so and points them at the iOS app rather
than starting a link it can't finish.

## Apple "Hide My Email" and re-prompting consent

If a user chooses **Hide My Email** with Apple, Apple supplies a private relay
address (`…@privaterelay.appleid.com`) that differs from their real email.
Because the emails don't match, Firebase treats it as a separate account — this
is an inherent limitation of Apple's private relay and can't be deduped purely
client-side. All cases where the emails *do* match are linked automatically
(including across Google/Apple).

Once a user has authorized Sign in with Apple for the app, **iOS will not show
the Hide/Share-email consent screen again** until they revoke the app's access.
This is an Apple-account setting, not an app cache. To get the prompt back:

- On device: **Settings → [your name] → Sign-In & Security → Sign in with Apple
  → Allim → Stop Using Apple ID**, or
- On the web: [appleid.apple.com](https://appleid.apple.com) → Sign-In & Security
  → Sign in with Apple → select the app → Stop using.

If a "Hide My Email" attempt created an unwanted account, delete it in
**Firebase Console → Authentication → Users** (the `…@privaterelay.appleid.com`
user) and remove the matching document in **Firestore → `users`**.
