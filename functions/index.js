/**
 * Firebase Cloud Functions — NotifiApp background push notifications
 *
 * WHY THIS EXISTS
 * ---------------
 * The iOS app uses Firestore real-time listeners to detect incoming events
 * (messages, friend requests, on-my-way, reminder changes) and then fires local
 * notifications.  iOS suspends the app ~30 s after it moves to the background,
 * which kills those listeners.  When the user reopens the app all queued events
 * arrive at once, causing a burst of notifications.
 *
 * These Cloud Functions watch the same Firestore collections server-side.  When
 * a document is created they look up the recipient's FCM token and push an APNs
 * notification immediately — no running app required.
 *
 * SETUP CHECKLIST (one-time, done in consoles — not in code)
 * -----------------------------------------------------------
 * 1. Firebase Console → Project Settings → Cloud Messaging
 *    Upload your Apple APNs Auth Key (.p8) or APNs Certificate.
 * 2. Xcode → Signing & Capabilities → add "Push Notifications" capability.
 * 3. Xcode → Signing & Capabilities → add "Background Modes" and tick
 *    "Remote notifications".
 * 4. In the Swift Package Manager dependencies already linked in this project,
 *    add the "FirebaseMessaging" library to the app target.
 * 5. Deploy these functions:
 *      cd functions && npm install
 *      firebase deploy --only functions
 *
 * FIRESTORE TOKEN FIELD
 * ---------------------
 * Each user document in the `users` collection must have a `fcmToken` field.
 * FCMTokenManager.swift (added alongside this file) writes/refreshes the token
 * automatically when the app launches or the token rotates.
 */

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const functions = require('firebase-functions');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getStorage } = require('firebase-admin/storage');

initializeApp();

const db = getFirestore();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Look up a user's FCM token by their userId field in the `users` collection.
 * Returns null when no document or no token is found.
 */
async function getFCMToken(userId) {
    const snap = await db
        .collection('users')
        .where('userId', '==', userId)
        .limit(1)
        .get();
    if (snap.empty) {
        console.warn(`getFCMToken: no user document for userId="${userId}"`);
        return null;
    }
    const token = snap.docs[0].data().fcmToken;
    if (!token) {
        console.warn(`getFCMToken: user "${userId}" has no fcmToken field in Firestore`);
    }
    return token || null;
}

/**
 * Send an FCM notification to a single device token.
 * `data` is an optional string→string map forwarded to the app.
 */
async function sendFCM(token, title, body, data = {}) {
    const message = {
        token,
        notification: { title, body },
        // All values in the data map must be strings for FCM
        data: Object.fromEntries(
            Object.entries(data).map(([k, v]) => [k, String(v)])
        ),
        apns: {
            payload: {
                aps: {
                    sound: 'default',
                    // Increment the badge by 1 (FCM handles the actual count)
                    badge: 1,
                    // Allow the app's Notification Service Extension to process
                    // the notification even when the app is suspended
                    'content-available': 1,
                },
            },
        },
    };

    try {
        const response = await getMessaging().send(message);
        console.log(`FCM sent OK — messageId: ${response}, token: …${token.slice(-8)}`);
    } catch (err) {
        console.error(`FCM send FAILED — token: …${token.slice(-8)}, code: ${err.code}, message: ${err.message}`);
        // Common error codes:
        //   messaging/registration-token-not-registered → stale token, app was uninstalled
        //   messaging/invalid-argument → APNs key not uploaded to Firebase Console
        //   messaging/authentication-error → APNs credentials missing/expired in Firebase Console
    }
}

// ---------------------------------------------------------------------------
// 1. "On My Way" notifications
//    Document shape: { recipientUserId, senderName, storeName, travelTimeMinutes, createdAt }
// ---------------------------------------------------------------------------
exports.onMyWayNotification = onDocumentCreated(
    'on_my_way_notifications/{docId}',
    async (event) => {
        const data = event.data?.data();
        if (!data) return;

        const { recipientUserId, senderName, storeName, travelTimeMinutes } = data;
        console.log(`onMyWayNotification fired — docId=${event.params.docId}, recipientUserId=${recipientUserId}`);
        if (!recipientUserId) { console.warn('onMyWayNotification: missing recipientUserId, skipping'); return; }

        const token = await getFCMToken(recipientUserId);
        if (!token) { console.warn(`onMyWayNotification: no token for ${recipientUserId}, skipping`); return; }

        const mins = travelTimeMinutes || 0;
        const body =
            mins > 0
                ? `${senderName} is on their way to ${storeName} (~${mins} min)`
                : `${senderName} is heading to ${storeName}`;

        await sendFCM(token, '🚗 On My Way', body, {
            type: 'on_my_way',
            storeName: storeName || '',
        });
    }
);

// ---------------------------------------------------------------------------
// 2. Shared reminder change notifications
//    Document shape: { recipientUserId, senderName, storeName, addedCount, otherChangeCount, createdAt }
// ---------------------------------------------------------------------------
exports.sharedReminderNotification = onDocumentCreated(
    'reminder_change_notifications/{docId}',
    async (event) => {
        const data = event.data?.data();
        if (!data) return;

        const { recipientUserId, senderName, storeName, addedCount } = data;
        console.log(`sharedReminderNotification fired — docId=${event.params.docId}, recipientUserId=${recipientUserId}`);
        if (!recipientUserId) { console.warn('sharedReminderNotification: missing recipientUserId, skipping'); return; }

        const token = await getFCMToken(recipientUserId);
        if (!token) { console.warn(`sharedReminderNotification: no token for ${recipientUserId}, skipping`); return; }

        const added = addedCount || 0;
        const body =
            added > 0
                ? `${senderName} added ${added} reminder${added > 1 ? 's' : ''} to ${storeName}`
                : `${senderName} updated reminders for ${storeName}`;

        await sendFCM(token, '📝 Reminder Updated', body, {
            type: 'reminder_change',
            storeName: storeName || '',
        });
    }
);

// ---------------------------------------------------------------------------
// 3. New message notifications
//    Document shape: { conversationId, senderId, senderName, content, createdAt, ... }
//    Recipient list is derived from the parent conversation's participantIds.
// ---------------------------------------------------------------------------
exports.newMessageNotification = onDocumentCreated(
    'messages/{docId}',
    async (event) => {
        const data = event.data?.data();
        if (!data) return;

        const { conversationId, senderId, senderName, content } = data;
        console.log(`newMessageNotification fired — docId=${event.params.docId}, conversationId=${conversationId}, senderId=${senderId}`);
        if (!conversationId || !senderId) return;

        // Fetch conversation to find all participants except the sender
        const convSnap = await db.collection('conversations').doc(conversationId).get();
        if (!convSnap.exists) return;

        const participantIds = convSnap.data()?.participantIds || [];
        const recipients = participantIds.filter((id) => id !== senderId);
        if (recipients.length === 0) return;

        const preview =
            content && content.length > 100 ? `${content.substring(0, 100)}…` : content || 'Sent you a message';

        // Use group name as notification title for group conversations
        const isGroup = convSnap.data()?.isGroup === true;
        const groupName = convSnap.data()?.groupName;
        const notificationTitle = isGroup && groupName
            ? groupName
            : (senderName || 'New Message');
        const notificationBody = isGroup
            ? `${senderName || 'Someone'}: ${preview}`
            : preview;

        await Promise.all(
            recipients.map(async (userId) => {
                const token = await getFCMToken(userId);
                if (!token) return;
                await sendFCM(token, notificationTitle, notificationBody, {
                    type: 'message',
                    conversationId: conversationId,
                    isGroup: String(isGroup),
                });
            })
        );
    }
);

// ---------------------------------------------------------------------------
// 5. User account cleanup
//    Triggered when a Firebase Auth user is deleted (from the app, Firebase
//    Console, or any other means).  The admin SDK bypasses Firestore security
//    rules, so this works even after the auth token is gone.
//
//    Deletes:
//      - users/{uid}  document
//      - reminders    where userId == uid
//      - user_stores  where userId == uid
//      - friends      where requesterId == uid  OR  receiverId == uid
//      - friend_requests where requesterId == uid  OR  receiverId == uid
//      - favorite_tags   where userId == uid
//      - profile_pictures/{uid}.jpg  from Cloud Storage
// ---------------------------------------------------------------------------
exports.cleanupDeletedUser = functions.auth.user().onDelete(async (user) => {
    const authUid = user.uid;
    const email = user.email;
    console.log(`cleanupDeletedUser: starting cleanup for authUid=${authUid}, email=${email}`);

    // Firestore documents are keyed by username (the userId field), NOT the Firebase Auth UID.
    // The Auth UID is never stored in Firestore, so we must look up the user document by email.
    const userSnap = await db.collection('users').where('email', '==', email).limit(1).get();
    if (userSnap.empty) {
        console.warn(`cleanupDeletedUser: no Firestore user document found for email=${email} — nothing to clean up`);
        return;
    }

    const userDocRef = userSnap.docs[0].ref;
    const userId = userSnap.docs[0].data().userId; // username used as key in all collections
    console.log(`cleanupDeletedUser: found Firestore userId="${userId}", proceeding with deletion`);

    /**
     * Delete all documents returned by a Firestore Query using batched writes.
     * Batches are capped at 500 operations each (Firestore limit).
     */
    async function deleteQueryResults(query) {
        const snap = await query.get();
        if (snap.empty) return;

        const BATCH_SIZE = 500;
        for (let i = 0; i < snap.docs.length; i += BATCH_SIZE) {
            const batch = db.batch();
            snap.docs.slice(i, i + BATCH_SIZE).forEach((doc) => batch.delete(doc.ref));
            await batch.commit();
        }
    }

    const tasks = [
        // User document (document ID is the username, not the Auth UID)
        userDocRef.delete(),

        // Related documents that reference userId (the username)
        deleteQueryResults(db.collection('reminders').where('userId', '==', userId)),
        deleteQueryResults(db.collection('user_stores').where('userId', '==', userId)),
        deleteQueryResults(db.collection('friends').where('requesterId', '==', userId)),
        deleteQueryResults(db.collection('friends').where('receiverId', '==', userId)),
        deleteQueryResults(db.collection('friend_requests').where('requesterId', '==', userId)),
        deleteQueryResults(db.collection('friend_requests').where('receiverId', '==', userId)),
        deleteQueryResults(db.collection('favorite_tags').where('userId', '==', userId)),
    ];

    // Profile picture — ignore "not found" errors; the file may not exist
    const profilePicTask = getStorage()
        .bucket()
        .file(`profile_pictures/${userId}.jpg`)
        .delete()
        .catch((err) => {
            if (err.code !== 404) console.warn(`cleanupDeletedUser: storage delete error for userId=${userId}:`, err.message);
        });

    await Promise.all([...tasks, profilePicTask]);
    console.log(`cleanupDeletedUser: cleanup complete for userId="${userId}"`);
});

// ---------------------------------------------------------------------------
// 4. Friend request notifications
//    Document shape: { requesterId, requesterName, requesterEmail, receiverId, receiverName, receiverEmail, status, createdAt }
// ---------------------------------------------------------------------------
exports.friendRequestNotification = onDocumentCreated(
    'friends/{docId}',
    async (event) => {
        const data = event.data?.data();
        // Only notify on new *pending* requests
        if (!data || data.status !== 'pending') return;

        const { receiverId, requesterName } = data;
        console.log(`friendRequestNotification fired — docId=${event.params.docId}, receiverId=${receiverId}`);
        if (!receiverId) { console.warn('friendRequestNotification: missing receiverId, skipping'); return; }

        const token = await getFCMToken(receiverId);
        if (!token) { console.warn(`friendRequestNotification: no token for ${receiverId}, skipping`); return; }

        await sendFCM(
            token,
            '👋 Friend Request',
            `${requesterName || 'Someone'} sent you a friend request`,
            { type: 'friend_request' }
        );
    }
);
