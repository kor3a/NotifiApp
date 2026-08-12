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
  // Fetch the profile for a signed-in account by email.
  // The `users` collection is keyed by username (matching the iOS app), not by
  // the Firebase Auth UID, so we must look the profile up by email — the same
  // mapping the iOS app uses to go from an authenticated account to its doc.
  async fetchUserByEmail(email: string): Promise<User | null> {
    const doc = await findUserDocByEmail(email);
    if (!doc) {
      return null;
    }
    return {id: doc.id, ...doc.data()} as unknown as User;
  },

  // Subscribe to user changes
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

  // Update profile. userId is the users doc id (username), not the auth uid.
  async updateProfile(userId: string, updates: Partial<User>): Promise<void> {
    await firestore().collection('users').doc(userId).update(updates);
  },

  // Upload profile picture. userId is the users doc id (username), matching the
  // iOS storage path (profile_pictures/{username}.jpg).
  async uploadProfilePicture(userId: string, uri: string): Promise<string> {
    const ref = storage().ref(`profile_pictures/${userId}.jpg`);
    await ref.putFile(uri);
    const url = await ref.getDownloadURL();
    await firestore()
      .collection('users')
      .doc(userId)
      .update({profilePictureURL: url});
    return url;
  },

  // Save FCM token. userId is the users doc id (username), not the auth uid.
  async saveFCMToken(userId: string, token: string): Promise<void> {
    await firestore().collection('users').doc(userId).update({fcmToken: token});
  },

  // Drop this device's push token from the signed-in user's doc on sign-out, so
  // pushes for the account stop targeting a device it no longer occupies.
  // Looked up by email (docs are keyed by username), mirroring iOS's
  // FCMTokenManager.clearToken. Must run while still authenticated — the rules
  // only allow a user to update their own document.
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
