import auth from '@react-native-firebase/auth';
import firestore from '@react-native-firebase/firestore';

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
    const result = await auth().createUserWithEmailAndPassword(email, password);
    await result.user.sendEmailVerification();

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
    await user.sendEmailVerification();
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
