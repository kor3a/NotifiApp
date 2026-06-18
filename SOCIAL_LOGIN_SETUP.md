# Google & Apple Sign-In Setup

This document covers the **one-time console configuration** required to make the
in-app Google and Apple sign-in (added to `LoginView`) work. All the code,
Info.plist URL scheme, entitlement, and the GoogleSignIn Swift package are
already wired up in the repo — these steps are the parts that live in Apple's
and Firebase's consoles and can't be committed to git.

## How the integration avoids duplicate accounts

The flow lives in `Geolocation_v1.0.0/Services/AuthenticationManager.swift`:

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

## 3. Google — already configured in code

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
