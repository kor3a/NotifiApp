// ─── Enums ────────────────────────────────────────────────────────────────────

export type StorePermission = 'owner' | 'edit' | 'view';
export type FriendshipStatus = 'pending' | 'accepted' | 'rejected';
export type SharedReminderStatus = 'pending' | 'accepted' | 'rejected';

// ─── User ─────────────────────────────────────────────────────────────────────

export interface User {
  userId: string;
  name: string;
  email: string;
  profilePictureURL?: string;
  isSubscribed?: boolean;
  adminSubscribed?: boolean;
  fcmToken?: string;
  createdAt?: any;
}

// ─── Store ────────────────────────────────────────────────────────────────────

export interface Store {
  id: string; // normalized name (lowercase-dash-separated)
  name: string;
  reminderCount: number;
  imageURL?: string;
}

// ─── UserStore ────────────────────────────────────────────────────────────────

export interface UserStore {
  id: string; // Firestore doc id
  userId: string;
  storeId: string;
  storeName: string;
  permission: StorePermission;
  order?: number;
  sharedWith?: string[]; // emails of people store is shared with
  sourceUserStoreId?: string; // for view/edit stores
  sharedFromEmail?: string;
  sharedFromName?: string;
  sharedStoreGroupId?: string;
  smartCategoryEnabled?: boolean;
}

// Combined item used in UI
export interface UserStoreItem {
  id: string; // UserStore doc id
  store: Store;
  permission: StorePermission;
  sharedWith?: string[];
  sharedFromName?: string;
  sourceUserStoreId?: string; // recipient: owner's user_store id (where reminders live)
  sharedStoreGroupId?: string;
  isShared: boolean;
}

// Someone a store is currently shared with. Built from the recipient's own
// user_store document, so it only ever describes shares that were accepted —
// a pending request has nothing on the recipient's side yet.
export interface SharedStoreUser {
  id: string; // the recipient's user_store doc id
  userId: string;
  name: string;
  email: string;
  // 'owner' when the recipient merged the store into one they already had, so
  // their reminders keep living in their own document.
  permission: StorePermission;
  sharedAt?: number;
}

// Returns the user_store id under which a store's reminders actually live.
// Owners always use their own id; recipients funnel to the owner's store via
// sourceUserStoreId (or the shared group). Mirrors the iOS app's reminderStoreId.
export function reminderStoreIdFor(item: UserStoreItem): string {
  if (item.permission === 'owner') {
    return item.id;
  }
  return item.sourceUserStoreId ?? item.sharedStoreGroupId ?? item.id;
}

// ─── Reminder ─────────────────────────────────────────────────────────────────

export interface Reminder {
  id: string;
  title: string;
  isDone: boolean;
  userStoreId: string;
  order?: number;
  sortOrder?: number; // the field iOS orders by
  isShared?: boolean;
  sharedReminderId?: string;
  photoURLs?: string[];
  quantity?: number;
  category?: string;
  isOutOfStock?: boolean;
  createdAt?: any;
  updatedAt?: any;
}

// ─── Message ──────────────────────────────────────────────────────────────────

// A store attached to a message as a share request. Field names and shape match
// the `linkedStore` map the iOS app writes and reads, so a share sent from one
// platform can be accepted on the other.
export interface LinkedStore {
  storeName: string;
  storeId: string;
  senderUserId: string;
  senderUserStoreId?: string; // sender's user_store — where the reminders live
  senderEmail?: string; // lets the Firestore rules authorise the sender later
  status?: SharedReminderStatus;
  permission: 'edit' | 'view';
  storeAddress?: string;
  storeLatitude?: number;
  storeLongitude?: number;
  storeImageURL?: string;
  reminderTitles?: string[];
}

export interface Message {
  id: string;
  content: string;
  senderId: string;
  senderName?: string;
  conversationId: string;
  createdAt: any;
  isRead?: boolean;
  linkedReminderId?: string;
  linkedStoreId?: string;
  linkedStoreName?: string;
  linkedStore?: LinkedStore;
}

// Timestamps arrive as either an epoch-seconds number (what iOS writes, and what
// this app now writes too) or a Firestore Timestamp (what older Android builds
// wrote). Normalising here keeps sorting and formatting working across both.
export function timestampMillis(value: any): number {
  if (value == null) {
    return 0;
  }
  if (typeof value === 'number') {
    return value * 1000;
  }
  if (typeof value.toMillis === 'function') {
    return value.toMillis();
  }
  if (typeof value.seconds === 'number') {
    return value.seconds * 1000;
  }
  return 0;
}

// ─── Conversation ─────────────────────────────────────────────────────────────

export interface Conversation {
  id: string;
  participantIds: string[];
  participantNames?: {[uid: string]: string};
  participantPhotos?: {[uid: string]: string};
  lastMessage?: string; // legacy Android-only preview, kept in step on send
  lastMessageContent?: string; // the preview both platforms write and read
  lastMessageAt?: any;
  unreadCount?: {[uid: string]: number};
  createdAt?: any;
}

// ─── Friendship ───────────────────────────────────────────────────────────────

export interface Friendship {
  id: string;
  requesterId: string;
  receiverId: string;
  requesterEmail: string;
  receiverEmail: string;
  requesterName?: string;
  receiverName?: string;
  requesterPhoto?: string;
  receiverPhoto?: string;
  status: FriendshipStatus;
  createdAt?: any;
}

// ─── FavoriteTag ──────────────────────────────────────────────────────────────

export interface FavoriteTag {
  id: string;
  userId: string;
  userStoreId: string;
  title: string;
}

// ─── NotificationLogEntry ─────────────────────────────────────────────────────

export interface NotificationLogEntry {
  id: string;
  storeName: string;
  reminderCount: number;
  timestamp: Date;
}
