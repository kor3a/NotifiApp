import firestore from '@react-native-firebase/firestore';
import auth from '@react-native-firebase/auth';
import {findSharedUsers, SharedStoreRef} from './sharedStoreUsers';

// ─── "Reminder Updated" ──────────────────────────────────────────────────────
//
// Mirrors the iOS SharedReminderNotificationService.sendNotifications: once the
// user leaves a shared store's list (or the app goes to the background), write
// one `reminder_change_notifications` document per other member of the store.
// The `sharedReminderNotification` Cloud Function turns each into a
// "📝 Reminder Updated" push on that member's device.

export interface PendingReminderChanges {
  // Reminders added this editing session.
  addedCount: number;
  // Everything else: toggles, renames, re-categorizing, deletes.
  otherChangeCount: number;
}

export function hasPendingChanges(changes: PendingReminderChanges): boolean {
  return changes.addedCount > 0 || changes.otherChangeCount > 0;
}

// Returns how many people were notified.
export async function sendReminderChangeNotifications(params: {
  store: SharedStoreRef;
  storeName: string;
  changes: PendingReminderChanges;
  currentUserId: string;
  currentUserName: string;
}): Promise<number> {
  const {store, storeName, changes, currentUserId, currentUserName} = params;
  if (!hasPendingChanges(changes)) {
    return 0;
  }

  // Verified sender identity: the rules reject a senderEmail that isn't the
  // caller's, and the push function resolves the display name from it rather
  // than trusting senderName.
  const senderEmail = auth().currentUser?.email ?? undefined;

  const recipients = (
    await findSharedUsers(store, currentUserId, {
      respectNotificationPreference: true,
    })
  ).filter(
    // Never notify the sender, even through a second account entry that
    // carries their email under another userId.
    user =>
      !senderEmail ||
      user.email.trim().toLowerCase() !== senderEmail.trim().toLowerCase(),
  );
  if (recipients.length === 0) {
    return 0;
  }

  const batch = firestore().batch();
  const now = Date.now() / 1000;

  recipients.forEach(user => {
    const ref = firestore().collection('reminder_change_notifications').doc();
    const payload: {[key: string]: any} = {
      recipientUserId: user.userId,
      recipientEmail: user.email,
      senderName: currentUserName,
      storeName,
      addedCount: changes.addedCount,
      otherChangeCount: changes.otherChangeCount,
      createdAt: now,
    };
    if (senderEmail) {
      payload.senderEmail = senderEmail;
    }
    batch.set(ref, payload);
  });

  await batch.commit();
  return recipients.length;
}
