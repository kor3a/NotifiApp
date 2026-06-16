import auth from '@react-native-firebase/auth';
import firestore from '@react-native-firebase/firestore';
import functions from '@react-native-firebase/functions';

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

    // Create user document in Firestore
    await firestore().collection('users').doc(result.user.uid).set({
      userId: userId,
      firebaseUid: result.user.uid,
      name: name,
      email: email,
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
    await auth().signOut();
  },

  // Delete account
  async deleteAccount(password: string): Promise<void> {
    const user = auth().currentUser;
    if (!user || !user.email) {throw new Error('No user');}
    const credential = auth.EmailAuthProvider.credential(user.email, password);
    await user.reauthenticateWithCredential(credential);

    // Delete Firestore user doc
    await firestore().collection('users').doc(user.uid).delete();
    await user.delete();
  },

  getCurrentUser() {
    return auth().currentUser;
  },

  onAuthStateChanged(callback: (user: any) => void) {
    return auth().onAuthStateChanged(callback);
  },
};
