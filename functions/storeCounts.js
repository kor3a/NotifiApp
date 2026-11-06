// ---------------------------------------------------------------------------
// Store counts behind the free-tier store limit
//
// Firestore rules can't count documents, so a rule can't ask "how many stores
// does this user have?". This keeps the answer in user_store_counts/{userId},
// which only the Admin SDK can write, and the user_stores create rule in
// firestore.rules reads it.
//
// The count covers every user_stores document with that userId, including stores
// accepted from a share. That is the number the iOS and Android limit checks use.
//
// Deploy order: syncUserStoreCount, then backfillUserStoreCounts (run once from
// the owner account), then the rules. A user with no count document can still
// add stores, so nobody is wrongly blocked at any point in that order.
// ---------------------------------------------------------------------------
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const ADMIN_EMAIL = 'kor3a5@gmail.com';
const FREE_STORE_LIMIT = 5;
const BATCH_SIZE = 400;

// Whose count a write to one user_stores document can change. Reorders and
// sharing updates change nobody's, and those are most writes to this collection.
function userIdsToRecount(before, after) {
    const beforeId = before?.userId;
    const afterId = after?.userId;
    if (beforeId === afterId) {
        return [];
    }
    return [beforeId, afterId].filter((id) => typeof id === 'string' && id);
}

// Counts rather than increments: triggers can run late, twice or out of order,
// and a recount lands on the right number whichever happens. A user with no
// stores left has no document, so deleted accounts leave nothing behind.
async function recountUserStores(db, userId) {
    const snap = await db
        .collection('user_stores')
        .where('userId', '==', userId)
        .count()
        .get();
    const count = snap.data().count;
    const ref = db.collection('user_store_counts').doc(userId);
    if (count === 0) {
        await ref.delete();
    } else {
        await ref.set({ count, updatedAt: FieldValue.serverTimestamp() });
    }
    return count;
}

// Rewrites every count from user_stores, and reports what the rules deploy needs
// to know about. Safe to re-run.
async function backfillCounts(db) {
    const storesSnap = await db.collection('user_stores').select('userId').get();
    const counts = new Map();
    storesSnap.forEach((doc) => {
        const userId = doc.data().userId;
        if (typeof userId === 'string' && userId) {
            counts.set(userId, (counts.get(userId) ?? 0) + 1);
        }
    });

    let batch = db.batch();
    let ops = 0;
    for (const [userId, count] of counts) {
        batch.set(db.collection('user_store_counts').doc(userId), {
            count,
            updatedAt: FieldValue.serverTimestamp(),
        });
        ops += 1;
        if (ops === BATCH_SIZE) {
            await batch.commit();
            batch = db.batch();
            ops = 0;
        }
    }
    if (ops > 0) {
        await batch.commit();
    }

    // The rule looks up premium at users/{userId}. A premium flag on a document
    // keyed any other way (legacy Android docs were keyed by Auth UID) won't be
    // seen, so that user would be held to the free limit. List them to fix first.
    const usersSnap = await db
        .collection('users')
        .select('userId', 'isSubscribed', 'adminSubscribed')
        .get();
    const premiumDocsNotKeyedByUserId = [];
    usersSnap.forEach((doc) => {
        const data = doc.data();
        if (
            (data.isSubscribed === true || data.adminSubscribed === true) &&
            doc.id !== data.userId
        ) {
            premiumDocsNotKeyedByUserId.push(doc.id);
        }
    });

    return {
        users: counts.size,
        stores: storesSnap.size,
        usersAtOrOverFreeLimit: [...counts.values()].filter(
            (count) => count >= FREE_STORE_LIMIT
        ).length,
        premiumDocsNotKeyedByUserId,
    };
}

exports.userIdsToRecount = userIdsToRecount;
exports.recountUserStores = recountUserStores;
exports.backfillCounts = backfillCounts;

exports.syncUserStoreCount = onDocumentWritten(
    { document: 'user_stores/{userStoreId}', maxInstances: 20 },
    async (event) => {
        const userIds = userIdsToRecount(
            event.data?.before?.data(),
            event.data?.after?.data()
        );
        const db = getFirestore();
        await Promise.all(userIds.map((userId) => recountUserStores(db, userId)));
    }
);

exports.backfillUserStoreCounts = onCall({ maxInstances: 20 }, async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign in required.');
    }
    if (request.auth.token.email !== ADMIN_EMAIL) {
        throw new HttpsError('permission-denied', 'Admin only.');
    }
    return backfillCounts(getFirestore());
});
