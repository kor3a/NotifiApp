import firestore, {
  FirebaseFirestoreTypes,
} from '@react-native-firebase/firestore';
import {UserStoreItem} from '../models';

export interface SharedUser {
  userId: string;
  email: string;
}

// The parts of a store's user_store entry that say who else is on it.
export type SharedStoreRef = Pick<
  UserStoreItem,
  'id' | 'permission' | 'sourceUserStoreId' | 'sharedStoreGroupId'
>;

// Everyone sharing the store, minus the current user — the same three cases
// the iOS SharedReminderNotificationService.findSharedUsers covers.
//
// With `respectNotificationPreference`, a member who turned notifications off
// for the store (`notificationsEnabled: false` on their user_store) is left
// out, as iOS does for "Reminder Updated" pushes.
export async function findSharedUsers(
  item: SharedStoreRef,
  currentUserId: string,
  options: {respectNotificationPreference?: boolean} = {},
): Promise<SharedUser[]> {
  const users = new Map<string, SharedUser>();
  const userStores = firestore().collection('user_stores');

  function collect(
    docs: {data(): FirebaseFirestoreTypes.DocumentData | undefined}[],
  ) {
    docs.forEach(doc => {
      const data = doc.data() ?? {};
      const userId = data.userId as string | undefined;
      const email = data.userEmail as string | undefined;
      if (!userId || !email || userId === currentUserId) {
        return;
      }
      if (
        options.respectNotificationPreference &&
        data.notificationsEnabled === false
      ) {
        return;
      }
      users.set(userId, {userId, email});
    });
  }

  const lookups: Promise<void>[] = [];

  // The current user owns the store: everyone who accepted a share of it.
  if (item.permission === 'owner') {
    lookups.push(
      userStores
        .where('sourceUserStoreId', '==', item.id)
        .get()
        .then(snap => collect(snap.docs))
        .catch(() => {}),
    );
  }

  // Legacy "Can Edit" group: every co-editor.
  if (item.sharedStoreGroupId) {
    lookups.push(
      userStores
        .where('sharedStoreGroupId', '==', item.sharedStoreGroupId)
        .get()
        .then(snap => collect(snap.docs))
        .catch(() => {}),
    );
  }

  // The current user was given the store: the owner, and everyone else the
  // owner shared it with.
  if (item.sourceUserStoreId) {
    const sourceId = item.sourceUserStoreId;
    lookups.push(
      (async () => {
        try {
          const owner = await userStores.doc(sourceId).get();
          if (owner.exists) {
            collect([owner]);
          }
        } catch (_) {}
        try {
          const others = await userStores
            .where('sourceUserStoreId', '==', sourceId)
            .get();
          collect(others.docs);
        } catch (_) {}
      })(),
    );
  }

  await Promise.all(lookups);
  return Array.from(users.values());
}
