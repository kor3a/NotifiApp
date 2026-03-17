const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

// ─── Helpers ────────────────────────────────────────────────────────────────

/**
 * Look up a user's FCM token by email.
 * Returns null if the user is not found or has no token.
 */
async function getFcmTokenByEmail(email) {
  const snap = await db.collection("users")
    .where("email", "==", email)
    .limit(1)
    .get();
  if (snap.empty) return null;
  return snap.docs[0].data().fcmToken || null;
}

/**
 * Look up a user's FCM token by userId (document ID in the users collection).
 */
async function getFcmTokenByUserId(userId) {
  const doc = await db.collection("users").doc(userId).get();
  if (!doc.exists) return null;
  return doc.data().fcmToken || null;
}

/**
 * Send an FCM notification to a single token.
 * Silently ignores unregistered / invalid tokens.
 */
async function sendFcmNotification(token, title, body, data = {}) {
  if (!token) return;
  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      apns: {
        payload: {
          aps: {
            alert: { title, body },
            sound: "default",
            badge: 1,
            // Mark as time-sensitive so it breaks through Focus modes
            "interruption-level": "time-sensitive",
          },
        },
      },
      android: {
        priority: "high",
        notification: { sound: "default" },
      },
      // Custom data so the iOS app can suppress a duplicate local notification
      // when the app is in the foreground (see AppDelegate.swift).
      data: { source: "fcm", ...data },
    });
  } catch (err) {
    // "registration-token-not-registered" means the device uninstalled the app.
    // Log but don't re-throw so one bad token doesn't break the whole function.
    console.error("FCM send error:", err.code || err.message);
  }
}

// ─── Shared Reminder Notifications ──────────────────────────────────────────

/**
 * Triggered when a reminder change notification document is created.
 * Sends an FCM push to the recipient and deletes the Firestore doc.
 *
 * The client-side Firestore listener handles the foreground case; this
 * function handles the app-closed / app-backgrounded case.
 */
exports.onReminderNotificationCreated = onDocumentCreated(
  "reminder_change_notifications/{docId}",
  async (event) => {
    const data = event.data.data();
    const recipientEmail = data.recipientEmail;
    const senderName = data.senderName || "Someone";
    const storeName = data.storeName || "a store";
    const addedCount = data.addedCount || 0;
    const otherChangeCount = data.otherChangeCount || 0;

    // Check whether the doc was already consumed by the client-side listener.
    // If the app was open, it deleted the doc almost immediately; skip FCM.
    const currentSnap = await event.data.ref.get();
    if (!currentSnap.exists) {
      console.log("Reminder notification doc already consumed by client – skipping FCM.");
      return;
    }

    const token = await getFcmTokenByEmail(recipientEmail);
    if (!token) {
      console.log(`No FCM token for ${recipientEmail}`);
      await event.data.ref.delete();
      return;
    }

    // Build a human-readable body that mirrors NotificationManager.swift.
    let body;
    if (addedCount > 0 && otherChangeCount > 0) {
      body = `Added ${addedCount} item${addedCount > 1 ? "s" : ""} and made ${otherChangeCount} other change${otherChangeCount > 1 ? "s" : ""} to ${storeName}`;
    } else if (addedCount > 0) {
      body = `Added ${addedCount} item${addedCount > 1 ? "s" : ""} to ${storeName}`;
    } else {
      body = `Made ${otherChangeCount} change${otherChangeCount > 1 ? "s" : ""} to ${storeName}`;
    }

    await sendFcmNotification(token, senderName, body, { type: "reminder_change", storeName });

    // Delete the doc so the client listener (if it starts later) doesn't
    // show a duplicate notification.
    await event.data.ref.delete();
  }
);

// ─── On My Way Notifications ─────────────────────────────────────────────────

exports.onOnMyWayNotificationCreated = onDocumentCreated(
  "on_my_way_notifications/{docId}",
  async (event) => {
    const data = event.data.data();
    const recipientEmail = data.recipientEmail;
    const senderName = data.senderName || "Someone";
    const storeName = data.storeName || "a store";
    const travelTimeMinutes = data.travelTimeMinutes || 0;

    const currentSnap = await event.data.ref.get();
    if (!currentSnap.exists) {
      console.log("On-my-way notification doc already consumed by client – skipping FCM.");
      return;
    }

    const token = await getFcmTokenByEmail(recipientEmail);
    if (!token) {
      console.log(`No FCM token for ${recipientEmail}`);
      await event.data.ref.delete();
      return;
    }

    const title = `${senderName} is on the way`;
    const body = travelTimeMinutes > 0
      ? `Heading to ${storeName} – arriving in about ${travelTimeMinutes} min`
      : `Heading to ${storeName}`;

    await sendFcmNotification(token, title, body, { type: "on_my_way", storeName });
    await event.data.ref.delete();
  }
);

// ─── Friend Request Notifications ────────────────────────────────────────────

exports.onFriendRequestCreated = onDocumentCreated(
  "friends/{docId}",
  async (event) => {
    const data = event.data.data();

    // Only notify for new pending requests (not acceptances / rejections).
    if (data.status !== "pending") return;

    const receiverId = data.receiverId; // app username = Firestore document ID
    const requesterName = data.requesterName || "Someone";

    const token = await getFcmTokenByUserId(receiverId);
    if (!token) {
      console.log(`No FCM token for user ${receiverId}`);
      return;
    }

    await sendFcmNotification(
      token,
      "New Friend Request",
      `${requesterName} wants to be your friend`,
      { type: "friend_request" }
    );
  }
);

// ─── New Message Notifications ────────────────────────────────────────────────

exports.onMessageCreated = onDocumentCreated(
  "messages/{messageId}",
  async (event) => {
    const data = event.data.data();
    const conversationId = data.conversationId;
    const senderId = data.senderId;       // app username
    const senderName = data.senderName || "Someone";
    const content = data.content || "";

    if (!conversationId) return;

    // Look up the conversation to find the other participant.
    const convDoc = await db.collection("conversations").doc(conversationId).get();
    if (!convDoc.exists) return;

    const participantIds = convDoc.data().participantIds || [];
    const recipients = participantIds.filter((id) => id !== senderId);

    const truncated = content.length > 100 ? content.slice(0, 97) + "…" : content;

    await Promise.all(
      recipients.map(async (recipientId) => {
        const token = await getFcmTokenByUserId(recipientId);
        if (!token) return;
        await sendFcmNotification(
          token,
          senderName,
          truncated,
          { type: "message", conversationId }
        );
      })
    );
  }
);
