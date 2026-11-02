import {
  addDoc,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDocs,
  query,
  updateDoc,
  where,
  writeBatch,
} from "firebase/firestore";
import { categorizeItems } from "./ai";
import { db } from "./firebase";
import { nowSeconds, reminderStoreId, type AppUser, type Reminder, type UserStore } from "./types";

/**
 * Writes to a store's list, matching ReminderViewModel / ReminderToggleService
 * on iOS field for field so the phone apps render web edits the same way.
 */

function isSharedStore(store: UserStore) {
  return (store.sharedWith?.length ?? 0) > 0 || store.permission !== "owner";
}

/**
 * Adds items to the end of a store's list, skipping any already on it
 * (case-insensitively), then files them into aisles with Smart Category.
 * Returns how many were added.
 */
export async function addItems(
  store: UserStore,
  user: AppUser,
  items: { title: string; quantity?: number }[],
): Promise<number> {
  const listId = reminderStoreId(store);
  const existing = await getDocs(query(collection(db, "reminders"), where("userStoreId", "==", listId)));
  const taken = new Set(existing.docs.map((d) => String(d.data().title).trim().toLowerCase()));
  let nextSort =
    Math.max(-1, ...existing.docs.map((d) => (d.data().sortOrder as number | undefined) ?? -1)) + 1;

  const fresh = items
    .map((i) => ({ ...i, title: i.title.trim() }))
    .filter((i) => i.title && !taken.has(i.title.toLowerCase()) && taken.add(i.title.toLowerCase()));
  if (fresh.length === 0) return 0;

  const shared = isSharedStore(store);
  const sharedFromName = store.permission !== "owner" ? (store.sharedFromName ?? store.sharedFrom) : undefined;
  const batch = writeBatch(db);
  const created: { id: string; title: string }[] = [];

  for (const item of fresh) {
    const ref = doc(collection(db, "reminders"));
    const data: Record<string, unknown> = {
      userStoreId: listId,
      title: item.title,
      isDone: false,
      createdAt: nowSeconds(),
      sortOrder: nextSort++,
    };
    if (item.quantity && item.quantity > 1) data.quantity = item.quantity;
    if (shared) {
      data.isShared = true;
      data.sharedAt = nowSeconds();
      if (sharedFromName) data.sharedWith = [sharedFromName];
      else if (store.sharedWith?.length) data.sharedWith = store.sharedWith;
      data.sharedFrom = user.name;
      data.sharedFromId = user.userId;
    }
    batch.set(ref, data);
    created.push({ id: ref.id, title: item.title });
  }
  await batch.commit();

  // Smart Category runs after the write so a slow or failed AI call never loses an item.
  categorizeItems(created.map((c) => c.title))
    .then((map) => {
      const b = writeBatch(db);
      for (const c of created) {
        const category = map[c.title];
        if (category && category !== "Uncategorized") b.update(doc(db, "reminders", c.id), { category });
      }
      return b.commit();
    })
    .catch(() => {});

  return created.length;
}

export function toggleDone(r: Reminder, user: AppUser) {
  const done = !r.isDone;
  return updateDoc(
    doc(db, "reminders", r.id),
    done
      ? { isDone: true, checkedOffAt: nowSeconds(), checkedOffBy: user.name, checkedOffById: user.userId, isOutOfStock: false }
      : { isDone: false, checkedOffAt: deleteField(), checkedOffBy: deleteField(), checkedOffById: deleteField() },
  );
}

function stampEdit(user: AppUser) {
  return { lastEditedAt: nowSeconds(), lastEditedBy: user.name, lastEditedById: user.userId };
}

export function setQuantity(r: Reminder, quantity: number, user: AppUser) {
  return updateDoc(doc(db, "reminders", r.id), {
    quantity: quantity > 1 ? quantity : deleteField(),
    ...stampEdit(user),
  });
}

export function toggleOutOfStock(r: Reminder, user: AppUser) {
  return updateDoc(doc(db, "reminders", r.id), { isOutOfStock: !r.isOutOfStock, ...stampEdit(user) });
}

export function rename(r: Reminder, title: string, user: AppUser) {
  return updateDoc(doc(db, "reminders", r.id), { title, ...stampEdit(user) });
}

/** Deleting a checked-off item keeps a copy in reminder_history, as the History screen expects. */
export async function deleteItem(r: Reminder, user: AppUser) {
  if (r.isDone) {
    const entry: Record<string, unknown> = {
      userStoreId: r.userStoreId,
      title: r.title,
      checkedOffAt: r.checkedOffAt ?? nowSeconds(),
      deletedAt: nowSeconds(),
      createdAt: r.createdAt,
      createdBy: r.sharedFrom ?? user.name,
      createdById: r.sharedFromId ?? user.userId,
    };
    if (r.quantity) entry.quantity = r.quantity;
    if (r.photoURLs?.length) entry.photoURLs = r.photoURLs;
    if (r.category) entry.category = r.category;
    if (r.checkedOffBy) entry.checkedOffBy = r.checkedOffBy;
    if (r.checkedOffById) entry.checkedOffById = r.checkedOffById;
    await addDoc(collection(db, "reminder_history"), entry).catch(() => {});
  }
  await deleteDoc(doc(db, "reminders", r.id));
}
