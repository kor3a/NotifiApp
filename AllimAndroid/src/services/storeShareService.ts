import firestore, {
  FirebaseFirestoreTypes,
} from '@react-native-firebase/firestore';
import {
  LinkedStore,
  Message,
  SharedStoreUser,
  User,
  UserStoreItem,
  reminderStoreIdFor,
} from '../models';
import {messageService} from './messageService';

// Store sharing is request-based, mirroring the iOS app: the owner sends a
// message carrying a `linkedStore` payload, and the recipient accepts or
// declines it from the conversation. Accepting is what creates the recipient's
// user_store — nothing is written to the recipient's account before that.

function nowSeconds(): number {
  return Date.now() / 1000;
}

function titleKey(title: string): string {
  return title.toLowerCase().trim();
}

// Active reminders for a store. The isDone filter is applied in JS rather than
// in the query so this needs no composite index.
async function activeReminders(userStoreId: string) {
  const snap = await firestore()
    .collection('reminders')
    .where('userStoreId', '==', userStoreId)
    .get();
  return snap.docs.filter(d => d.data().isDone !== true);
}

// Flag every active reminder in the owner's store as shared with `recipientName`
// so both sides show the shared badge. Recipients read the owner's reminder docs
// directly (via sourceUserStoreId), so marking the owner's copies is enough.
// Idempotent — re-running it leaves already-marked reminders untouched.
async function markRemindersAsShared(
  ownerUserStoreId: string,
  recipientName: string,
): Promise<void> {
  const docs = await activeReminders(ownerUserStoreId);
  if (docs.length === 0) {
    return;
  }
  const batch = firestore().batch();
  docs.forEach(doc => {
    batch.update(doc.ref, {
      isShared: true,
      sharedWith: firestore.FieldValue.arrayUnion(recipientName),
    });
  });
  await batch.commit();
}

// Carry a reminder's optional fields onto a copy in another store. `order` is
// this app's field and `sortOrder` is the iOS one; whichever the source has is
// preserved so the copy lands in a sensible position on both platforms.
function copyableFields(data: FirebaseFirestoreTypes.DocumentData) {
  const copy: {[key: string]: any} = {};
  ['quantity', 'category', 'order', 'sortOrder', 'photoURLs'].forEach(field => {
    if (data[field] !== undefined) {
      copy[field] = data[field];
    }
  });
  return copy;
}

// Bidirectional merge for when the recipient already owns the same store:
// unique reminders are copied both ways, shared metadata is stamped on both
// lists, and the two user_store docs are linked so each side shows the other.
async function mergeStoreReminders(params: {
  recipientUserStoreId: string;
  ownerUserStoreId: string;
  ownerName: string;
  ownerUserId: string;
  ownerEmail: string;
  recipientUserId: string;
  recipientEmail: string;
  recipientName: string;
}): Promise<void> {
  const remindersRef = firestore().collection('reminders');
  const recipientDocs = await activeReminders(params.recipientUserStoreId);
  const ownerDocs = await activeReminders(params.ownerUserStoreId);

  const recipientTitles = new Set(
    recipientDocs.map(d => titleKey(d.data().title ?? '')),
  );
  const ownerTitles = new Set(ownerDocs.map(d => titleKey(d.data().title ?? '')));

  const batch = firestore().batch();

  // Owner's unique reminders → recipient's store.
  ownerDocs.forEach(doc => {
    const data = doc.data();
    const title: string | undefined = data.title;
    if (!title || recipientTitles.has(titleKey(title))) {
      return;
    }
    batch.set(remindersRef.doc(), {
      userStoreId: params.recipientUserStoreId,
      title,
      isDone: false,
      createdAt: nowSeconds(),
      isShared: true,
      sharedFrom: params.ownerName,
      sharedFromId: params.ownerUserId,
      sharedAt: nowSeconds(),
      ...copyableFields(data),
    });
  });

  // Recipient's existing reminders: items the owner also has are attributed to
  // the owner, the rest are marked as shared with them.
  recipientDocs.forEach(doc => {
    const data = doc.data();
    const title: string | undefined = data.title;
    if (!title) {
      return;
    }
    if (ownerTitles.has(titleKey(title))) {
      batch.update(doc.ref, {
        isShared: true,
        sharedFrom: params.ownerName,
        sharedFromId: params.ownerUserId,
      });
    } else {
      batch.update(doc.ref, {
        isShared: true,
        sharedWith: firestore.FieldValue.arrayUnion(params.ownerName),
      });
    }
  });

  // Recipient's unique reminders → owner's store.
  recipientDocs.forEach(doc => {
    const data = doc.data();
    const title: string | undefined = data.title;
    if (!title || ownerTitles.has(titleKey(title))) {
      return;
    }
    batch.set(remindersRef.doc(), {
      userStoreId: params.ownerUserStoreId,
      title,
      isDone: false,
      createdAt: nowSeconds(),
      isShared: true,
      sharedFrom: params.recipientName,
      sharedFromId: params.recipientUserId,
      sharedAt: nowSeconds(),
      ...copyableFields(data),
    });
  });

  const userStores = firestore().collection('user_stores');

  // The owner's list shows the store as shared…
  batch.update(userStores.doc(params.ownerUserStoreId), {
    sharedWith: firestore.FieldValue.arrayUnion(params.recipientName),
  });

  // …and the recipient keeps their own store (permission stays owner, so their
  // reminders keep living in their own doc) while recording the link back to
  // the owner. sharedFrom/sharedFromEmail are what let the Firestore rules
  // authorise the owner to clean this doc up if they unshare later.
  batch.update(userStores.doc(params.recipientUserStoreId), {
    sourceUserStoreId: params.ownerUserStoreId,
    userName: params.recipientName,
    userEmail: params.recipientEmail,
    sharedWith: firestore.FieldValue.arrayUnion(params.ownerName),
    sharedFromName: params.ownerName,
    sharedFrom: params.ownerUserId,
    sharedFromEmail: params.ownerEmail,
  });

  await batch.commit();
}

async function setLinkedStoreStatus(
  messageId: string,
  status: 'accepted' | 'rejected',
): Promise<void> {
  await firestore()
    .collection('messages')
    .doc(messageId)
    .update({'linkedStore.status': status});
}

// ─── Unshare / departure cleanup ─────────────────────────────────────────────
//
// These mirror the iOS app's cleanup helpers (StoresViewModel and
// ShareStoreView) one for one, so a store torn down on either platform leaves
// the same documents behind. They are exported because store deletion
// (storeService) and explicit unsharing (this service) share them exactly as
// the Swift code shares them between StoresViewModel and ShareStoreView.

// Every reminder in a store, regardless of isDone. The isShared filter is
// applied in JS rather than in the query so this needs no composite index.
async function remindersIn(userStoreId: string) {
  const snap = await firestore()
    .collection('reminders')
    .where('userStoreId', '==', userStoreId)
    .get();
  return snap.docs;
}

// Look up the current display names for a list of user ids. Firestore `in`
// queries take at most 10 values, so the ids are queried in chunks — the same
// shape as the iOS fetchUsersNames.
export async function fetchUserNames(
  userIds: string[],
): Promise<Map<string, string>> {
  const names = new Map<string, string>();
  const unique = [...new Set(userIds.filter(Boolean))];
  for (let i = 0; i < unique.length; i += 10) {
    const chunk = unique.slice(i, i + 10);
    try {
      const snap = await firestore()
        .collection('users')
        .where('userId', 'in', chunk)
        .get();
      snap.docs.forEach(doc => {
        const data = doc.data();
        if (data.userId && data.name) {
          names.set(data.userId as string, data.name as string);
        }
      });
    } catch (_) {
      // A failed lookup only costs a display name — the caller falls back.
    }
  }
  return names;
}

// Message the other side about a store that was deleted, left, or unshared.
// Notifications are best effort: failing to send one must never abort the
// cleanup that has already been committed.
export async function sendStoreNotice(params: {
  currentUser: User;
  recipientId: string;
  recipientName: string;
  message: string;
}): Promise<void> {
  const {currentUser, recipientId, recipientName, message} = params;
  if (!recipientId || recipientId === currentUser.userId) {
    return;
  }
  try {
    const conversationId = await messageService.getOrCreateConversation(
      currentUser.userId,
      recipientId,
      currentUser.name,
      recipientName,
      currentUser.profilePictureURL,
    );
    await messageService.sendMessage(
      conversationId,
      currentUser.userId,
      currentUser.name,
      message,
    );
  } catch (_) {}
}

// Strip a departed recipient from the owner's reminders: items the recipient
// contributed are deleted, and the owner's own items lose them from sharedWith
// (clearing the shared flag once nobody is left).
export async function updateOwnerRemindersAfterRecipientLeaves(
  ownerUserStoreId: string,
  recipientName: string,
): Promise<void> {
  if (!ownerUserStoreId || !recipientName) {
    return;
  }
  const docs = (await remindersIn(ownerUserStoreId)).filter(
    d => d.data().isShared === true,
  );
  if (docs.length === 0) {
    return;
  }

  const batch = firestore().batch();
  let updated = 0;

  docs.forEach(doc => {
    const data = doc.data();
    const sharedWith: string[] = data.sharedWith ?? [];

    // The recipient created this item and added it to the owner's store —
    // it leaves with them.
    if (data.sharedFrom === recipientName) {
      batch.delete(doc.ref);
      updated += 1;
      return;
    }

    // The owner's own item, shared with the recipient.
    if (!sharedWith.includes(recipientName)) {
      return;
    }
    const remaining = sharedWith.filter(name => name !== recipientName);
    updated += 1;
    if (remaining.length === 0) {
      batch.update(doc.ref, {
        isShared: false,
        sharedWith: firestore.FieldValue.delete(),
        sharedFrom: firestore.FieldValue.delete(),
      });
    } else {
      batch.update(doc.ref, {sharedWith: remaining});
    }
  });

  if (updated > 0) {
    await batch.commit();
  }
}

// Drop a departed recipient from the owner's user_store, clearing the shared
// flags entirely once they were the last one.
export async function updateOwnerUserStoreAfterRecipientLeaves(
  ownerUserStoreId: string,
  recipientName: string,
): Promise<void> {
  if (!ownerUserStoreId || !recipientName) {
    return;
  }
  const ref = firestore().collection('user_stores').doc(ownerUserStoreId);
  const snap = await ref.get();
  if (!snap.exists) {
    return;
  }
  const sharedWith: string[] = snap.data()?.sharedWith ?? [];
  const remaining = sharedWith.filter(name => name !== recipientName);
  if (remaining.length === 0) {
    await ref.update({
      sharedWith: firestore.FieldValue.delete(),
      isSharedStore: firestore.FieldValue.delete(),
    });
  } else {
    await ref.update({sharedWith: remaining});
  }
}

// Unlink a merged store from a departing owner.
//
// This only ever runs for a recipient who owns their OWN store — they had it
// before merging with the other owner. So the store is never deleted and the
// recipient's reminders are never deleted: the merge re-attributes the
// recipient's own duplicate items to the other owner (sharedFromId ==
// ownerUserId), which makes them indistinguishable from items that owner
// contributed. Deleting on that basis would destroy the recipient's own data.
//
// Instead only the link to the departing owner is severed: items attributed to
// them become the recipient's own again, their name comes off any sharedWith,
// and the user_store keeps existing minus its link fields — so the recipient
// stays the owner and keeps any shares of their own.
export async function clearMergedStoreSharing(params: {
  mergedUserStoreId: string;
  ownerUserId: string;
  ownerName: string;
}): Promise<void> {
  const {mergedUserStoreId, ownerUserId, ownerName} = params;
  const docs = await remindersIn(mergedUserStoreId);

  if (docs.length > 0) {
    const batch = firestore().batch();
    let updated = 0;

    docs.forEach(doc => {
      const data = doc.data();
      const sharedFromId: string | undefined = data.sharedFromId;
      const sharedFromName: string | undefined = data.sharedFrom;
      const sharedWith: string[] = data.sharedWith ?? [];

      // Attributed to the departing owner — either a copy they contributed or
      // one of the recipient's own duplicates the merge re-attributed. Either
      // way it stays as the recipient's own item now.
      const attributedToOwner =
        (!!ownerUserId && sharedFromId === ownerUserId) ||
        (sharedFromId == null && !!ownerName && sharedFromName === ownerName);

      const updates: {[key: string]: any} = {};

      if (attributedToOwner) {
        updates.sharedFrom = firestore.FieldValue.delete();
        updates.sharedFromId = firestore.FieldValue.delete();
      }

      const remaining = sharedWith.filter(name => name !== ownerName);
      if (remaining.length !== sharedWith.length) {
        updates.sharedWith =
          remaining.length === 0 ? firestore.FieldValue.delete() : remaining;
      }

      // Still shared only if shared with somebody else, or still attributed to
      // someone other than the departing owner.
      const stillSharedWithOthers = remaining.length > 0;
      const stillSharedFromOther = !attributedToOwner && sharedFromName != null;
      if (
        data.isShared === true &&
        !stillSharedWithOthers &&
        !stillSharedFromOther
      ) {
        updates.isShared = false;
      }

      if (Object.keys(updates).length > 0) {
        batch.update(doc.ref, updates);
        updated += 1;
      }
    });

    if (updated > 0) {
      await batch.commit();
    }
  }

  // Always KEEP the recipient's store; just sever the link to the departing
  // owner. Only their name comes off sharedWith so any independent shares the
  // recipient has survive.
  await firestore()
    .collection('user_stores')
    .doc(mergedUserStoreId)
    .update({
      sourceUserStoreId: firestore.FieldValue.delete(),
      sharedFrom: firestore.FieldValue.delete(),
      sharedFromEmail: firestore.FieldValue.delete(),
      sharedFromName: firestore.FieldValue.delete(),
      sharedWith: firestore.FieldValue.arrayRemove(ownerName),
    });
}

// Deletes the items a merged recipient contributed to the owner's store, and
// takes the recipient off sharedWith on the owner's own items.
async function removeRecipientRemindersFromOwnerStore(params: {
  ownerStoreId: string;
  recipientUserId: string;
  recipientName: string;
}): Promise<void> {
  const {ownerStoreId, recipientUserId, recipientName} = params;
  const docs = (await remindersIn(ownerStoreId)).filter(
    d => d.data().isShared === true,
  );
  if (docs.length === 0) {
    return;
  }

  const batch = firestore().batch();
  let updated = 0;

  docs.forEach(doc => {
    const data = doc.data();
    const sharedWith: string[] = data.sharedWith ?? [];

    if (!!recipientUserId && data.sharedFromId === recipientUserId) {
      // Came from the recipient during the merge — it leaves with them.
      batch.delete(doc.ref);
      updated += 1;
      return;
    }

    if (!sharedWith.includes(recipientName)) {
      return;
    }
    const remaining = sharedWith.filter(name => name !== recipientName);
    updated += 1;
    if (remaining.length === 0) {
      batch.update(doc.ref, {
        isShared: false,
        sharedWith: firestore.FieldValue.delete(),
      });
    } else {
      batch.update(doc.ref, {sharedWith: remaining});
    }
  });

  if (updated > 0) {
    await batch.commit();
  }
}

export const storeShareService = {
  // Everyone who currently has access to the store whose reminders live under
  // `ownerUserStoreId`. Recipients are read from their own user_store documents
  // (each points back at the owner's via sourceUserStoreId) rather than from the
  // owner's `sharedWith` array, which only holds names and which nothing updates
  // when a share is accepted on iOS. Same source the store list already uses.
  subscribeToSharedUsers(
    ownerUserStoreId: string,
    callback: (users: SharedStoreUser[]) => void,
  ): () => void {
    return firestore()
      .collection('user_stores')
      .where('sourceUserStoreId', '==', ownerUserStoreId)
      .onSnapshot(
        snap => {
          const users = snap.docs
            .map(doc => {
              const data = doc.data();
              const email: string = data.userEmail ?? '';
              return {
                id: doc.id,
                userId: (data.userId as string) ?? '',
                name: (data.userName as string) || email || 'Someone',
                email,
                // A missing permission means the recipient owns their copy —
                // they merged this store into one they already had. Defaulting
                // to 'edit' would mislabel that as a store they only borrow.
                permission: (data.permission as SharedStoreUser['permission']) ??
                  'owner',
                sharedAt: data.sharedAt as number | undefined,
              };
            })
            .filter(user => !!user.userId)
            .sort((a, b) => (b.sharedAt ?? 0) - (a.sharedAt ?? 0));
          callback(users);
        },
        // A failed listener must not take down the share sheet.
        () => callback([]),
      );
  },

  // Send a share request for `item` to `recipient`. Nothing is created on the
  // recipient's side here — they get a message they can accept or decline.
  async shareStore(params: {
    item: UserStoreItem;
    recipient: User;
    permission: 'edit' | 'view';
    currentUser: User;
  }): Promise<void> {
    const {item, recipient, permission, currentUser} = params;

    if (recipient.userId === currentUser.userId) {
      throw new Error('You cannot share a store with yourself.');
    }

    const ownerUserStoreId = reminderStoreIdFor(item);
    const reminderTitles = (await activeReminders(ownerUserStoreId))
      .map(d => d.data().title as string)
      .filter(Boolean);

    const conversationId = await messageService.getOrCreateConversation(
      currentUser.userId,
      recipient.userId,
      currentUser.name,
      recipient.name,
      currentUser.profilePictureURL,
      recipient.profilePictureURL,
    );

    const linkedStore: LinkedStore = {
      storeName: item.store.name,
      storeId: item.store.id,
      senderUserId: currentUser.userId,
      // Where the reminders actually live, which is the owner's user_store even
      // when an editor is the one passing the store on — a recipient pointed at
      // an editor's own doc would find no reminders under it.
      senderUserStoreId: ownerUserStoreId,
      senderEmail: currentUser.email,
      status: 'pending',
      permission,
      storeImageURL: item.store.imageURL,
      reminderTitles,
    };

    const permissionText = permission === 'edit' ? 'Can Edit' : 'View Only';
    const content = `I'd like to share ${item.store.name} with you (${permissionText}). It has ${reminderTitles.length} reminder(s).`;

    await messageService.sendMessage(
      conversationId,
      currentUser.userId,
      currentUser.name,
      content,
      {linkedStore, linkedStoreName: item.store.name},
    );

    await markRemindersAsShared(ownerUserStoreId, recipient.name);
  },

  // Accept a share request: adds the store to the accepting user's list, or
  // merges the two lists when they already have the same store.
  async acceptSharedStore(
    message: Message,
    currentUser: User,
  ): Promise<void> {
    const linkedStore = message.linkedStore;
    if (!linkedStore) {
      throw new Error('This message has no store attached.');
    }

    const userStores = firestore().collection('user_stores');
    const existing = await userStores
      .where('userId', '==', currentUser.userId)
      .where('storeId', '==', linkedStore.storeId)
      .get();

    if (!existing.empty && linkedStore.senderUserStoreId) {
      await mergeStoreReminders({
        recipientUserStoreId: existing.docs[0].id,
        ownerUserStoreId: linkedStore.senderUserStoreId,
        ownerName: message.senderName ?? linkedStore.senderUserId,
        ownerUserId: linkedStore.senderUserId,
        ownerEmail: linkedStore.senderEmail ?? '',
        recipientUserId: currentUser.userId,
        recipientEmail: currentUser.email,
        recipientName: currentUser.name,
      });
      await setLinkedStoreStatus(message.id, 'accepted');
      return;
    }

    if (!existing.empty) {
      // Already have the store and there is nothing to merge against.
      await setLinkedStoreStatus(message.id, 'accepted');
      return;
    }

    // Reminders the owner added between sending the request and this accept
    // have not been marked as shared yet — catch them up first.
    if (linkedStore.senderUserStoreId) {
      await markRemindersAsShared(
        linkedStore.senderUserStoreId,
        currentUser.name,
      );
    }

    const ownCount = await userStores
      .where('userId', '==', currentUser.userId)
      .get();

    const recipientUserStore: {[key: string]: any} = {
      userId: currentUser.userId,
      userEmail: currentUser.email,
      storeId: linkedStore.storeId,
      storeName: linkedStore.storeName,
      storeAddress: linkedStore.storeAddress ?? '',
      addedAt: nowSeconds(),
      sortOrder: ownCount.docs.length,
      permission: linkedStore.permission,
      sharedFrom: linkedStore.senderUserId,
      sharedFromName: message.senderName ?? linkedStore.senderUserId,
      sharedAt: nowSeconds(),
      notificationsEnabled: true,
      // The owner's listener reads this to know who accepted.
      userName: currentUser.name,
    };
    if (linkedStore.senderEmail) {
      recipientUserStore.sharedFromEmail = linkedStore.senderEmail;
    }
    // Both view and edit recipients read the owner's reminders through this.
    if (linkedStore.senderUserStoreId) {
      recipientUserStore.sourceUserStoreId = linkedStore.senderUserStoreId;
    }
    if (linkedStore.storeImageURL) {
      recipientUserStore.imageURL = linkedStore.storeImageURL;
    }

    await userStores.add(recipientUserStore);

    // Show the store as shared in the owner's list. Written on its own because
    // the Firestore rules only let a non-owner touch the `sharedWith` field.
    if (linkedStore.senderUserStoreId) {
      await userStores.doc(linkedStore.senderUserStoreId).update({
        sharedWith: firestore.FieldValue.arrayUnion(currentUser.name),
      });
    }

    await setLinkedStoreStatus(message.id, 'accepted');
  },

  async rejectSharedStore(messageId: string): Promise<void> {
    await setLinkedStoreStatus(messageId, 'rejected');
  },

  // Revoke one person's access to a store the current user owns. Mirrors the
  // iOS unshareWithUser: a regular recipient loses their user_store outright,
  // while a recipient who merged the store into one they already own keeps
  // their store and only has the link severed.
  async unshareWithUser(params: {
    item: UserStoreItem;
    sharedUser: SharedStoreUser;
    currentUser: User;
  }): Promise<void> {
    const {item, sharedUser, currentUser} = params;

    // The recipient's current display name drives every sharedWith edit, so it
    // is read fresh rather than taken from the (possibly stale) copy stored on
    // their user_store.
    const names = await fetchUserNames([sharedUser.userId]);
    const recipientName =
      names.get(sharedUser.userId) || sharedUser.name || sharedUser.email;

    // Where this store's reminders live — the group id for a legacy shared
    // "Can Edit" store, otherwise the owner's own document.
    const ownerStoreId = item.sharedStoreGroupId ?? item.id;

    if (sharedUser.permission === 'owner') {
      // Merged store: the recipient owns their copy. Sever only the link
      // between the two stores, never the store itself.
      await clearMergedStoreSharing({
        mergedUserStoreId: sharedUser.id,
        ownerUserId: currentUser.userId,
        ownerName: currentUser.name,
      });

      await removeRecipientRemindersFromOwnerStore({
        ownerStoreId,
        recipientUserId: sharedUser.userId,
        recipientName,
      });
    } else {
      // Regular recipient: their user_store only exists because of this share.
      await firestore().collection('user_stores').doc(sharedUser.id).delete();

      await updateOwnerRemindersAfterRecipientLeaves(
        ownerStoreId,
        recipientName,
      );
    }

    await updateOwnerUserStoreAfterRecipientLeaves(item.id, recipientName);

    await sendStoreNotice({
      currentUser,
      recipientId: sharedUser.userId,
      recipientName,
      message: `I've stopped sharing ${item.store.name} with you.`,
    });
  },
};
