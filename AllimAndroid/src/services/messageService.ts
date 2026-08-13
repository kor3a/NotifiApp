import firestore from '@react-native-firebase/firestore';
import {Conversation, LinkedStore, Message, timestampMillis} from '../models';

// Timestamps are written as epoch seconds rather than a server timestamp: it is
// the format the iOS app writes and the only one it parses, so a message sent
// from Android is invisible there otherwise. Documents written by older Android
// builds still hold Firestore Timestamps, so ordering is done in JS via
// timestampMillis() instead of orderBy() — Firestore sorts by type first, which
// would otherwise split a thread into two blocks.
function nowSeconds(): number {
  return Date.now() / 1000;
}

export const messageService = {
  // Subscribe to conversations for a user
  subscribeToConversations(
    uid: string,
    callback: (conversations: Conversation[]) => void,
  ) {
    return firestore()
      .collection('conversations')
      .where('participantIds', 'array-contains', uid)
      .onSnapshot(snap => {
        const convos = snap.docs
          .map(d => ({id: d.id, ...d.data()} as Conversation))
          .sort(
            (a, b) =>
              timestampMillis(b.lastMessageAt) - timestampMillis(a.lastMessageAt),
          );
        callback(convos);
      });
  },

  // Subscribe to messages in a conversation
  subscribeToMessages(
    conversationId: string,
    callback: (messages: Message[]) => void,
  ) {
    return firestore()
      .collection('messages')
      .where('conversationId', '==', conversationId)
      .onSnapshot(snap => {
        const msgs = snap.docs
          .map(d => ({id: d.id, ...d.data()} as Message))
          .sort(
            (a, b) => timestampMillis(a.createdAt) - timestampMillis(b.createdAt),
          );
        callback(msgs);
      });
  },

  // Send a message
  async sendMessage(
    conversationId: string,
    senderId: string,
    senderName: string,
    content: string,
    options?: {
      linkedReminderId?: string;
      linkedStoreName?: string;
      linkedStore?: LinkedStore;
    },
  ): Promise<string> {
    const batch = firestore().batch();

    // Add message
    const msgRef = firestore().collection('messages').doc();
    const data: {[key: string]: any} = {
      conversationId,
      senderId,
      senderName,
      content,
      linkedReminderId: options?.linkedReminderId ?? null,
      linkedStoreName: options?.linkedStoreName ?? null,
      createdAt: nowSeconds(),
      isRead: false,
    };
    if (options?.linkedStore) {
      // Undefined values are rejected by Firestore, so only keep what is set.
      data.linkedStore = Object.fromEntries(
        Object.entries(options.linkedStore).filter(([, v]) => v !== undefined),
      );
    }
    batch.set(msgRef, data);

    // Update conversation last message + unread count. `lastMessageContent` is
    // the preview both platforms read; `lastMessage` is written alongside it
    // only so older Android builds, which read that field first, stay current.
    const convoRef = firestore().collection('conversations').doc(conversationId);
    const convoSnap = await convoRef.get();
    if (convoSnap.exists) {
      const convoData = convoSnap.data()!;
      const participants: string[] = convoData.participantIds ?? [];
      const unreadUpdate: {[key: string]: any} = {};
      participants
        .filter(id => id !== senderId)
        .forEach(id => {
          unreadUpdate[`unreadCount.${id}`] = firestore.FieldValue.increment(1);
        });
      batch.update(convoRef, {
        lastMessage: content,
        lastMessageContent: content,
        lastMessageSenderId: senderId,
        lastMessageAt: nowSeconds(),
        ...unreadUpdate,
      });
    }

    await batch.commit();
    return msgRef.id;
  },

  // Create conversation between two users
  async getOrCreateConversation(
    uid1: string,
    uid2: string,
    name1: string,
    name2: string,
    photo1?: string,
    photo2?: string,
  ): Promise<string> {
    const existing = await firestore()
      .collection('conversations')
      .where('participantIds', 'array-contains', uid1)
      .get();

    for (const doc of existing.docs) {
      const data = doc.data();
      if (data.participantIds?.includes(uid2)) {
        return doc.id;
      }
    }

    // Create new
    const ref = await firestore()
      .collection('conversations')
      .add({
        participantIds: [uid1, uid2],
        participantNames: {[uid1]: name1, [uid2]: name2},
        participantPhotos: {
          [uid1]: photo1 ?? '',
          [uid2]: photo2 ?? '',
        },
        lastMessage: '',
        lastMessageContent: '',
        lastMessageAt: nowSeconds(),
        unreadCount: {[uid1]: 0, [uid2]: 0},
        createdAt: nowSeconds(),
      });
    return ref.id;
  },

  // Mark messages as read
  async markAsRead(conversationId: string, uid: string): Promise<void> {
    await firestore()
      .collection('conversations')
      .doc(conversationId)
      .update({[`unreadCount.${uid}`]: 0});
  },

  // Get total unread count
  async getTotalUnreadCount(uid: string): Promise<number> {
    const snap = await firestore()
      .collection('conversations')
      .where('participantIds', 'array-contains', uid)
      .get();
    return snap.docs.reduce((total, doc) => {
      const data = doc.data();
      return total + ((data.unreadCount?.[uid] as number) ?? 0);
    }, 0);
  },
};
