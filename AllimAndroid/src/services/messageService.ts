import firestore from '@react-native-firebase/firestore';
import {Conversation, Message} from '../models';

export const messageService = {
  // Subscribe to conversations for a user
  subscribeToConversations(
    uid: string,
    callback: (conversations: Conversation[]) => void,
  ) {
    return firestore()
      .collection('conversations')
      .where('participantIds', 'array-contains', uid)
      .orderBy('lastMessageAt', 'desc')
      .onSnapshot(snap => {
        const convos = snap.docs.map(
          d => ({id: d.id, ...d.data()} as Conversation),
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
      .orderBy('createdAt', 'asc')
      .onSnapshot(snap => {
        const msgs = snap.docs.map(d => ({id: d.id, ...d.data()} as Message));
        callback(msgs);
      });
  },

  // Send a message
  async sendMessage(
    conversationId: string,
    senderId: string,
    senderName: string,
    content: string,
    linkedReminderId?: string,
    linkedStoreName?: string,
  ): Promise<void> {
    const batch = firestore().batch();

    // Add message
    const msgRef = firestore().collection('messages').doc();
    batch.set(msgRef, {
      conversationId,
      senderId,
      senderName,
      content,
      linkedReminderId: linkedReminderId ?? null,
      linkedStoreName: linkedStoreName ?? null,
      createdAt: firestore.FieldValue.serverTimestamp(),
    });

    // Update conversation last message + unread count
    const convoRef = firestore().collection('conversations').doc(conversationId);
    const convoSnap = await convoRef.get();
    if (convoSnap.exists) {
      const data = convoSnap.data()!;
      const participants: string[] = data.participantIds ?? [];
      const unreadUpdate: {[key: string]: any} = {};
      participants
        .filter(id => id !== senderId)
        .forEach(id => {
          unreadUpdate[`unreadCount.${id}`] = firestore.FieldValue.increment(1);
        });
      batch.update(convoRef, {
        lastMessage: content,
        lastMessageAt: firestore.FieldValue.serverTimestamp(),
        ...unreadUpdate,
      });
    }

    await batch.commit();
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
    const ref = await firestore().collection('conversations').add({
      participantIds: [uid1, uid2],
      participantNames: {[uid1]: name1, [uid2]: name2},
      participantPhotos: {
        [uid1]: photo1 ?? '',
        [uid2]: photo2 ?? '',
      },
      lastMessage: '',
      lastMessageAt: firestore.FieldValue.serverTimestamp(),
      unreadCount: {[uid1]: 0, [uid2]: 0},
      createdAt: firestore.FieldValue.serverTimestamp(),
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
