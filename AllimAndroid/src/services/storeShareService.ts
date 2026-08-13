import firestore, {
  FirebaseFirestoreTypes,
} from '@react-native-firebase/firestore';
import {
  LinkedStore,
  Message,
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

export const storeShareService = {
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
};
