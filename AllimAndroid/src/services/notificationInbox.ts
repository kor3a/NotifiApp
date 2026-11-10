import firestore from '@react-native-firebase/firestore';

/**
 * Consumes the notification documents addressed to the signed-in account.
 *
 * Senders write one `reminder_change_notifications` or
 * `on_my_way_notifications` document per recipient, and a Cloud Function turns
 * each new one into an FCM push. Nothing on the server removes them afterwards:
 * the recipient's app does, as the iOS app's SharedReminderNotificationService
 * and OnMyWayNotificationService do. Without this, documents for people who
 * only use Android would pile up forever.
 *
 * Nothing is shown from here. On Android the FCM push is the one delivery
 * path: the system tray shows it while the app is in the background, and
 * App.tsx's onMessage handler shows it while the app is open. A local
 * notification here would be a second copy of the same event. The push
 * function reads the document from its own trigger event, so deleting it
 * straight away cannot cost the recipient their push.
 *
 * The Firestore rules let only the recipient read or delete these documents,
 * matched on the email in their auth token, so `start` must be given the Auth
 * account's email.
 */

export const NOTIFICATION_COLLECTIONS = [
  'reminder_change_notifications',
  'on_my_way_notifications',
] as const;

let activeEmail: string | null = null;
let unsubscribers: (() => void)[] = [];
// Documents already deleted (or being deleted) this session, so a listener that
// reconnects before a pending delete lands doesn't delete them twice.
const processedPaths = new Set<string>();

function listen(collection: string, email: string) {
  return firestore()
    .collection(collection)
    .where('recipientEmail', '==', email)
    .onSnapshot(
      snapshot => {
        if (!snapshot) {
          return;
        }
        snapshot.docChanges().forEach(change => {
          if (change.type !== 'added') {
            return;
          }
          const ref = change.doc.ref;
          if (processedPaths.has(ref.path)) {
            return;
          }
          processedPaths.add(ref.path);
          ref.delete().catch(error => {
            // Let a later snapshot retry it.
            processedPaths.delete(ref.path);
            if (__DEV__) {
              console.warn(`Could not delete ${ref.path}`, error);
            }
          });
        });
      },
      error => {
        // Expected briefly around sign-out, when the listener outlives the
        // credentials it was opened with.
        if (__DEV__) {
          console.warn(`Notification listener on ${collection} failed`, error);
        }
      },
    );
}

export const notificationInbox = {
  /** Starts consuming documents addressed to `email`. Safe to call again. */
  start(email: string) {
    if (email === activeEmail) {
      return;
    }
    notificationInbox.stop();
    activeEmail = email;
    unsubscribers = NOTIFICATION_COLLECTIONS.map(collection =>
      listen(collection, email),
    );
  },

  stop() {
    unsubscribers.forEach(unsubscribe => unsubscribe());
    unsubscribers = [];
    activeEmail = null;
    processedPaths.clear();
  },
};
