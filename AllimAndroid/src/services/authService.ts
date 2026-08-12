import auth, {FirebaseAuthTypes} from '@react-native-firebase/auth';
import firestore from '@react-native-firebase/firestore';
import functions from '@react-native-firebase/functions';
import {userService} from './userService';

// Sends a custom, mobile-friendly verification email via the
// `sendVerificationEmail` Cloud Function (Resend) instead of Firebase Auth's
// locked default template, whose link isn't tappable in many mobile mail apps.
const sendVerificationEmail = () =>
  functions().httpsCallable('sendVerificationEmail')();

// Roll back a half-finished signup so the email isn't left claimed by an auth
// account with no profile behind it. Best-effort: if the delete itself fails
// the original signup error is still what the user needs to see.
const discardAuthUser = async (user: FirebaseAuthTypes.User) => {
  try {
    await user.delete();
  } catch (_) {}
};

export const authService = {
  // Sign in with email/password
  async login(email: string, password: string): Promise<void> {
    const result = await auth().signInWithEmailAndPassword(email, password);
    if (!result.user.emailVerified) {
      await auth().signOut();
      throw new Error('EMAIL_NOT_VERIFIED');
    }
  },

  // Create new account
  async signup(
    email: string,
    password: string,
    name: string,
    userId: string,
  ): Promise<void> {
    // User docs are keyed by the lowercased username, matching iOS — one doc
    // per person across platforms.
    const normalizedUserId = userId.toLowerCase().trim();
    const normalizedEmail = email.toLowerCase().trim();

    let result;
    try {
      result = await auth().createUserWithEmailAndPassword(
        normalizedEmail,
        password,
      );
    } catch (err: any) {
      // The email may belong to an earlier signup that was never confirmed.
      // Firebase reports that identically to a fully-registered email, so ask
      // the backend whether it's still pending verification (which also
      // re-sends the link) and surface a clearer error if so.
      if (err?.code === 'auth/email-already-in-use') {
        const {data} = await functions().httpsCallable(
          'checkEmailVerificationStatus',
        )({email});
        if (data?.status === 'pending') {
          throw new Error('EMAIL_PENDING_VERIFICATION');
        }
      }
      throw err;
    }

    // The username availability check has to run *after* the auth account
    // exists: the `users` rules only grant reads to signed-in callers, so
    // checking first failed with firestore/permission-denied before the user
    // ever got an account. Matches iOS (SignupViewModel), which creates the
    // auth user, then checks, then deletes the auth user if the name is taken
    // — so a rejected signup still leaves the email free to try again.
    let usernameTaken: boolean;
    try {
      const existing = await firestore()
        .collection('users')
        .doc(normalizedUserId)
        .get();
      usernameTaken = existing.exists;
    } catch (err: any) {
      await discardAuthUser(result.user);
      throw new Error(
        `Couldn't check whether that username is available: ${
          err?.message ?? 'please try again.'
        }`,
      );
    }
    if (usernameTaken) {
      await discardAuthUser(result.user);
      throw new Error('This username is already taken. Please choose another.');
    }

    // Create user document in Firestore, keyed by username like iOS. Written
    // while signed in, since the rules only accept a create from the account
    // whose email the document carries.
    try {
      await firestore().collection('users').doc(normalizedUserId).set({
        userId: normalizedUserId,
        firebaseUid: result.user.uid,
        name: name,
        email: normalizedEmail,
        isSubscribed: false,
        adminSubscribed: false,
        createdAt: firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      // No profile means no usable account, so don't leave the auth user (and
      // its claim on the email address) behind — same rollback as iOS.
      await discardAuthUser(result.user);
      throw err;
    }

    // Non-fatal: the account exists either way, and the login screen offers a
    // resend if the email never arrives.
    try {
      await sendVerificationEmail();
    } catch (_) {}

    // Sign back out so an unverified account can't walk straight into the app
    // — login() enforces the same rule, and it's what iOS does after signup.
    await auth().signOut();
  },

  // Send password reset email
  async sendPasswordReset(email: string): Promise<void> {
    await auth().sendPasswordResetEmail(email);
  },

  // Resend verification email
  async resendVerificationEmail(): Promise<void> {
    const user = auth().currentUser;
    if (!user) {throw new Error('No user logged in');}
    await sendVerificationEmail();
  },

  // Sign out
  async signOut(): Promise<void> {
    // Best-effort: remove this device's FCM token from the user's doc while
    // still authenticated (rules only allow updating your own doc), so pushes
    // for this account stop targeting a device it no longer occupies. Raced
    // against a timeout so sign-out never hangs offline; SessionContext also
    // invalidates the device token itself once the sign-out lands.
    const user = auth().currentUser;
    if (user?.email) {
      await Promise.race([
        userService.clearFCMToken(user.email),
        new Promise<void>(resolve => setTimeout(() => resolve(), 3000)),
      ]).catch(() => {});
    }
    await auth().signOut();
  },

  // Delete account
  async deleteAccount(password: string): Promise<void> {
    const user = auth().currentUser;
    if (!user || !user.email) {throw new Error('No user');}
    const credential = auth.EmailAuthProvider.credential(user.email, password);
    await user.reauthenticateWithCredential(credential);

    // Delete the Firestore user doc. It's keyed by username, so find it by
    // email rather than assuming the doc id is the auth uid.
    const userDocs = await firestore()
      .collection('users')
      .where('email', '==', user.email)
      .get();
    await Promise.all(userDocs.docs.map(d => d.ref.delete()));
    await user.delete();
  },

  getCurrentUser() {
    return auth().currentUser;
  },

  onAuthStateChanged(callback: (user: any) => void) {
    return auth().onAuthStateChanged(callback);
  },
};
