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
    let latestItems: UserStoreItem[] = [];

    function emit() {
      callback(
        latestItems.map(item => ({
          ...item,
          store: {
            ...item.store,
            reminderCount: counts.get(reminderStoreIdFor(item)) ?? 0,
          },
        })),
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
        emit();
      });

    return () => {
      unsubscribeStores();
      countUnsubs.forEach(unsub => unsub());
      countUnsubs.clear();
      counts.clear();
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
