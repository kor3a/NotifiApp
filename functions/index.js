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
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

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
    if (snap.empty) return null;
    const token = snap.docs[0].data().fcmToken;
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
        await getMessaging().send(message);
    } catch (err) {
        console.error(`FCM send failed for token …${token.slice(-6)}:`, err.message);
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
        if (!recipientUserId) return;

        const token = await getFCMToken(recipientUserId);
        if (!token) return;

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
        if (!recipientUserId) return;

        const token = await getFCMToken(recipientUserId);
        if (!token) return;

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
        if (!conversationId || !senderId) return;

        // Fetch conversation to find all participants except the sender
        const convSnap = await db.collection('conversations').doc(conversationId).get();
        if (!convSnap.exists) return;

        const participantIds = convSnap.data()?.participantIds || [];
        const recipients = participantIds.filter((id) => id !== senderId);
        if (recipients.length === 0) return;

        const preview =
            content && content.length > 100 ? `${content.substring(0, 100)}…` : content || 'Sent you a message';

        await Promise.all(
            recipients.map(async (userId) => {
                const token = await getFCMToken(userId);
                if (!token) return;
                await sendFCM(token, senderName || 'New Message', preview, {
                    type: 'message',
                    conversationId: conversationId,
                });
            })
        );
    }
);

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
        if (!receiverId) return;

        const token = await getFCMToken(receiverId);
        if (!token) return;

        await sendFCM(
            token,
            '👋 Friend Request',
            `${requesterName || 'Someone'} sent you a friend request`,
            { type: 'friend_request' }
        );
    }
);
