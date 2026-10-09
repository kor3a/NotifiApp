import AsyncStorage from '@react-native-async-storage/async-storage';
import firestore from '@react-native-firebase/firestore';
import notifee from '@notifee/react-native';
import {backgroundPreferences} from './backgroundPreferences';

/**
 * Wipes what the signed-out account left on the device, so the next person to
 * sign in here starts from nothing of theirs: no Firestore documents in the
 * offline cache, no preferences in storage, no notifications in the tray.
 *
 * Run once a session has ended — sign-out, account deletion, or a revoked
 * session — after the auth state has already flipped to signed out.
 */

// Device-level flags that are kept. Both are keyed by Auth UID and record only
// that this device has walked that account through the permission primers and
// the tour — nothing about the account itself — so keeping them just stops the
// same person being shown either again.
const KEPT_KEY_PREFIXES = [
  'hasCompletedPermissionOnboarding_auth_',
  'hasCompletedTutorial_auth_',
];

async function clearStorage() {
  const keys = await AsyncStorage.getAllKeys();
  const toRemove = keys.filter(
    key => !KEPT_KEY_PREFIXES.some(prefix => key.startsWith(prefix)),
  );
  if (toRemove.length > 0) {
    await AsyncStorage.multiRemove(toRemove);
  }
}

/**
 * Firestore keeps every document it has read on disk for offline use. Clearing
 * that cache needs the instance shut down first; the next `firestore()` call
 * starts a fresh one.
 */
async function clearFirestoreCache() {
  await firestore().terminate();
  await firestore().clearPersistence();
}

/** Reminders and messages addressed to the previous account. */
async function clearNotifications() {
  await notifee.cancelAllNotifications();
  await notifee.setBadgeCount(0);
}

export async function clearSignedOutUserData(): Promise<void> {
  // In-memory copies first, so nothing on screen can read them back while the
  // disk work runs.
  backgroundPreferences.clearCache();
  // Independent of each other: one failing (say, the notification service) must
  // not leave the others undone.
  const results = await Promise.allSettled([
    clearStorage(),
    clearFirestoreCache(),
    clearNotifications(),
  ]);
  if (__DEV__) {
    results.forEach(result => {
      if (result.status === 'rejected') {
        console.warn('Sign-out cleanup step failed:', result.reason);
      }
    });
  }
}
