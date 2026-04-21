import firestore from '@react-native-firebase/firestore';
import storage from '@react-native-firebase/storage';
import {Store, UserStore, UserStoreItem} from '../models';

function normalizeStoreName(name: string): string {
  return name.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '');
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
            sharedStoreGroupId: us.sharedStoreGroupId,
            isShared: !!us.sharedFromEmail,
          });
        }
        // Sort by order field
        items.sort((a: any, b: any) => (a.order ?? 0) - (b.order ?? 0));
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
      const o = (d.data().order ?? 0) as number;
      return Math.max(max, o);
    }, -1);

    // Add user_store doc
    await firestore().collection('user_stores').add({
      userId: uid,
      email: email,
      storeId: storeId,
      storeName: storeName,
      permission: 'owner',
      order: maxOrder + 1,
      createdAt: firestore.FieldValue.serverTimestamp(),
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
