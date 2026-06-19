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

export interface Message {
  id: string;
  content: string;
  senderId: string;
  senderName?: string;
  conversationId: string;
  createdAt: any;
  linkedReminderId?: string;
  linkedStoreId?: string;
  linkedStoreName?: string;
}

// ─── Conversation ─────────────────────────────────────────────────────────────

export interface Conversation {
  id: string;
  participantIds: string[];
  participantNames?: {[uid: string]: string};
  participantPhotos?: {[uid: string]: string};
  lastMessage?: string;
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
