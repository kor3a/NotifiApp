import firestore from '@react-native-firebase/firestore';
import storage from '@react-native-firebase/storage';
import auth from '@react-native-firebase/auth';
import {User} from '../models';

export const userService = {
  // Fetch user by Firebase UID
  async fetchUserByUid(uid: string): Promise<User | null> {
    const snap = await firestore().collection('users').doc(uid).get();
    if (!snap.exists) {return null;}
    return {id: snap.id, ...snap.data()} as unknown as User;
  },

  // Subscribe to user changes
  subscribeToUser(uid: string, callback: (user: User | null) => void) {
    return firestore()
      .collection('users')
      .doc(uid)
      .onSnapshot(snap => {
        if (!snap.exists) {
          callback(null);
          return;
        }
        callback({...snap.data()} as User);
      });
  },

  // Update profile
  async updateProfile(uid: string, updates: Partial<User>): Promise<void> {
    await firestore().collection('users').doc(uid).update(updates);
  },

  // Upload profile picture
  async uploadProfilePicture(uid: string, uri: string): Promise<string> {
    const ref = storage().ref(`profile_pictures/${uid}.jpg`);
    await ref.putFile(uri);
    const url = await ref.getDownloadURL();
    await firestore()
      .collection('users')
      .doc(uid)
      .update({profilePictureURL: url});
    return url;
  },

  // Save FCM token
  async saveFCMToken(uid: string, token: string): Promise<void> {
    await firestore().collection('users').doc(uid).update({fcmToken: token});
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
