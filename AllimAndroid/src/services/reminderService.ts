import firestore from '@react-native-firebase/firestore';
import storage from '@react-native-firebase/storage';
import {Reminder} from '../models';

// Keywords used to auto-assign categories when Smart Category is toggled on
const SMART_CATEGORY_KEYWORDS: Record<string, string[]> = {
  Produce: [
    'apple', 'banana', 'orange', 'grape', 'strawberry', 'blueberry', 'raspberry',
    'peach', 'pear', 'plum', 'mango', 'pineapple', 'watermelon', 'cantaloupe',
    'lemon', 'lime', 'avocado', 'tomato', 'potato', 'onion', 'garlic', 'carrot',
    'celery', 'cucumber', 'lettuce', 'spinach', 'kale', 'broccoli', 'cauliflower',
    'pepper', 'zucchini', 'eggplant', 'corn', 'asparagus', 'mushroom', 'cabbage',
    'radish', 'beet', 'turnip', 'squash', 'salad', 'herbs', 'basil', 'cilantro',
    'parsley', 'ginger', 'vegetable', 'fruit',
  ],
  Dairy: [
    'milk', 'cheese', 'yogurt', 'butter', 'cream', 'egg', 'eggs', 'sour cream',
    'cottage cheese', 'cream cheese', 'half and half', 'whipped cream',
    'mozzarella', 'cheddar', 'parmesan', 'brie', 'feta',
  ],
  Meat: [
    'chicken', 'beef', 'pork', 'turkey', 'lamb', 'salmon', 'tuna', 'fish',
    'shrimp', 'steak', 'ground beef', 'sausage', 'bacon', 'ham', 'hot dog',
    'deli', 'pepperoni', 'seafood', 'lobster', 'crab', 'tilapia', 'cod',
  ],
  Bakery: [
    'bread', 'bagel', 'muffin', 'cake', 'pie', 'croissant', 'bun', 'roll',
    'tortilla', 'wrap', 'pita', 'naan', 'donut', 'pastry', 'baguette',
  ],
  Frozen: ['frozen', 'ice cream', 'popsicle', 'freezer'],
  Beverages: [
    'water', 'juice', 'soda', 'coffee', 'tea', 'beer', 'wine', 'lemonade',
    'smoothie', 'sport drink', 'energy drink', 'sparkling', 'coconut water',
    'almond milk', 'oat milk', 'drink',
  ],
  Snacks: [
    'chips', 'crackers', 'nuts', 'popcorn', 'candy', 'chocolate', 'cookies',
    'granola', 'protein bar', 'trail mix', 'pretzels', 'gummies', 'cereal',
    'oats', 'rice cakes',
  ],
  Household: [
    'detergent', 'soap', 'paper towel', 'toilet paper', 'tissue', 'cleaning',
    'dish', 'laundry', 'trash bag', 'zip lock', 'foil', 'cling wrap',
    'sponge', 'bleach', 'wipes', 'batteries', 'light bulb', 'candle',
  ],
  'Personal Care': [
    'shampoo', 'conditioner', 'toothpaste', 'toothbrush', 'deodorant', 'razor',
    'lotion', 'sunscreen', 'face wash', 'makeup', 'lipstick', 'mascara',
    'moisturizer', 'cologne', 'perfume', 'body wash', 'floss',
  ],
};

function guessCategory(title: string): string {
  const lower = title.toLowerCase();
  for (const [cat, keywords] of Object.entries(SMART_CATEGORY_KEYWORDS)) {
    if (keywords.some(kw => lower.includes(kw))) {
      return cat;
    }
  }
  return 'Other';
}

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

  // Batch-categorize all uncategorized reminders in a store using keyword matching.
  // Called once when the user toggles Smart Category on.
  async smartCategorizeAll(userStoreId: string): Promise<void> {
    const snap = await firestore()
      .collection('reminders')
      .where('userStoreId', '==', userStoreId)
      .get();

    const uncategorized = snap.docs.filter(
      d => !d.data().category,
    );

    if (uncategorized.length === 0) {return;}

    const batch = firestore().batch();
    uncategorized.forEach(doc => {
      const category = guessCategory(doc.data().title ?? '');
      batch.update(doc.ref, {category});
    });
    await batch.commit();
  },

  // Reorder reminders
  async reorderReminders(updates: {id: string; order: number}[]): Promise<void> {
    const batch = firestore().batch();
    updates.forEach(({id, order}) => {
      batch.update(firestore().collection('reminders').doc(id), {order});
    });
    await batch.commit();
  },

  // Upload photo. The storage path matches iOS (reminder_photos/{reminderId}/…)
  // so photos attached on either platform live in one place and cleanup
  // (photo deletion on reminder delete) finds them regardless of origin.
  async uploadPhoto(reminderId: string, uri: string): Promise<string> {
    const filename = `${Date.now()}.jpg`;
    const ref = storage().ref(`reminder_photos/${reminderId}/${filename}`);
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
