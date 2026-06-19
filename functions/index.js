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
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const functions = require('firebase-functions');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getStorage } = require('firebase-admin/storage');
const { getAuth } = require('firebase-admin/auth');

initializeApp();

// Resend API key — set once with:  firebase functions:secrets:set RESEND_API_KEY
const RESEND_API_KEY = defineSecret('RESEND_API_KEY');

// Sender address for verification emails. MUST be on a domain you've verified in
// Resend (https://resend.com/domains). For quick testing Resend also allows
// "onboarding@resend.dev", but that can only deliver to your own Resend account
// email. Set this in production via functions/.env (see .env.example) — Firebase
// loads that file into process.env at deploy time. A shell `export` before
// `firebase deploy` does NOT reach the deployed Gen-2 runtime.
const VERIFICATION_FROM_EMAIL =
    process.env.VERIFICATION_FROM_EMAIL || 'Allim <onboarding@resend.dev>';

// Sender + destination for in-app "Report & Feedback" submissions. The sender
// MUST be on a domain you've verified in Resend (the onboarding@resend.dev
// fallback only delivers to your own Resend account email — fine for testing).
// Set both in functions/.env (see .env.example). FEEDBACK_TO_EMAIL is the inbox
// that receives user reports.
const FEEDBACK_FROM_EMAIL =
    process.env.FEEDBACK_FROM_EMAIL || 'Allim Feedback <onboarding@resend.dev>';
const FEEDBACK_TO_EMAIL =
    process.env.FEEDBACK_TO_EMAIL || 'jjamesubongdev@gmail.com';

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
 *
 * @param {string} token  Recipient device's FCM registration token.
 * @param {string} title  Notification title.
 * @param {string} body   Notification body.
 * @param {Object} data    Optional string→string map forwarded to the app.
 * @param {Object} options Optional APNs tuning:
 *   - category {string}          APNs category. MUST match an identifier
 *       registered in NotificationManager.registerNotificationCategories.
 *       CarPlay visibility is decided app-side: only categories created with
 *       the `.allowInCarPlay` option surface on the CarPlay screen. Setting the
 *       category here also lets notification taps route correctly when the app
 *       is cold-launched from a push (the delegate falls back to `data.type`
 *       only when no categoryIdentifier is present).
 *   - interruptionLevel {string} APNs interruption level. Defaults to
 *       'time-sensitive' so reminders break through Focus modes — including the
 *       Driving Focus that CarPlay auto-enables. Requires the
 *       com.apple.developer.usernotifications.time-sensitive entitlement
 *       (already present on the app target).
 *   - threadId {string}          APNs thread id used to group related banners
 *       (e.g. all pushes for one store or conversation).
 *   - mutableContent {boolean}   When true, sets aps.mutable-content so the
 *       NotifiNotificationService extension can intercept and rewrite the
 *       notification (used to turn message pushes into communication
 *       notifications that are CarPlay-safe).
 */
async function sendFCM(token, title, body, data = {}, options = {}) {
    const aps = {
        sound: 'default',
        // Increment the badge by 1 (FCM handles the actual count)
        badge: 1,
        // Default to time-sensitive so the notification is delivered even while
        // Driving Focus is active. Callers can override per notification type.
        'interruption-level': options.interruptionLevel || 'time-sensitive',
    };
    if (options.category) {
        aps.category = options.category;
    }
    if (options.threadId) {
        aps['thread-id'] = options.threadId;
    }
    if (options.mutableContent) {
        aps['mutable-content'] = 1;
    }

    const message = {
        token,
        notification: { title, body },
        // All values in the data map must be strings for FCM
        data: Object.fromEntries(
            Object.entries(data).map(([k, v]) => [k, String(v)])
        ),
        apns: {
            payload: { aps },
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
        }, {
            // ON_MY_WAY is registered with .allowInCarPlay — shows on CarPlay.
            category: 'ON_MY_WAY',
            threadId: `on-my-way-${storeName || ''}`,
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
        }, {
            // SHARED_REMINDER_CHANGE is registered with .allowInCarPlay.
            category: 'SHARED_REMINDER_CHANGE',
            threadId: `shared-reminder-${storeName || ''}`,
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
                    // Sender / group name forwarded so the NotifiNotificationService
                    // extension can build the INSendMessageIntent without parsing
                    // the (localized) title.
                    senderName: senderName || '',
                    groupName: groupName || '',
                }, {
                    // mutable-content lets the NotifiNotificationService extension
                    // rewrite this push into a communication notification, which
                    // renders sender-only on CarPlay (message body never shown).
                    // The NEW_MESSAGE category must be registered WITH
                    // .allowInCarPlay for CarPlay display — do that only once the
                    // extension target is in the build (see the runbook), so the
                    // raw body is never exposed on CarPlay in the meantime.
                    category: 'NEW_MESSAGE',
                    threadId: conversationId,
                    mutableContent: true,
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
            { type: 'friend_request' },
            // FRIEND_REQUEST is registered with .allowInCarPlay.
            { category: 'FRIEND_REQUEST' }
        );
    }
);

// ---------------------------------------------------------------------------
// 6. Custom email verification
//
// WHY THIS EXISTS
// ---------------
// Firebase Auth's built-in verification email uses a locked template whose
// message body cannot be edited ("To help prevent spam, the message can't be
// edited on this email template"). The default body renders the link as a bare
// URL, which desktop mail clients auto-link but many MOBILE clients leave as
// plain, un-tappable text.
//
// To control the markup — and guarantee a real, tappable <a href> button on
// phones — we generate the verification link with the Admin SDK and send our
// own HTML email through Resend instead of calling user.sendEmailVerification()
// from the client.
//
// The link still points at Firebase's standard action handler, so the existing
// emailVerified flow (LoginScreen) keeps working unchanged.
//
// Callable from the app via:  functions().httpsCallable('sendVerificationEmail')()
// The caller must be signed in (true right after createUserWithEmailAndPassword).
// ---------------------------------------------------------------------------

/**
 * Build the verification email HTML. The link is wrapped in an explicit <a>
 * anchor styled as a button so every mail client — mobile included — renders it
 * as a tap target, with the raw URL repeated below as a copy/paste fallback.
 */
function buildVerificationEmailHtml(link) {
    return `<!DOCTYPE html>
<html>
  <body style="margin:0;padding:0;background:#f4f4f7;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f7;padding:24px 0;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border-radius:12px;padding:32px;">
            <tr>
              <td style="font-size:20px;font-weight:700;color:#111827;padding-bottom:12px;">
                Confirm your email
              </td>
            </tr>
            <tr>
              <td style="font-size:15px;line-height:22px;color:#374151;padding-bottom:24px;">
                Thanks for signing up for Allim. Tap the button below to verify your email address and finish setting up your account.
              </td>
            </tr>
            <tr>
              <td align="center" style="padding-bottom:24px;">
                <a href="${link}"
                   style="display:inline-block;background:#2563eb;color:#ffffff;font-size:16px;font-weight:600;text-decoration:none;padding:14px 28px;border-radius:8px;">
                  Verify my email
                </a>
              </td>
            </tr>
            <tr>
              <td style="font-size:13px;line-height:20px;color:#6b7280;padding-bottom:8px;">
                If the button doesn't work, copy and paste this link into your browser:
              </td>
            </tr>
            <tr>
              <td style="font-size:13px;line-height:20px;word-break:break-all;">
                <a href="${link}" style="color:#2563eb;">${link}</a>
              </td>
            </tr>
            <tr>
              <td style="font-size:12px;line-height:18px;color:#9ca3af;padding-top:24px;">
                If you didn't create an Allim account, you can safely ignore this email.
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

/**
 * Generate a fresh verification link for `email` and deliver our custom HTML
 * email through Resend. Shared by `sendVerificationEmail` (authenticated resend)
 * and `checkEmailVerificationStatus` (unauthenticated resend during signup).
 *
 * Throws an HttpsError on failure so callers can surface a consistent error.
 */
async function deliverVerificationEmail(email) {
    // Generate the verification link using Firebase's standard action handler.
    let link;
    try {
        link = await getAuth().generateEmailVerificationLink(email);
    } catch (err) {
        console.error('deliverVerificationEmail: failed to generate link', err);
        throw new HttpsError('internal', 'Could not generate verification link.');
    }

    // Send our own custom HTML email via Resend.
    const { Resend } = require('resend');
    const resend = new Resend(RESEND_API_KEY.value());

    const { error } = await resend.emails.send({
        from: VERIFICATION_FROM_EMAIL,
        to: email,
        subject: 'Verify your email for Allim',
        html: buildVerificationEmailHtml(link),
        text:
            `Confirm your email for Allim by opening this link:\n\n${link}\n\n` +
            `If you didn't create an Allim account, you can ignore this email.`,
    });

    if (error) {
        console.error('deliverVerificationEmail: Resend send failed', error);
        throw new HttpsError('internal', 'Failed to send verification email.');
    }

    console.log(`deliverVerificationEmail: verification email sent to ${email}`);
}

exports.sendVerificationEmail = onCall(
    { secrets: [RESEND_API_KEY] },
    async (request) => {
        const auth = request.auth;
        if (!auth) {
            throw new HttpsError(
                'unauthenticated',
                'You must be signed in to request a verification email.'
            );
        }

        const email = auth.token.email;
        if (!email) {
            throw new HttpsError(
                'failed-precondition',
                'This account has no email address.'
            );
        }

        // Nothing to do if the address is already verified.
        if (auth.token.email_verified) {
            console.log(`sendVerificationEmail: ${email} already verified, skipping`);
            return { status: 'already_verified' };
        }

        await deliverVerificationEmail(email);
        return { status: 'sent' };
    }
);

// ---------------------------------------------------------------------------
// 7. Email verification status check (signup "email pending verification" UX)
//
// WHY THIS EXISTS
// ---------------
// When someone starts signing up but never confirms their email, their Firebase
// Auth account (and Firestore user doc) still exist. A later signup attempt with
// the same address fails with `auth/email-already-in-use`, which reads to the
// user as "this email is taken" — confusing when it's *their own* unconfirmed
// account.
//
// The client can't tell a verified account apart from an unverified one: Firebase
// Auth deliberately hides `emailVerified` from unauthenticated callers (and the
// signer-up doesn't necessarily know the original password). This callable uses
// the Admin SDK to look it up and, when the account is unverified, re-sends the
// verification link so the user can simply finish what they started.
//
// Callable from the app via:
//   functions().httpsCallable('checkEmailVerificationStatus')({ email })
//
// NOTE: This intentionally reveals whether an email is registered/verified, which
// is the product requirement here. The work it does (an Auth lookup plus, for
// unverified accounts, one email) is the same a normal signup attempt triggers,
// so it doesn't add meaningful enumeration or spam surface beyond signup itself.
// ---------------------------------------------------------------------------
exports.checkEmailVerificationStatus = onCall(
    { secrets: [RESEND_API_KEY] },
    async (request) => {
        const rawEmail = request.data?.email;
        if (!rawEmail || typeof rawEmail !== 'string') {
            throw new HttpsError(
                'invalid-argument',
                'An email address is required.'
            );
        }
        const email = rawEmail.trim().toLowerCase();

        let userRecord;
        try {
            userRecord = await getAuth().getUserByEmail(email);
        } catch (err) {
            if (err.code === 'auth/user-not-found') {
                // No account exists for this email — it's available to register.
                return { status: 'available' };
            }
            console.error('checkEmailVerificationStatus: lookup failed', err);
            throw new HttpsError('internal', 'Could not check this email address.');
        }

        if (userRecord.emailVerified) {
            return { status: 'verified' };
        }

        // Unverified account: re-send the verification link so they can finish
        // signing up. Surface a 'pending' status even if the resend itself fails,
        // so the app can still explain why signup was blocked.
        let resent = false;
        try {
            await deliverVerificationEmail(email);
            resent = true;
        } catch (err) {
            console.error('checkEmailVerificationStatus: resend failed', err);
        }
        return { status: 'pending', resent };
    }
);

// ---------------------------------------------------------------------------
// 8. In-app "Report & Feedback" submissions
//
// WHY THIS EXISTS
// ---------------
// The Report & Feedback screen used to hand off to the system Mail app via a
// mailto: link, which fails silently on devices with no mail account and forces
// the user to leave the app. Instead the app now calls this function directly:
// the user stays in the app, gets an immediate success/failure result, and the
// feedback is both archived in Firestore and emailed to the team via Resend.
//
// Callable from the app via:
//   functions().httpsCallable('submitFeedback')({ category, message, appVersion })
// The caller must be signed in.
// ---------------------------------------------------------------------------

const ALLOWED_FEEDBACK_CATEGORIES = [
    'General Feedback',
    'Report a Bug',
    'Feature Request',
];
const MAX_FEEDBACK_LENGTH = 5000;

/** Minimal HTML-escape so user text can't inject markup into the email body. */
function escapeHtml(str) {
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

/** Build the feedback notification email sent to the team inbox. */
function buildFeedbackEmailHtml({ category, message, reporterName, reporterEmail, reporterUserId, appVersion }) {
    const safeMessage = escapeHtml(message).replace(/\n/g, '<br>');
    const row = (label, value) => `
            <tr>
              <td style="font-size:13px;color:#6b7280;padding:4px 12px 4px 0;white-space:nowrap;vertical-align:top;">${label}</td>
              <td style="font-size:14px;color:#111827;padding:4px 0;">${escapeHtml(value || '—')}</td>
            </tr>`;
    return `<!DOCTYPE html>
<html>
  <body style="margin:0;padding:0;background:#f4f4f7;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f7;padding:24px 0;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#ffffff;border-radius:12px;padding:32px;">
            <tr>
              <td style="font-size:20px;font-weight:700;color:#111827;padding-bottom:4px;">
                New ${escapeHtml(category)}
              </td>
            </tr>
            <tr>
              <td style="font-size:13px;color:#6b7280;padding-bottom:20px;">
                Submitted from the Allim app
              </td>
            </tr>
            <tr>
              <td style="padding-bottom:20px;">
                <table role="presentation" cellpadding="0" cellspacing="0">
                  ${row('Category', category)}
                  ${row('From', reporterName)}
                  ${row('Email', reporterEmail)}
                  ${row('Username', reporterUserId)}
                  ${row('App version', appVersion)}
                </table>
              </td>
            </tr>
            <tr>
              <td style="font-size:13px;font-weight:600;color:#6b7280;padding-bottom:8px;text-transform:uppercase;letter-spacing:0.5px;">
                Message
              </td>
            </tr>
            <tr>
              <td style="font-size:15px;line-height:22px;color:#111827;background:#f9fafb;border-radius:8px;padding:16px;">
                ${safeMessage}
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

exports.submitFeedback = onCall(
    { secrets: [RESEND_API_KEY] },
    async (request) => {
        const auth = request.auth;
        if (!auth) {
            throw new HttpsError(
                'unauthenticated',
                'You must be signed in to send feedback.'
            );
        }

        // Validate inputs.
        const category = String(request.data?.category || '').trim();
        const message = String(request.data?.message || '').trim();
        const appVersion = String(request.data?.appVersion || '').trim().slice(0, 50);

        if (!ALLOWED_FEEDBACK_CATEGORIES.includes(category)) {
            throw new HttpsError('invalid-argument', 'Unknown feedback category.');
        }
        if (!message) {
            throw new HttpsError('invalid-argument', 'The message cannot be empty.');
        }
        if (message.length > MAX_FEEDBACK_LENGTH) {
            throw new HttpsError(
                'invalid-argument',
                `The message is too long (max ${MAX_FEEDBACK_LENGTH} characters).`
            );
        }

        // Reporter identity comes from the verified auth token (email is trusted);
        // the human-readable name/username are best-effort from the client.
        const reporterEmail = auth.token.email || '';
        const reporterName = String(request.data?.reporterName || '').trim().slice(0, 200);
        const reporterUserId = String(request.data?.reporterUserId || '').trim().slice(0, 200);

        // Archive the submission first so nothing is lost even if email delivery
        // fails. The Admin SDK bypasses Firestore security rules.
        const docRef = await db.collection('feedback').add({
            category,
            message,
            appVersion: appVersion || null,
            reporterAuthUid: auth.uid,
            reporterEmail,
            reporterName: reporterName || null,
            reporterUserId: reporterUserId || null,
            status: 'pending',
            createdAt: new Date(),
        });

        // Email the team inbox via Resend.
        const { Resend } = require('resend');
        const resend = new Resend(RESEND_API_KEY.value());

        const { error } = await resend.emails.send({
            from: FEEDBACK_FROM_EMAIL,
            to: FEEDBACK_TO_EMAIL,
            // Let the team reply straight to the user when an address is present.
            replyTo: reporterEmail || undefined,
            subject: `[Allim ${category}] from ${reporterName || reporterEmail || 'a user'}`,
            html: buildFeedbackEmailHtml({
                category, message, reporterName, reporterEmail, reporterUserId, appVersion,
            }),
            text:
                `New ${category} from the Allim app\n\n` +
                `From: ${reporterName || '—'}\n` +
                `Email: ${reporterEmail || '—'}\n` +
                `Username: ${reporterUserId || '—'}\n` +
                `App version: ${appVersion || '—'}\n\n` +
                `Message:\n${message}\n`,
        });

        if (error) {
            console.error('submitFeedback: Resend send failed', error);
            await docRef.update({ status: 'email_failed' }).catch(() => {});
            throw new HttpsError('internal', 'Could not send your feedback. Please try again.');
        }

        await docRef.update({ status: 'sent' }).catch(() => {});
        console.log(`submitFeedback: feedback ${docRef.id} sent (category="${category}")`);
        return { status: 'sent' };
    }
);
