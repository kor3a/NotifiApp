import firestore from '@react-native-firebase/firestore';
import storage from '@react-native-firebase/storage';
import {Store, UserStore, UserStoreItem, reminderStoreIdFor} from '../models';

function normalizeStoreName(name: string): string {
  return name.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '');
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
            permission: us.permission,
            sharedWith: us.sharedWith,
            sharedFromName: us.sharedFromName,
            sourceUserStoreId: us.sourceUserStoreId,
            sharedStoreGroupId: us.sharedStoreGroupId,
            // A store is shared if the owner is sharing it with others
            // (sharedWith populated) OR it was shared to this user (recipient).
            isShared:
              (!!us.sharedWith && us.sharedWith.length > 0) ||
              !!us.sharedFromEmail,
            sortOrder: (us as any).sortOrder ?? 0,
          } as any);
        }
        // Sort by sortOrder field (matches the iOS app's ordering)
        items.sort((a: any, b: any) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));
        latestItems = items;
        syncCountListeners(items);
        syncRecipientListeners(items);
        emit();
      });

    return () => {
      unsubscribeStores();
      countUnsubs.forEach(unsub => unsub());
      countUnsubs.clear();
      counts.clear();
      recipientUnsubs.forEach(unsub => unsub());
      recipientUnsubs.clear();
      recipients.clear();
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

  // Delete store
  async deleteStore(
    userStoreId: string,
    uid: string,
    email: string,
  ): Promise<void> {
    const reminders = await firestore()
      .collection('reminders')
      .where('userStoreId', '==', userStoreId)
      .get();

    // Delete every photo attached to any reminder in this store from Storage
    // before removing the Firestore docs, otherwise the files are orphaned.
    const photoURLs = reminders.docs.flatMap(
      d => (d.data().photoURLs ?? []) as string[],
    );
    await Promise.all(
      photoURLs.map(async url => {
        try {
          await storage().refFromURL(url).delete();
        } catch (_) {}
      }),
    );

    const batch = firestore().batch();
    reminders.docs.forEach(d => batch.delete(d.ref));
    batch.delete(firestore().collection('user_stores').doc(userStoreId));
    await batch.commit();
  },

  // Remove a shared store (view/edit permission)
  async removeSharedStore(userStoreId: string): Promise<void> {
    await firestore().collection('user_stores').doc(userStoreId).delete();
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
