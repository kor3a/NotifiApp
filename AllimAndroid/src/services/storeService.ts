import firestore from '@react-native-firebase/firestore';
import storage from '@react-native-firebase/storage';
import {Store, UserStore, UserStoreItem} from '../models';

function normalizeStoreName(name: string): string {
  return name.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '');
}

// Compares two name lists ignoring order/duplicates.
function sameNameSet(a: string[], b: string[]): boolean {
  const sa = Array.from(new Set(a)).sort();
  const sb = Array.from(new Set(b)).sort();
  return sa.length === sb.length && sa.every((v, i) => v === sb[i]);
}

export const storeService = {
  // Subscribe to user's stores
  subscribeToUserStores(
    uid: string,
    email: string,
    callback: (items: UserStoreItem[]) => void,
  ) {
    return firestore()
      .collection('user_stores')
      .where('userId', '==', uid)
      .onSnapshot(async snap => {
        const items: UserStoreItem[] = [];
        for (const doc of snap.docs) {
          const us = {id: doc.id, ...doc.data()} as UserStore;
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
        callback(items);
      });
  },

  // Add store to user's list
  async addStore(uid: string, email: string, storeName: string): Promise<void> {
    const storeId = normalizeStoreName(storeName);

    // Create or update global store
    const storeRef = firestore().collection('stores').doc(storeId);
    const storeSnap = await storeRef.get();
    if (!storeSnap.exists) {
      await storeRef.set({
        id: storeId,
        name: storeName,
        reminderCount: 0,
      });
    }

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

  // Keep each owner store's `sharedWith` name list in sync with its actual
  // recipients (user_stores whose sourceUserStoreId points back to the owner
  // store). Mirrors the iOS app's shared-status listener so the "Shared with …"
  // label stays accurate even when the owner only uses Android.
  //
  // A recipient's sourceUserStoreId belongs to exactly one owner store, so each
  // owner id lives in exactly one query chunk and can be reconciled independently.
  subscribeOwnerSharedWith(ownerStoreIds: string[]): () => void {
    const reconcile = async (ownerId: string, names: string[]) => {
      const ref = firestore().collection('user_stores').doc(ownerId);
      const snap = await ref.get();
      if (!snap.exists) {return;}
      const current = (snap.data()?.sharedWith ?? []) as string[];
      if (sameNameSet(current, names)) {return;}
      if (names.length === 0) {
        await ref.update({sharedWith: firestore.FieldValue.delete()});
      } else {
        await ref.update({sharedWith: Array.from(new Set(names))});
      }
    };

    const unsubs: Array<() => void> = [];
    for (let i = 0; i < ownerStoreIds.length; i += 10) {
      const chunk = ownerStoreIds.slice(i, i + 10);
      const unsub = firestore()
        .collection('user_stores')
        .where('sourceUserStoreId', 'in', chunk)
        .onSnapshot(
          snap => {
            const byOwner: Record<string, string[]> = {};
            snap.docs.forEach(d => {
              const data = d.data();
              const src = data.sourceUserStoreId as string | undefined;
              const name = (data.userName ?? data.userEmail) as string | undefined;
              if (!src || !name) {return;}
              (byOwner[src] ??= []).push(name);
            });
            chunk.forEach(ownerId => reconcile(ownerId, byOwner[ownerId] ?? []));
          },
          err => console.warn('sharedWith listener error:', err),
        );
      unsubs.push(unsub);
    }
    return () => unsubs.forEach(u => u());
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

  // Reorder stores
  async reorderStores(updates: {id: string; order: number}[]): Promise<void> {
    const batch = firestore().batch();
    updates.forEach(({id, order}) => {
      batch.update(firestore().collection('user_stores').doc(id), {order});
    });
    await batch.commit();
  },

  // Update store reminder count
  async updateReminderCount(
    storeId: string,
    count: number,
  ): Promise<void> {
    await firestore()
      .collection('stores')
      .doc(storeId)
      .update({reminderCount: count});
  },
};
