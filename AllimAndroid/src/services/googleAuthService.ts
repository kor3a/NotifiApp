import auth, {FirebaseAuthTypes} from '@react-native-firebase/auth';
import Constants from 'expo-constants';
import {
  GoogleSignin,
  isErrorWithCode,
  isSuccessResponse,
  statusCodes,
} from '@react-native-google-signin/google-signin';

/**
 * "Continue with Google" for Android, mirroring the iOS AuthenticationManager.
 *
 * The two rules the iOS flow is built around apply here too:
 *
 *  1. No duplicate Firebase Auth accounts. The project keeps Firebase's default
 *     "one account per email address" setting, so signing in with Google using
 *     an email that already belongs to another account fails with
 *     `auth/account-exists-with-different-credential`. We then LINK Google onto
 *     the existing account instead of creating a second one.
 *
 *  2. No duplicate Firestore `users` profiles. After sign-in the profile is
 *     looked up by email (SessionContext); only when none exists does the app
 *     route to ProfileSetupScreen, which writes exactly one new profile.
 *
 * Unlike iOS there is no Apple branch: Sign in with Apple on Android would need
 * the Services ID + private key configured in Firebase (see SOCIAL_LOGIN_SETUP.md),
 * which this project deliberately does not set up. An Apple-owned email is
 * therefore reported back to the caller as an explanation rather than a link
 * flow it cannot finish.
 */

// Set from app.config.js (`extra.googleWebClientId`) — the type-3 OAuth client
// out of google-services.json. Google mints the ID token for this client, and
// it is the audience Firebase checks, so sign-in fails without it.
const WEB_CLIENT_ID = (Constants.expoConfig?.extra as any)?.googleWebClientId as
  | string
  | undefined;

let isConfigured = false;

function configure() {
  if (isConfigured) {
    return;
  }
  if (!WEB_CLIENT_ID) {
    throw new Error(
      'Google Sign-In is not configured correctly. Please try again later.',
    );
  }
  GoogleSignin.configure({webClientId: WEB_CLIENT_ID});
  isConfigured = true;
}

export type GoogleSignInOutcome =
  /** Signed in to Firebase. The session listener takes it from here. */
  | {status: 'signedIn'}
  /** User dismissed the Google account sheet — not an error worth surfacing. */
  | {status: 'cancelled'}
  /**
   * The email already belongs to an email/password account. Ask for that
   * password and pass it, with this credential, to `linkToPasswordAccount`.
   */
  | {
      status: 'needsPasswordLink';
      email: string;
      credential: FirebaseAuthTypes.AuthCredential;
    }
  /**
   * The email already belongs to an Apple account, which can only be
   * re-authenticated on iOS. Nothing to link here.
   */
  | {status: 'appleAccountExists'; email: string};

/** A Google account the user just picked, ready to hand to Firebase. */
type GoogleCredential = {
  credential: FirebaseAuthTypes.AuthCredential;
  email: string;
};

/** Run the Google account picker and turn the result into a Firebase credential. */
async function requestGoogleCredential(): Promise<GoogleCredential | null> {
  configure();

  // Throws PLAY_SERVICES_NOT_AVAILABLE (and offers the update dialog) rather
  // than failing later with an opaque native error.
  await GoogleSignin.hasPlayServices({showPlayServicesUpdateDialog: true});

  // Google's client remembers the last account and would reuse it silently, so
  // someone who picked the wrong account could never switch. Clearing it first
  // always brings up the picker. Best-effort: nothing is signed in on a cold
  // start, and that is not a failure.
  await GoogleSignin.signOut().catch(() => {});

  const response = await GoogleSignin.signIn();
  if (!isSuccessResponse(response)) {
    return null;
  }

  const {idToken, user} = response.data;
  if (!idToken) {
    throw new Error(
      'Google Sign-In failed: missing credentials. Please try again.',
    );
  }

  return {
    credential: auth.GoogleAuthProvider.credential(idToken),
    email: user.email,
  };
}

/**
 * Outcomes that shouldn't be surfaced as errors: the user dismissed the sheet,
 * or a sheet is already open and this second request is redundant.
 */
function isCancellation(err: unknown): boolean {
  return (
    isErrorWithCode(err) &&
    (err.code === statusCodes.SIGN_IN_CANCELLED ||
      err.code === statusCodes.IN_PROGRESS)
  );
}

/**
 * `GoogleSignInStatusCodes.DEVELOPER_ERROR`. The library has no `statusCodes`
 * entry for it — the native module passes Google's raw integer through as a
 * string — so it has to be matched by value.
 */
const DEVELOPER_ERROR_CODE = '10';

/**
 * Turn the picker's opaque native failures into something the reader can act
 * on, or return null to let the original error through.
 *
 * DEVELOPER_ERROR is worth spelling out: Google rejects the request before the
 * account picker returns anything, and the message it ships is the bare string
 * "DEVELOPER_ERROR". It means Google does not recognise this build — package
 * name + signing-certificate SHA-1 — not that anything went wrong at runtime,
 * so it happens on every attempt until the fingerprint is registered.
 */
function explainSignInError(err: unknown): Error | null {
  if (!isErrorWithCode(err)) {
    return null;
  }
  if (err.code === statusCodes.PLAY_SERVICES_NOT_AVAILABLE) {
    return new Error(
      'Google Play services is required to sign in with Google. Please install or update it and try again.',
    );
  }
  if (err.code === DEVELOPER_ERROR_CODE) {
    // The alert reaches whoever is running the build, so name the fix.
    console.error(
      '[googleAuthService] DEVELOPER_ERROR: Google does not recognise this ' +
        'build. Register the SHA-1 of the keystore that signed it against ' +
        'package com.allimandroid in the Firebase console, re-download ' +
        'google-services.json (it should then contain an oauth_client with ' +
        '"client_type": 1), and rebuild — see SOCIAL_LOGIN_SETUP.md section 5. ' +
        `Web client ID in use: ${WEB_CLIENT_ID}`,
    );
    return new Error(
      "Google Sign-In isn't set up for this build: its signing certificate " +
        'is not registered with Google (DEVELOPER_ERROR). See ' +
        'SOCIAL_LOGIN_SETUP.md section 5.',
    );
  }
  return null;
}

export const googleAuthService = {
  async signIn(): Promise<GoogleSignInOutcome> {
    let google: GoogleCredential | null;
    try {
      google = await requestGoogleCredential();
    } catch (err: any) {
      if (isCancellation(err)) {
        return {status: 'cancelled'};
      }
      throw explainSignInError(err) ?? err;
    }

    if (!google) {
      return {status: 'cancelled'};
    }
    const {credential, email} = google;

    try {
      await auth().signInWithCredential(credential);
      return {status: 'signedIn'};
    } catch (err: any) {
      if (err?.code !== 'auth/account-exists-with-different-credential') {
        throw err;
      }

      // The colliding address is the one Google just gave us — the Android
      // Firebase module doesn't carry it on the error the way iOS does.
      if (!email) {
        throw new Error(
          'An account already exists with this email. Please sign in with your original method.',
        );
      }

      // With email-enumeration protection switched on this comes back empty, in
      // which case we assume a password account and let the password prompt be
      // the check — same fallback as iOS.
      let methods: string[] = [];
      try {
        methods = await auth().fetchSignInMethodsForEmail(email);
      } catch (_) {}

      if (methods.includes('apple.com') && !methods.includes('password')) {
        return {status: 'appleAccountExists', email};
      }

      return {status: 'needsPasswordLink', email, credential};
    }
  },

  /**
   * Finish the link started by a `needsPasswordLink` outcome: sign in to the
   * existing password account, then attach the Google credential to it so both
   * routes land on one account from now on.
   */
  async linkToPasswordAccount(
    email: string,
    password: string,
    credential: FirebaseAuthTypes.AuthCredential,
  ): Promise<void> {
    const result = await auth().signInWithEmailAndPassword(email, password);
    try {
      await result.user.linkWithCredential(credential);
    } catch (err: any) {
      // Both mean the link already exists — the accounts are joined either way.
      if (
        err?.code !== 'auth/provider-already-linked' &&
        err?.code !== 'auth/credential-already-in-use'
      ) {
        await auth().signOut();
        throw err;
      }
    }
    // Linking a provider that vouches for the address marks it verified; reload
    // so the session sees that rather than the pre-link value.
    await result.user.reload();
  },

  /**
   * Fresh Google credential for the signed-in user, for operations Firebase
   * only allows after a recent login (account deletion). Returns null if the
   * user dismissed the picker.
   */
  async reauthenticate(): Promise<boolean> {
    const user = auth().currentUser;
    if (!user) {
      throw new Error('No user logged in');
    }
    let google: GoogleCredential | null;
    try {
      google = await requestGoogleCredential();
    } catch (err: any) {
      if (isCancellation(err)) {
        return false;
      }
      throw explainSignInError(err) ?? err;
    }
    if (!google) {
      return false;
    }
    // Firebase rejects a re-auth against a different account, which is the
    // check we want: picking someone else's Google account must not delete this
    // one. The message it produces is opaque, so name the requirement instead.
    if (
      user.email &&
      google.email.toLowerCase() !== user.email.toLowerCase()
    ) {
      throw new Error(
        `Please confirm with the Google account for ${user.email}.`,
      );
    }
    await user.reauthenticateWithCredential(google.credential);
    return true;
  },

  /**
   * Drop the cached Google account on sign-out so the next sign-in shows the
   * picker instead of silently reusing the last one. Best-effort — a signed-out
   * Firebase session is the part that matters.
   */
  async signOut(): Promise<void> {
    try {
      configure();
      await GoogleSignin.signOut();
    } catch (_) {}
  },

  /** Whether the signed-in account authenticates through Google. */
  isGoogleAccount(user: FirebaseAuthTypes.User | null): boolean {
    return (user?.providerData ?? []).some(p => p.providerId === 'google.com');
  },

  /**
   * Whether the account has an email/password credential at all. Accounts
   * created with Google don't, so there is no password to type when deleting.
   */
  hasPasswordProvider(user: FirebaseAuthTypes.User | null): boolean {
    return (user?.providerData ?? []).some(p => p.providerId === 'password');
  },
};
