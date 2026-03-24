import firestore from '@react-native-firebase/firestore';
import {Friendship, User} from '../models';

export const friendService = {
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
      if (
        data.participantIds?.includes(toUser.userId) ||
        data.participantIds?.includes(fromUser.userId)
      ) {
        if (data.requesterId === fromUser.userId && data.receiverId === toUser.userId) {
          throw new Error('Friend request already sent');
        }
        if (data.status === 'accepted') {
          throw new Error('Already friends');
        }
      }
    }

    await firestore().collection('friends').add({
      requesterId: fromUser.userId,
      receiverId: toUser.userId,
      requesterEmail: fromUser.email,
      receiverEmail: toUser.email,
      requesterName: fromUser.name,
      receiverName: toUser.name,
      requesterPhoto: fromUser.profilePictureURL ?? null,
      receiverPhoto: toUser.profilePictureURL ?? null,
      participantIds: [fromUser.userId, toUser.userId],
      status: 'pending',
      createdAt: firestore.FieldValue.serverTimestamp(),
    });
  },

  // Accept friend request
  async acceptRequest(friendshipId: string): Promise<void> {
    await firestore()
      .collection('friends')
      .doc(friendshipId)
      .update({status: 'accepted'});
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
    return snap.docs[0].data() as User;
  },
};
