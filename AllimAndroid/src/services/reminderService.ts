import firestore from '@react-native-firebase/firestore';
import storage from '@react-native-firebase/storage';
import {Reminder} from '../models';

export const reminderService = {
  // Subscribe to reminders for a user store
  subscribeToReminders(
    userStoreId: string,
    callback: (reminders: Reminder[]) => void,
  ) {
    return firestore()
      .collection('reminders')
      .where('userStoreId', '==', userStoreId)
      .onSnapshot(snap => {
        const reminders = snap.docs.map(
          d => ({id: d.id, ...d.data()} as Reminder),
        );
        reminders.sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
        callback(reminders);
      });
  },

  // Add reminder
  async addReminder(
    userStoreId: string,
    storeId: string,
    title: string,
    category?: string,
  ): Promise<Reminder> {
    const existing = await firestore()
      .collection('reminders')
      .where('userStoreId', '==', userStoreId)
      .get();
    const maxOrder = existing.docs.reduce((max, d) => {
      return Math.max(max, d.data().order ?? 0);
    }, -1);

    const ref = await firestore().collection('reminders').add({
      title,
      isDone: false,
      userStoreId,
      storeId,
      order: maxOrder + 1,
      category: category ?? null,
      quantity: null,
      photoURLs: [],
      isShared: false,
      createdAt: firestore.FieldValue.serverTimestamp(),
    });

    // Update store reminder count
    await firestore()
      .collection('stores')
      .doc(storeId)
      .update({reminderCount: existing.docs.length + 1});

    return {
      id: ref.id,
      title,
      isDone: false,
      userStoreId,
      order: maxOrder + 1,
    };
  },

  // Toggle reminder done
  async toggleDone(reminder: Reminder): Promise<void> {
    await firestore()
      .collection('reminders')
      .doc(reminder.id)
      .update({isDone: !reminder.isDone});
  },

  // Update reminder title
  async updateTitle(id: string, title: string): Promise<void> {
    await firestore().collection('reminders').doc(id).update({title});
  },

  // Update reminder category
  async updateCategory(id: string, category: string): Promise<void> {
    await firestore().collection('reminders').doc(id).update({category});
  },

  // Update reminder quantity
  async updateQuantity(id: string, quantity: number | null): Promise<void> {
    await firestore().collection('reminders').doc(id).update({quantity});
  },

  // Update out-of-stock flag
  async updateOutOfStock(id: string, isOutOfStock: boolean): Promise<void> {
    await firestore().collection('reminders').doc(id).update({isOutOfStock});
  },

  // Delete reminder
  async deleteReminder(id: string, storeId: string): Promise<void> {
    // Delete any attached photos from Storage first so they don't become orphaned.
    const snap = await firestore().collection('reminders').doc(id).get();
    const photoURLs = (snap.data()?.photoURLs ?? []) as string[];
    await Promise.all(
      photoURLs.map(async url => {
        try {
          await storage().refFromURL(url).delete();
        } catch (_) {}
      }),
    );

    await firestore().collection('reminders').doc(id).delete();

    // Decrement store reminder count
    const remaining = await firestore()
      .collection('reminders')
      .where('storeId', '==', storeId)
      .get();
    await firestore()
      .collection('stores')
      .doc(storeId)
      .update({reminderCount: remaining.docs.length});
  },

  // Reorder reminders
  async reorderReminders(updates: {id: string; order: number}[]): Promise<void> {
    const batch = firestore().batch();
    updates.forEach(({id, order}) => {
      batch.update(firestore().collection('reminders').doc(id), {order});
    });
    await batch.commit();
  },

  // Upload photo
  async uploadPhoto(
    reminderId: string,
    uri: string,
    uid: string,
  ): Promise<string> {
    const filename = `${Date.now()}.jpg`;
    const ref = storage().ref(`reminder_photos/${uid}/${reminderId}/${filename}`);
    await ref.putFile(uri);
    const url = await ref.getDownloadURL();
    await firestore()
      .collection('reminders')
      .doc(reminderId)
      .update({
        photoURLs: firestore.FieldValue.arrayUnion(url),
      });
    return url;
  },

  // Delete photo
  async deletePhoto(reminderId: string, url: string): Promise<void> {
    await firestore()
      .collection('reminders')
      .doc(reminderId)
      .update({
        photoURLs: firestore.FieldValue.arrayRemove(url),
      });
    try {
      const ref = storage().refFromURL(url);
      await ref.delete();
    } catch (_) {}
  },
};
