import firestore from '@react-native-firebase/firestore';
import storage from '@react-native-firebase/storage';
import {
  Store,
  User,
  UserStore,
  UserStoreItem,
  isRecipientStore,
  reminderStoreIdFor,
} from '../models';
import {
  clearMergedStoreSharing,
  fetchUserNames,
  sendStoreNotice,
  updateOwnerRemindersAfterRecipientLeaves,
  updateOwnerUserStoreAfterRecipientLeaves,
} from './storeShareService';

function normalizeStoreName(name: string): string {
  return name.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '');
}

// ─── Store removal ───────────────────────────────────────────────────────────
//
// The three paths below mirror the iOS StoresViewModel one for one
// (deleteSingleUserStore / deleteRecipientUserStore / deleteSharedStoreGroup),
// so a store torn down on either platform leaves the same documents behind —
// most importantly, an owner's delete also clears the store off every
// recipient's account instead of stranding it there.

// Delete every photo attached to these reminders from Storage before their
// documents go, otherwise the files are orphaned. Best effort: a file that is
// already gone must not abort the deletion.
async function deleteReminderPhotos(
  docs: {data: () => {[key: string]: any}}[],
): Promise<void> {
  const urls = new Set<string>();
  docs.forEach(doc => {
    ((doc.data().photoURLs ?? []) as string[]).forEach(url => urls.add(url));
  });
  await Promise.all(
    [...urls].map(async url => {
      try {
        await storage().refFromURL(url).delete();
      } catch (_) {}
    }),
  );
}

// The owner deleting a store they own: their reminders and user_store go, and
// every recipient's side is cleaned up too.
async function deleteSingleUserStore(
  item: UserStoreItem,
  currentUser: User,
): Promise<void> {
  const ownerUserStoreId = item.id;

  // Recipients are cleaned up before the owner's own document goes: the
  // Firestore rules authorise these writes through `sharedFrom`/
  // `sharedFromEmail` on the recipients' documents, and doing them first means
  // an interrupted delete can never leave a recipient pointing at a store that
  // no longer exists.
  const recipientDocs = (
    await firestore()
      .collection('user_stores')
      .where('sourceUserStoreId', '==', ownerUserStoreId)
      .get()
  ).docs.filter(doc => (doc.data().userId as string) !== currentUser.userId);

  // A recipient with an explicit edit/view permission only has this store
  // because of the share, so their copy goes. A missing permission means they
  // own their store and merged this one into it — that store is theirs and is
  // only unlinked.
  const regularDocs = recipientDocs.filter(doc => {
    const permission = doc.data().permission;
    return permission === 'edit' || permission === 'view';
  });
  const mergedDocs = recipientDocs.filter(doc => {
    const permission = doc.data().permission;
    return !(permission === 'edit' || permission === 'view');
  });

  if (regularDocs.length > 0) {
    const batch = firestore().batch();
    regularDocs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
  }

  for (const doc of mergedDocs) {
    // Failing on one merged recipient must not strand the others, nor stop the
    // owner's own store from being deleted.
    try {
      await clearMergedStoreSharing({
        mergedUserStoreId: doc.id,
        ownerUserId: currentUser.userId,
        ownerName: currentUser.name,
      });
    } catch (_) {}
  }

  // The owner's own reminders and store.
  const reminders = await firestore()
    .collection('reminders')
    .where('userStoreId', '==', ownerUserStoreId)
    .get();

  await deleteReminderPhotos(reminders.docs);

  const batch = firestore().batch();
  reminders.docs.forEach(d => batch.delete(d.ref));
  batch.delete(firestore().collection('user_stores').doc(ownerUserStoreId));
  await batch.commit();

  // Tell each recipient what happened to the store that just vanished from
  // their list.
  const regularIds = regularDocs
    .map(doc => doc.data().userId as string)
    .filter(Boolean);
  const mergedIds = mergedDocs
    .map(doc => doc.data().userId as string)
    .filter(Boolean);
  if (regularIds.length === 0 && mergedIds.length === 0) {
    return;
  }

  const names = await fetchUserNames([...regularIds, ...mergedIds]);
  const nameFor = (userId: string) => names.get(userId) ?? 'Unknown';

  for (const recipientId of regularIds) {
    await sendStoreNotice({
      currentUser,
      recipientId,
      recipientName: nameFor(recipientId),
      message: `${currentUser.name} deleted ${item.store.name}, which was shared with you. The store has been removed from your account.`,
    });
  }
  for (const recipientId of mergedIds) {
    await sendStoreNotice({
      currentUser,
      recipientId,
      recipientName: nameFor(recipientId),
      message: `${currentUser.name} deleted ${item.store.name}. Their shared items have been removed from your list.`,
    });
  }
}

// A recipient removing a store that was shared with them. Only their side goes
// — deleting the reminders is the owner's action alone.
async function deleteRecipientUserStore(
  item: UserStoreItem,
  currentUser: User,
): Promise<void> {
  const ownerId = item.sharedFromId ?? '';
  const ownerName = item.sharedFromName ?? '';

  // Merged store: this user owns it (they had it before the merge), so it is
  // never deleted — only the link to the other owner is severed.
  if (item.permission === 'owner') {
    await clearMergedStoreSharing({
      mergedUserStoreId: item.id,
      ownerUserId: ownerId,
      ownerName,
    });

    if (item.sourceUserStoreId) {
      await updateOwnerRemindersAfterRecipientLeaves(
        item.sourceUserStoreId,
        currentUser.name,
      );
      await updateOwnerUserStoreAfterRecipientLeaves(
        item.sourceUserStoreId,
        currentUser.name,
      );
    }

    await sendStoreNotice({
      currentUser,
      recipientId: ownerId,
      recipientName: ownerName,
      message: `${currentUser.name} disconnected from the shared ${item.store.name}. Their shared items have been removed from your list.`,
    });
    return;
  }

  await firestore().collection('user_stores').doc(item.id).delete();

  if (item.sourceUserStoreId) {
    await updateOwnerRemindersAfterRecipientLeaves(
      item.sourceUserStoreId,
      currentUser.name,
    );
    await updateOwnerUserStoreAfterRecipientLeaves(
      item.sourceUserStoreId,
      currentUser.name,
    );
  }

  await sendStoreNotice({
    currentUser,
    recipientId: ownerId,
    recipientName: ownerName,
    message:
      item.permission === 'edit'
        ? `${currentUser.name} left the shared ${item.store.name} store. The store is no longer shared with them.`
        : `${currentUser.name} removed ${item.store.name} from their account. The store is no longer shared with them.`,
  });
}

// Legacy "Can Edit" shared group, deleted by the user who created it: the group
// document goes first, which is what lets the Firestore rules permit deleting
// the other members' user_stores.
async function deleteSharedStoreGroup(
  sharedGroupId: string,
  item: UserStoreItem,
  currentUser: User,
): Promise<void> {
  const members = await firestore()
    .collection('user_stores')
    .where('sharedStoreGroupId', '==', sharedGroupId)
    .get();

  const coEditorIds = members.docs
    .map(doc => doc.data().userId as string)
    .filter(userId => !!userId && userId !== currentUser.userId);

  await firestore()
    .collection('shared_store_groups')
    .doc(sharedGroupId)
    .delete();

  const reminders = await firestore()
    .collection('reminders')
    .where('userStoreId', '==', sharedGroupId)
    .get();

  await deleteReminderPhotos(reminders.docs);

  const batch = firestore().batch();
  members.docs.forEach(doc => batch.delete(doc.ref));
  reminders.docs.forEach(doc => batch.delete(doc.ref));
  await batch.commit();

  if (coEditorIds.length === 0) {
    return;
  }
  const names = await fetchUserNames(coEditorIds);
  for (const coEditorId of coEditorIds) {
    await sendStoreNotice({
      currentUser,
      recipientId: coEditorId,
      recipientName: names.get(coEditorId) ?? 'Unknown',
      message: `${currentUser.name} deleted the shared ${item.store.name} store. It has been removed from your account.`,
    });
  }
}

export const storeService = {
  // Subscribe to user's stores.
  //
  // Reminder counts are derived live from the `reminders` collection rather
  // than read off the global `stores` doc: that document is shared by every
  // user who has the same store, so its count belongs to whoever wrote it
  // last. This mirrors the iOS app, which keeps a per-store reminder listener.
  subscribeToUserStores(
    uid: string,
    email: string,
    callback: (items: UserStoreItem[]) => void,
  ) {
    // Counts and their listeners are keyed by the user_store id the reminders
    // actually live under — an owner's own id, or the owner's id for a store
    // shared with this user.
    const counts = new Map<string, number>();
    const countUnsubs = new Map<string, () => void>();
    // Recipients of each store this user owns, keyed by the owner's user_store
    // id. Derived from the recipients' own documents rather than from the
    // owner's `sharedWith` field, which nothing updates when the share is
    // accepted on iOS.
    const recipients = new Map<string, string[]>();
    const recipientUnsubs = new Map<string, () => void>();
    // Owner documents behind stores shared with this user, keyed by the owner's
    // user_store id — watched so this side notices if the owner's store is
    // deleted without their device cleaning up here.
    const sourceUnsubs = new Map<string, () => void>();
    let latestItems: UserStoreItem[] = [];

    function emit() {
      callback(
        latestItems.map(item => {
          const shared =
            item.permission === 'owner'
              ? recipients.get(item.id) ?? item.sharedWith ?? []
              : item.sharedWith ?? [];
          return {
            ...item,
            sharedWith: shared.length > 0 ? shared : undefined,
            isShared: shared.length > 0 || item.isShared,
            store: {
              ...item.store,
              reminderCount: counts.get(reminderStoreIdFor(item)) ?? 0,
            },
          };
        }),
      );
    }

    // Watch for user_stores pointing at a store this user owns — one exists per
    // person who accepted a share of it. Mirrors the iOS shared-status listener,
    // including writing the names back onto the owner's document so the other
    // platform reads the same list.
    function syncRecipientListeners(items: UserStoreItem[]) {
      const owned = new Set(
        items.filter(i => i.permission === 'owner').map(i => i.id),
      );

      recipientUnsubs.forEach((unsub, id) => {
        if (!owned.has(id)) {
          unsub();
          recipientUnsubs.delete(id);
          recipients.delete(id);
        }
      });

      owned.forEach(ownerStoreId => {
        if (recipientUnsubs.has(ownerStoreId)) {
          return;
        }
        const unsub = firestore()
          .collection('user_stores')
          .where('sourceUserStoreId', '==', ownerStoreId)
          .onSnapshot(
            snap => {
              const names = snap.docs
                .map(d => d.data().userName as string | undefined)
                .filter((name): name is string => !!name);
              recipients.set(ownerStoreId, names);
              emit();

              // Keep the owner's own document in step, so iOS (and this app's
              // other reads of sharedWith) see the same thing.
              const stored =
                latestItems.find(i => i.id === ownerStoreId)?.sharedWith ?? [];
              const changed =
                stored.length !== names.length ||
                names.some(name => !stored.includes(name));
              if (changed) {
                firestore()
                  .collection('user_stores')
                  .doc(ownerStoreId)
                  .update(
                    names.length > 0
                      ? {sharedWith: names, isSharedStore: true}
                      : {
                          sharedWith: firestore.FieldValue.delete(),
                          isSharedStore: firestore.FieldValue.delete(),
                        },
                  )
                  .catch(() => {});
              }
            },
            // A failed listener must not take down the store list.
            () => {},
          );
        recipientUnsubs.set(ownerStoreId, unsub);
      });
    }

    // Watch the owner's user_store behind every store that was shared with this
    // user, so its deletion is noticed here too. Mirrors the iOS
    // setupSourceStoreListeners: the owner's own delete already clears both
    // sides, and this is the backstop for when that write never lands (the
    // owner went offline mid-delete, or an older build deleted only its own
    // documents) — the cleanup then runs with this user's own credentials.
    function syncSourceStoreListeners(items: UserStoreItem[]) {
      const linked = items.filter(
        item => !!item.sourceUserStoreId && isRecipientStore(item),
      );
      const wanted = new Set(linked.map(item => item.sourceUserStoreId!));

      sourceUnsubs.forEach((unsub, id) => {
        if (!wanted.has(id)) {
          unsub();
          sourceUnsubs.delete(id);
        }
      });

      linked.forEach(item => {
        const sourceId = item.sourceUserStoreId!;
        if (sourceUnsubs.has(sourceId)) {
          return;
        }
        const unsub = firestore()
          .collection('user_stores')
          .doc(sourceId)
          .onSnapshot(
            sourceSnap => {
              // React only to the owner's document being deleted, and only on
              // word from the server: offline, a document this device has
              // never cached also arrives as "missing", and acting on that
              // would drop a store that is perfectly alive.
              if (
                !sourceSnap ||
                sourceSnap.exists ||
                sourceSnap.metadata?.fromCache
              ) {
                return;
              }
              sourceUnsubs.get(sourceId)?.();
              sourceUnsubs.delete(sourceId);

              if (item.permission === 'owner') {
                // Merged store: this user owns it, so it survives the owner's
                // departure with only the link severed.
                clearMergedStoreSharing({
                  mergedUserStoreId: item.id,
                  ownerUserId: item.sharedFromId ?? '',
                  ownerName: item.sharedFromName ?? '',
                }).catch(() => {});
              } else {
                // The store only existed because of the share.
                firestore()
                  .collection('user_stores')
                  .doc(item.id)
                  .delete()
                  .catch(() => {});
              }
            },
            // A failed listener must not take down the store list.
            () => {},
          );
        sourceUnsubs.set(sourceId, unsub);
      });
    }

    // Look up the sharer's current display name for every store shared with
    // this user and rewrite a stale `sharedFromName`. Mirrors the iOS
    // refreshSharedFromNames: the name is cached on the recipient's own
    // document at accept time, so a later rename would otherwise show the old
    // one forever. The write only happens when the name actually differs, so
    // the listener it re-triggers settles immediately.
    async function refreshSharedFromNames(items: UserStoreItem[]) {
      const sharers = items.filter(item => !!item.sharedFromId);
      if (sharers.length === 0) {
        return;
      }
      const names = await fetchUserNames(
        sharers.map(item => item.sharedFromId!),
      );
      await Promise.all(
        sharers.map(async item => {
          const current = names.get(item.sharedFromId!);
          if (!current || current === item.sharedFromName) {
            return;
          }
          try {
            await firestore()
              .collection('user_stores')
              .doc(item.id)
              .update({sharedFromName: current});
          } catch (_) {}
        }),
      );
    }

    function syncCountListeners(items: UserStoreItem[]) {
      const wanted = new Set(items.map(reminderStoreIdFor));

      // Drop listeners for stores that are no longer in the list.
      countUnsubs.forEach((unsub, id) => {
        if (!wanted.has(id)) {
          unsub();
          countUnsubs.delete(id);
          counts.delete(id);
        }
      });

      wanted.forEach(id => {
        if (countUnsubs.has(id)) {
          return;
        }
        const unsub = firestore()
          .collection('reminders')
          .where('userStoreId', '==', id)
          .onSnapshot(
            remindersSnap => {
              counts.set(id, remindersSnap.docs.length);
              emit();
            },
            // A failed count must not take down the store list.
            () => {},
          );
        countUnsubs.set(id, unsub);
      });
    }

    const unsubscribeStores = firestore()
      .collection('user_stores')
      .where('userId', '==', uid)
      .onSnapshot(async snap => {
        const items: UserStoreItem[] = [];
        for (const doc of snap.docs) {
          const us = {id: doc.id, ...doc.data()} as UserStore;
          // The catalog doc is optional: it supplies a shared display name and
          // image when the owner has seeded one, and the user_store's own
          // storeName is the fallback. The app never writes it — `stores` is a
          // global collection locked to the app owner by the Firestore rules.
          const storeSnap = await firestore()
            .collection('stores')
            .doc(us.storeId)
            .get();
          const store: Store = storeSnap.exists
            ? ({id: storeSnap.id, ...storeSnap.data()} as Store)
            : {
                id: us.storeId,
                name: us.storeName,
                reminderCount: 0,
              };
          items.push({
            id: us.id,
            store,
            // A store the user created carries no permission field, so a
            // missing value means they own it — the same default the iOS
            // parser applies. Defaulting to a recipient permission would send
            // reminder lookups to `sourceUserStoreId` and route deletes down
            // the recipient path.
            permission: us.permission ?? 'owner',
            sharedWith: us.sharedWith,
            sharedFromName: us.sharedFromName,
            sharedFromId: us.sharedFrom,
            sharedFromEmail: us.sharedFromEmail,
            sourceUserStoreId: us.sourceUserStoreId,
            sharedStoreGroupId: us.sharedStoreGroupId,
            // A store is shared if the owner is sharing it with others
            // (sharedWith populated) OR it was shared to this user (recipient).
            isShared:
              (!!us.sharedWith && us.sharedWith.length > 0) ||
              !!us.sharedFromName,
            sortOrder: (us as any).sortOrder ?? 0,
          } as any);
        }
        // Sort by sortOrder field (matches the iOS app's ordering)
        items.sort((a: any, b: any) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));
        latestItems = items;
        syncCountListeners(items);
        syncRecipientListeners(items);
        syncSourceStoreListeners(items);
        emit();
        // Best effort and off the critical path — the list is already rendered.
        refreshSharedFromNames(items).catch(() => {});
      });

    return () => {
      unsubscribeStores();
      countUnsubs.forEach(unsub => unsub());
      countUnsubs.clear();
      counts.clear();
      recipientUnsubs.forEach(unsub => unsub());
      recipientUnsubs.clear();
      recipients.clear();
      sourceUnsubs.forEach(unsub => unsub());
      sourceUnsubs.clear();
    };
  },

  // Add store to user's list.
  //
  // Only the user_store association is written. `stores` is a global catalog
  // shared by every user and the Firestore rules allow the app owner alone to
  // write it, so creating a catalog entry here fails with permission-denied
  // for everyone else. The store's name travels on the user_store document
  // (`storeName`), which is what the iOS app relies on too.
  async addStore(uid: string, email: string, storeName: string): Promise<void> {
    const storeId = normalizeStoreName(storeName);

    // Get current max order
    const existing = await firestore()
      .collection('user_stores')
      .where('userId', '==', uid)
      .get();
    const maxOrder = existing.docs.reduce((max, d) => {
      const o = (d.data().sortOrder ?? 0) as number;
      return Math.max(max, o);
    }, -1);

    // Add user_store doc. Field names must match the iOS app + Firestore rules:
    // `userEmail` (not `email`) is required by the create rule, and ordering
    // uses `sortOrder`/`addedAt` so iOS and Android stay in sync.
    await firestore().collection('user_stores').add({
      userId: uid,
      userEmail: email,
      storeId: storeId,
      storeName: storeName,
      permission: 'owner',
      sortOrder: maxOrder + 1,
      addedAt: Date.now() / 1000,
    });
  },

  // Remove a store from the current user's list.
  //
  // Which of the three paths runs is decided exactly as the iOS app decides it:
  // anyone with a `sharedFromName` is a recipient and only affects their own
  // side, the creator of a legacy "Can Edit" group tears the whole group down,
  // and everyone else is an owner deleting their own store — which also clears
  // it off every recipient's account.
  async removeStoreFromUser(
    item: UserStoreItem,
    currentUser: User,
  ): Promise<void> {
    const isRecipient = isRecipientStore(item);

    if (item.permission === 'edit' && item.sharedStoreGroupId && !isRecipient) {
      await deleteSharedStoreGroup(item.sharedStoreGroupId, item, currentUser);
    } else if (isRecipient) {
      await deleteRecipientUserStore(item, currentUser);
    } else {
      await deleteSingleUserStore(item, currentUser);
    }
  },

  // Toggle smart category for a user store
  async updateSmartCategory(
    userStoreId: string,
    enabled: boolean,
  ): Promise<void> {
    await firestore()
      .collection('user_stores')
      .doc(userStoreId)
      .update({smartCategoryEnabled: enabled});
  },

  // Reorder stores. The field is `sortOrder` — the same one the store list
  // reads and the iOS app writes.
  async reorderStores(updates: {id: string; order: number}[]): Promise<void> {
    const batch = firestore().batch();
    updates.forEach(({id, order}) => {
      batch.update(firestore().collection('user_stores').doc(id), {
        sortOrder: order,
      });
    });
    await batch.commit();
  },
};
