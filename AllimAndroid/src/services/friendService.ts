import firestore from '@react-native-firebase/firestore';
import {Friendship, User} from '../models';

/** The other participant of a friendship, as seen by `currentUserId`. */
export interface FriendInfo {
  userId: string;
  name: string;
  email: string;
  photo?: string;
}

// Empty strings count as unset: iOS writes "" when there is no picture.
function firstPhoto(...urls: (string | null | undefined)[]): string | undefined {
  return urls.find(url => !!url) ?? undefined;
}

function userFromDoc(id: string, data: any): User {
  return {...data, userId: data.userId ?? id} as User;
}

export const friendService = {
  // The friend side of a friendship document, which stores both people.
  friendOf(friendship: Friendship, currentUserId: string): FriendInfo {
    const isRequester = friendship.requesterId === currentUserId;
    const userId = isRequester ? friendship.receiverId : friendship.requesterId;
    return {
      userId,
      name:
        (isRequester ? friendship.receiverName : friendship.requesterName) ||
        userId,
      email:
        (isRequester ? friendship.receiverEmail : friendship.requesterEmail) ??
        '',
      photo: isRequester
        ? firstPhoto(friendship.receiverProfilePictureURL, friendship.receiverPhoto)
        : firstPhoto(friendship.requesterProfilePictureURL, friendship.requesterPhoto),
    };
  },

  // Subscribe to friendships (accepted)
  subscribeToFriends(uid: string, callback: (friends: Friendship[]) => void) {
    return firestore()
      .collection('friends')
      .where('participantIds', 'array-contains', uid)
      .where('status', '==', 'accepted')
      .onSnapshot(snap => {
        const friends = snap.docs.map(
          d => ({id: d.id, ...d.data()} as Friendship),
        );
        callback(friends);
      });
  },

  // Every friendship the user is part of, in any state — the same query the
  // iOS Friends screen splits into friends, received and sent requests.
  subscribeToFriendships(
    uid: string,
    callback: (friendships: Friendship[]) => void,
  ) {
    return firestore()
      .collection('friends')
      .where('participantIds', 'array-contains', uid)
      .onSnapshot(
        snap => {
          callback(snap.docs.map(d => ({id: d.id, ...d.data()} as Friendship)));
        },
        () => callback([]),
      );
  },

  // Subscribe to pending requests received
  subscribeToPendingRequests(
    uid: string,
    callback: (requests: Friendship[]) => void,
  ) {
    return firestore()
      .collection('friends')
      .where('receiverId', '==', uid)
      .where('status', '==', 'pending')
      .onSnapshot(snap => {
        const requests = snap.docs.map(
          d => ({id: d.id, ...d.data()} as Friendship),
        );
        callback(requests);
      });
  },

  // Send friend request
  async sendFriendRequest(
    fromUser: User,
    toUser: User,
  ): Promise<void> {
    // Check existing
    const existing = await firestore()
      .collection('friends')
      .where('participantIds', 'array-contains', fromUser.userId)
      .get();

    for (const doc of existing.docs) {
      const data = doc.data();
      if (!data.participantIds?.includes(toUser.userId) || data.status === 'rejected') {
        continue;
      }
      if (data.status === 'accepted') {
        throw new Error(`You're already friends with ${toUser.name}`);
      }
      if (data.requesterId === fromUser.userId) {
        throw new Error(`Friend request already sent to ${toUser.name}`);
      }
      throw new Error(`${toUser.name} already sent you a friend request`);
    }

    await firestore().collection('friends').add({
      requesterId: fromUser.userId,
      receiverId: toUser.userId,
      requesterEmail: fromUser.email,
      receiverEmail: toUser.email,
      requesterName: fromUser.name,
      receiverName: toUser.name,
      // The field names iOS reads.
      requesterProfilePictureURL: fromUser.profilePictureURL ?? '',
      receiverProfilePictureURL: toUser.profilePictureURL ?? '',
      participantIds: [fromUser.userId, toUser.userId],
      status: 'pending',
      // Epoch seconds, not a server timestamp: iOS drops any friendship whose
      // createdAt does not cast to a TimeInterval.
      createdAt: Date.now() / 1000,
    });
  },

  // Accept friend request
  async acceptRequest(friendshipId: string): Promise<void> {
    await firestore()
      .collection('friends')
      .doc(friendshipId)
      .update({status: 'accepted', acceptedAt: Date.now() / 1000});
  },

  // Reject / decline friend request
  async rejectRequest(friendshipId: string): Promise<void> {
    await firestore().collection('friends').doc(friendshipId).delete();
  },

  // Remove friend
  async removeFriend(friendshipId: string): Promise<void> {
    await firestore().collection('friends').doc(friendshipId).delete();
  },

  // Search users by email
  async searchByEmail(email: string): Promise<User | null> {
    const snap = await firestore()
      .collection('users')
      .where('email', '==', email.toLowerCase().trim())
      .limit(1)
      .get();
    if (snap.empty) {return null;}
    return userFromDoc(snap.docs[0].id, snap.docs[0].data());
  },

  // Search users by username. User documents are keyed by username.
  async searchByUsername(username: string): Promise<User | null> {
    const id = username.trim().replace(/^@/, '').toLowerCase();
    if (!id) {return null;}
    const doc = await firestore().collection('users').doc(id).get();
    const data = doc.data();
    if (!data || !data.name || !data.email) {return null;}
    return userFromDoc(doc.id, data);
  },

  // Fresh profile pictures from the users collection, keyed by userId. The
  // copies on the friendship documents go stale when someone changes photo.
  async fetchProfilePictures(userIds: string[]): Promise<Record<string, string>> {
    const pictures: Record<string, string> = {};
    const ids = Array.from(new Set(userIds)).filter(Boolean);
    // Firestore 'in' queries take at most 30 values.
    for (let i = 0; i < ids.length; i += 30) {
      const snap = await firestore()
        .collection('users')
        .where(firestore.FieldPath.documentId(), 'in', ids.slice(i, i + 30))
        .get();
      snap.docs.forEach(doc => {
        const url = doc.data().profilePictureURL;
        if (url) {pictures[doc.id] = url;}
      });
    }
    return pictures;
  },

  // ─── Family ────────────────────────────────────────────────────────────────
  // Family is a list of friend ids on the user's own document, shared with iOS.

  subscribeToFamilyIds(userId: string, callback: (ids: string[]) => void) {
    return firestore()
      .collection('users')
      .doc(userId)
      .onSnapshot(
        doc => callback((doc.data()?.familyMemberIds as string[]) ?? []),
        () => {},
      );
  },

  async addToFamily(userId: string, friendId: string): Promise<void> {
    await firestore()
      .collection('users')
      .doc(userId)
      .update({familyMemberIds: firestore.FieldValue.arrayUnion(friendId)});
  },

  async removeFromFamily(userId: string, friendId: string): Promise<void> {
    await firestore()
      .collection('users')
      .doc(userId)
      .update({familyMemberIds: firestore.FieldValue.arrayRemove(friendId)});
  },
};
