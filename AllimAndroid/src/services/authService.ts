import auth from '@react-native-firebase/auth';
import firestore from '@react-native-firebase/firestore';
import functions from '@react-native-firebase/functions';
import {userService} from './userService';

// Sends a custom, mobile-friendly verification email via the
// `sendVerificationEmail` Cloud Function (Resend) instead of Firebase Auth's
// locked default template, whose link isn't tappable in many mobile mail apps.
const sendVerificationEmail = () =>
  functions().httpsCallable('sendVerificationEmail')();

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
    // per person across platforms. Check availability BEFORE creating the
    // auth account so a taken username doesn't leave an orphaned auth user.
    const normalizedUserId = userId.toLowerCase().trim();
    const normalizedEmail = email.toLowerCase().trim();
    const existing = await firestore()
      .collection('users')
      .doc(normalizedUserId)
      .get();
    if (existing.exists) {
      throw new Error('This username is already taken. Please choose another.');
    }

    let result;
    try {
      result = await auth().createUserWithEmailAndPassword(email, password);
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
    await sendVerificationEmail();

    // Create user document in Firestore, keyed by username like iOS
    await firestore().collection('users').doc(normalizedUserId).set({
      userId: normalizedUserId,
      firebaseUid: result.user.uid,
      name: name,
      email: normalizedEmail,
      isSubscribed: false,
      adminSubscribed: false,
      createdAt: firestore.FieldValue.serverTimestamp(),
    });
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

    // Delete every user doc for this email — covers both the canonical
    // username-keyed doc and any legacy UID-keyed doc from older Android
    // builds. The cleanupDeletedUser Cloud Function also sweeps related data
    // once the auth user is deleted below.
    const snap = await firestore()
      .collection('users')
      .where('email', '==', user.email.toLowerCase().trim())
      .get();
    await Promise.all(snap.docs.map(doc => doc.ref.delete()));
    await user.delete();
  },

  getCurrentUser() {
    return auth().currentUser;
  },

  onAuthStateChanged(callback: (user: any) => void) {
    return auth().onAuthStateChanged(callback);
  },
};
