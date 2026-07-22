import firestore, {FirebaseFirestoreTypes} from '@react-native-firebase/firestore';
import storage from '@react-native-firebase/storage';
import {User} from '../models';

// The `users` collection is keyed by the lowercased username (the `userId`
// field) to match the iOS app — one document per person across platforms, so
// Cloud Functions that look users up by userId or email resolve a single doc
// (push tokens, account cleanup, sender-name resolution).
//
// Legacy Android builds keyed these docs by Firebase Auth UID instead. All
// lookups therefore go through an email query — which finds both keying
// schemes — and prefer the canonical username-keyed doc when a user has one
// of each (e.g. signed up on Android, later used iOS).

async function findUserDocByEmail(
  email: string,
): Promise<FirebaseFirestoreTypes.QueryDocumentSnapshot | null> {
  const snap = await firestore()
    .collection('users')
    .where('email', '==', email.toLowerCase().trim())
    .get();
  if (snap.empty) {
    return null;
  }
  const canonical = snap.docs.find(
    doc => doc.id === (doc.data() as User).userId,
  );
  return canonical ?? snap.docs[0];
}

export const userService = {
  // Fetch the user document for an email (auth identity)
  async fetchUserByEmail(email: string): Promise<User | null> {
    const doc = await findUserDocByEmail(email);
    if (!doc) {
      return null;
    }
    return {id: doc.id, ...doc.data()} as unknown as User;
  },

  // Subscribe to user changes (by email, resilient to either doc keying)
  subscribeToUser(email: string, callback: (user: User | null) => void) {
    return firestore()
      .collection('users')
      .where('email', '==', email.toLowerCase().trim())
      .onSnapshot(snap => {
        if (!snap || snap.empty) {
          callback(null);
          return;
        }
        const canonical =
          snap.docs.find(doc => doc.id === (doc.data() as User).userId) ??
          snap.docs[0];
        callback({...canonical.data()} as User);
      });
  },

  // Update profile
  async updateProfile(email: string, updates: Partial<User>): Promise<void> {
    const doc = await findUserDocByEmail(email);
    if (!doc) {
      throw new Error('User profile not found.');
    }
    await doc.ref.update(updates);
  },

  // Upload profile picture. The storage path is keyed by username to match
  // iOS and the cleanupDeletedUser Cloud Function (profile_pictures/{userId}.jpg).
  async uploadProfilePicture(
    email: string,
    userId: string,
    uri: string,
  ): Promise<string> {
    const ref = storage().ref(`profile_pictures/${userId}.jpg`);
    await ref.putFile(uri);
    const url = await ref.getDownloadURL();
    await userService.updateProfile(email, {profilePictureURL: url});
    return url;
  },

  // Save FCM token to the account's document
  async saveFCMToken(email: string, token: string): Promise<void> {
    const doc = await findUserDocByEmail(email);
    if (!doc) {
      return;
    }
    await doc.ref.update({fcmToken: token});
  },

  // Remove the FCM token from the account's document (called before sign-out,
  // while the rules still allow updating the user's own document)
  async clearFCMToken(email: string): Promise<void> {
    const doc = await findUserDocByEmail(email);
    if (!doc) {
      return;
    }
    await doc.ref.update({fcmToken: firestore.FieldValue.delete()});
  },

  // Search users by email
  async searchUsersByEmail(email: string): Promise<User[]> {
    const snap = await firestore()
      .collection('users')
      .where('email', '==', email.toLowerCase().trim())
      .get();
    return snap.docs.map(d => ({...d.data()} as User));
  },
};
