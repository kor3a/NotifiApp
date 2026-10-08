import firestore from '@react-native-firebase/firestore';
import {Recipe, User, UserStoreItem, reminderStoreIdFor} from '../models';
import {openAIService} from './openAIService';

// Saved recipes live in the `recipes` collection, one document per recipe,
// keyed to the owner by userId — the same documents the iOS RecipeViewModel
// reads and writes, so a recipe saved on one platform shows on the other.

function nowSeconds(): number {
  return Date.now() / 1000;
}

function normalize(title: string): string {
  return title.trim().toLowerCase();
}

export const recipeService = {
  subscribeToRecipes(
    userId: string,
    callback: (recipes: Recipe[]) => void,
    onError?: (err: Error) => void,
  ) {
    return firestore()
      .collection('recipes')
      .where('userId', '==', userId)
      .onSnapshot(
        snap => {
          const recipes: Recipe[] = [];
          snap.docs.forEach(d => {
            const data = d.data();
            // Same shape check iOS applies — anything else is skipped.
            if (
              typeof data.name === 'string' &&
              Array.isArray(data.ingredients) &&
              typeof data.createdAt === 'number'
            ) {
              recipes.push({
                id: d.id,
                name: data.name,
                ingredients: data.ingredients,
                createdAt: data.createdAt,
              });
            }
          });
          recipes.sort((a, b) => a.createdAt - b.createdAt);
          callback(recipes);
        },
        err => onError?.(err),
      );
  },

  async addRecipe(
    user: User,
    name: string,
    ingredients: string[],
  ): Promise<void> {
    // The rules require userEmail to match the signed-in account.
    await firestore().collection('recipes').add({
      userId: user.userId,
      userEmail: user.email,
      name,
      ingredients,
      createdAt: nowSeconds(),
    });
  },

  async updateRecipe(
    id: string,
    name: string,
    ingredients: string[],
  ): Promise<void> {
    await firestore().collection('recipes').doc(id).update({name, ingredients});
  },

  async deleteRecipe(id: string): Promise<void> {
    await firestore().collection('recipes').doc(id).delete();
  },

  // Adds each ingredient to the store's list as a reminder, skipping any the
  // list already has, and returns how many were added. Mirrors the iOS
  // addIngredientsToStore, including the shared-store attribution.
  async addIngredientsToStore(
    ingredients: string[],
    item: UserStoreItem,
    user: User,
    options?: {categorize?: boolean},
  ): Promise<number> {
    const userStoreId = reminderStoreIdFor(item);
    const snap = await firestore()
      .collection('reminders')
      .where('userStoreId', '==', userStoreId)
      .get();

    const existingTitles = new Set<string>();
    let maxOrder = -1;
    snap.docs.forEach(d => {
      const data = d.data();
      if (typeof data.title === 'string') {
        existingTitles.add(normalize(data.title));
      }
      maxOrder = Math.max(maxOrder, data.order ?? data.sortOrder ?? -1);
    });

    // The owner's user_store.sharedWith is only written once a recipient
    // accepts, so recover the recipients from reminders already marked shared
    // when the store's own list is empty — as iOS does.
    let sharedWith = item.sharedWith ?? [];
    if (sharedWith.length === 0) {
      const recovered = new Set<string>();
      snap.docs.forEach(d => {
        const data = d.data();
        if (data.isShared === true && Array.isArray(data.sharedWith)) {
          data.sharedWith.forEach((n: string) => recovered.add(n));
        }
      });
      recovered.delete(user.name);
      sharedWith = [...recovered];
    }
    const isSharedStore = sharedWith.length > 0 || !!item.sharedFromName;

    const batch = firestore().batch();
    const added: {id: string; title: string}[] = [];
    const seen = new Set<string>();

    for (const ingredient of ingredients) {
      const key = normalize(ingredient);
      if (!key || existingTitles.has(key) || seen.has(key)) {
        continue;
      }
      seen.add(key);

      const ref = firestore().collection('reminders').doc();
      const order = maxOrder + 1 + added.length;
      const data: any = {
        title: ingredient.trim(),
        isDone: false,
        userStoreId,
        storeId: item.store.id,
        order,
        sortOrder: order,
        category: null,
        quantity: null,
        photoURLs: [],
        isShared: false,
        createdAt: nowSeconds(),
      };

      if (isSharedStore) {
        data.isShared = true;
        data.sharedAt = nowSeconds();
        // Recipient perspective first, so a recipient shares back to the owner.
        if (item.sharedFromName) {
          data.sharedWith = [item.sharedFromName];
        } else if (sharedWith.length > 0) {
          data.sharedWith = sharedWith;
        }
        data.sharedFrom = user.name;
        data.sharedFromId = user.userId;
      }

      batch.set(ref, data);
      added.push({id: ref.id, title: data.title});
    }

    if (added.length === 0) {
      return 0;
    }
    await batch.commit();

    if (options?.categorize) {
      // Not awaited: the ingredients are in, and a failed categorization only
      // leaves them uncategorized.
      categorizeAdded(added).catch(() => {});
    }
    return added.length;
  },
};

async function categorizeAdded(added: {id: string; title: string}[]) {
  const mapping = await openAIService.categorizeItems(added.map(a => a.title));
  // The model occasionally echoes an item back with different casing.
  const byNormalized = new Map(
    Object.entries(mapping).map(([k, v]) => [normalize(k), v]),
  );

  const batch = firestore().batch();
  let updates = 0;
  added.forEach(({id, title}) => {
    const category = mapping[title] ?? byNormalized.get(normalize(title));
    if (typeof category === 'string' && category && category !== 'Uncategorized') {
      batch.update(firestore().collection('reminders').doc(id), {category});
      updates++;
    }
  });
  if (updates > 0) {
    await batch.commit();
  }
}
