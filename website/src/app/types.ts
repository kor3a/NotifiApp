/**
 * Firestore document shapes, mirrored from the Swift models in
 * Geolocation_v1.0.0/Models. Field names must match exactly: the iOS and
 * Android apps read whatever this client writes.
 */

/** users/{username}. The document ID is the username, which is also `userId`. */
export interface AppUser {
  userId: string;
  name: string;
  email: string;
  joined: number;
  profilePictureURL?: string;
  isSubscribed?: boolean;
  adminSubscribed?: boolean;
}

export type StorePermission = "owner" | "edit" | "view";

/** user_stores/{id}: one store pinned by one user. */
export interface UserStore {
  id: string;
  userId: string;
  userEmail?: string;
  storeId: string;
  storeName: string;
  storeAddress?: string;
  addedAt: number;
  sortOrder?: number;
  permission: StorePermission;
  sharedStoreGroupId?: string;
  sourceUserStoreId?: string;
  sharedFrom?: string;
  sharedFromName?: string;
  sharedWith?: string[];
  notificationsEnabled?: boolean;
  imageURL?: string;
}

/** reminders/{id}: one item on one store's list. */
export interface Reminder {
  id: string;
  userStoreId: string;
  title: string;
  isDone: boolean;
  createdAt: number;
  isShared?: boolean;
  sharedFrom?: string;
  sharedFromId?: string;
  photoURLs?: string[];
  sortOrder?: number;
  quantity?: number;
  isOutOfStock?: boolean;
  category?: string;
  checkedOffAt?: number;
  checkedOffBy?: string;
  checkedOffById?: string;
  lastEditedBy?: string;
}

/** recipes/{id}: a saved recipe, owned by `userId`. */
export interface Recipe {
  id: string;
  userId: string;
  userEmail: string;
  name: string;
  ingredients: string[];
  createdAt: number;
}

export type FriendshipStatus = "pending" | "accepted" | "rejected";

/** friends/{id}: one friendship, from request to acceptance. */
export interface Friendship {
  id: string;
  requesterId: string;
  requesterName: string;
  requesterEmail: string;
  requesterProfilePictureURL?: string;
  receiverId: string;
  receiverName: string;
  receiverEmail: string;
  receiverProfilePictureURL?: string;
  status: FriendshipStatus;
  createdAt: number;
  acceptedAt?: number;
  participantIds: string[];
}

/** conversations/{id}: a 1:1 or group thread. */
export interface Conversation {
  id: string;
  participantIds: string[];
  participantEmails?: string[];
  participantNames: Record<string, string>;
  createdAt: number;
  lastMessageContent?: string;
  lastMessageAt?: number;
  lastMessageSenderId?: string;
  unreadCount?: Record<string, number>;
  isGroup?: boolean;
  groupName?: string;
}

/** messages/{id}: one message in a conversation. */
export interface Message {
  id: string;
  conversationId: string;
  senderId: string;
  senderName: string;
  content: string;
  createdAt: number;
  isRead: boolean;
  photoURLs?: string[];
  linkedReminder?: { reminderTitle: string; storeName: string; status?: string };
  linkedStore?: { storeName: string; permission: string; status?: string; reminderTitles?: string[] };
}

/** The ID reminders are filed under. Mirrors `UserStore.reminderStoreId` in Swift. */
export function reminderStoreId(store: UserStore): string {
  if (store.permission === "owner") return store.id;
  return store.sourceUserStoreId ?? store.sharedStoreGroupId ?? store.id;
}

/** Mirrors `Store.normalizedId(from:)` in Swift, so every client files a chain under the same ID. */
export function normalizedStoreId(name: string): string {
  return name
    .toLowerCase()
    .trim()
    .replaceAll(" ", "-")
    .replaceAll("'", "")
    .replaceAll(".", "")
    .replaceAll(",", "")
    .replaceAll("&", "and");
}

/** Firestore timestamps in this project are seconds since 1970, as `Date().timeIntervalSince1970` writes them. */
export const nowSeconds = () => Date.now() / 1000;
