import firestore, {
  FirebaseFirestoreTypes,
} from '@react-native-firebase/firestore';
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

// A commit takes at most 500 writes; deleting a long thread needs several.
const BATCH_LIMIT = 450;

async function commitDeletes(
  refs: FirebaseFirestoreTypes.DocumentReference[],
): Promise<void> {
  for (let i = 0; i < refs.length; i += BATCH_LIMIT) {
    const batch = firestore().batch();
    refs.slice(i, i + BATCH_LIMIT).forEach(ref => batch.delete(ref));
    await batch.commit();
  }
}

// Emails for a set of usernames, the way iOS resolves them before writing a
// conversation: the rules can only match an auth token against an email, so a
// conversation that carries only usernames can't be checked for membership.
// Firestore `in` queries take at most 10 values, hence the chunking.
async function resolveParticipantEmails(userIds: string[]): Promise<string[]> {
  const unique = [...new Set(userIds.map(id => id.toLowerCase()).filter(Boolean))];
  const emails = new Set<string>();
  for (let i = 0; i < unique.length; i += 10) {
    const chunk = unique.slice(i, i + 10);
    const snap = await firestore()
      .collection('users')
      .where('userId', 'in', chunk)
      .get();
    snap.docs.forEach(doc => {
      const email = doc.data().email as string | undefined;
      if (email) {
        emails.add(email);
      }
    });
  }
  return [...emails];
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

    // Create new. participantEmails mirrors what iOS writes — without it a
    // conversation started here can't be checked for membership by the rules.
    const ref = await firestore()
      .collection('conversations')
      .add({
        participantIds: [uid1, uid2],
        participantEmails: await resolveParticipantEmails([uid1, uid2]),
        participantNames: {[uid1]: name1, [uid2]: name2},
        participantPhotos: {
          [uid1]: photo1 ?? '',
          [uid2]: photo2 ?? '',
        },
        lastMessage: '',
        lastMessageContent: '',
        // Creation time, not 0, so the conversation sorts into the list before
        // anyone has said anything.
        lastMessageAt: nowSeconds(),
        lastMessageSenderId: '',
        unreadCount: {[uid1]: 0, [uid2]: 0},
        createdAt: nowSeconds(),
      });
    return ref.id;
  },

  // Delete a conversation and every message in it, as iOS's
  // MessagingService.deleteConversation does. The conversation document goes
  // last so a failure part-way through leaves the thread visible rather than
  // stranding its messages behind a row that is already gone.
  async deleteConversation(conversationId: string): Promise<void> {
    const msgs = await firestore()
      .collection('messages')
      .where('conversationId', '==', conversationId)
      .get();

    const refs: FirebaseFirestoreTypes.DocumentReference[] = msgs.docs.map(
      d => d.ref,
    );
    refs.push(firestore().collection('conversations').doc(conversationId));
    await commitDeletes(refs);
  },

  // Remove a member from a group conversation. Used to leave a group the user
  // does not own — iOS's removeGroupMember, which the Messages list calls when
  // a non-owner swipes a group away. participantEmails is recomputed so the
  // departing member loses read access.
  async removeGroupMember(
    conversationId: string,
    userId: string,
  ): Promise<void> {
    const ref = firestore().collection('conversations').doc(conversationId);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new Error('Conversation not found');
    }
    const data = snap.data()!;

    const participantIds: string[] = (data.participantIds ?? []).filter(
      (id: string) => id !== userId,
    );
    const participantNames = {...(data.participantNames ?? {})};
    delete participantNames[userId];
    const unreadCount = {...(data.unreadCount ?? {})};
    delete unreadCount[userId];

    const update: {[key: string]: any} = {
      participantIds,
      participantEmails: await resolveParticipantEmails(participantIds),
      participantNames,
      unreadCount,
    };

    // participantPhotos is Android-only — leave the field alone on documents
    // written by iOS rather than introducing an empty map.
    if (data.participantPhotos) {
      const participantPhotos = {...data.participantPhotos};
      delete participantPhotos[userId];
      update.participantPhotos = participantPhotos;
    }

    await ref.update(update);
  },

  // Profile picture URLs for conversation participants, read from their user
  // documents. Conversations created on iOS carry no participantPhotos map, so
  // the avatar has to come from the same place iOS reads it from.
  async fetchParticipantPhotos(
    userIds: string[],
  ): Promise<{[uid: string]: string}> {
    const unique = [...new Set(userIds.filter(Boolean))];
    const photos: {[uid: string]: string} = {};
    for (let i = 0; i < unique.length; i += 10) {
      const chunk = unique.slice(i, i + 10);
      try {
        const snap = await firestore()
          .collection('users')
          .where('userId', 'in', chunk)
          .get();
        snap.docs.forEach(doc => {
          const data = doc.data();
          const url = data.profilePictureURL as string | undefined;
          if (data.userId && url) {
            photos[data.userId as string] = url;
          }
        });
      } catch (_) {
        // A failed lookup only costs an avatar — the row falls back to initials.
      }
    }
    return photos;
  },

  // Mark messages as read: clear this user's unread count and flip the incoming
  // message documents to isRead, which iOS does too — without it a message sent
  // from iOS stays unread there forever once it is opened here. The sender
  // filter runs in JS so the query needs no composite index.
  async markAsRead(conversationId: string, uid: string): Promise<void> {
    await firestore()
      .collection('conversations')
      .doc(conversationId)
      .update({[`unreadCount.${uid}`]: 0});

    const unread = await firestore()
      .collection('messages')
      .where('conversationId', '==', conversationId)
      .where('isRead', '==', false)
      .get();

    const incoming = unread.docs.filter(doc => doc.data().senderId !== uid);
    for (let i = 0; i < incoming.length; i += BATCH_LIMIT) {
      const batch = firestore().batch();
      incoming
        .slice(i, i + BATCH_LIMIT)
        .forEach(doc => batch.update(doc.ref, {isRead: true}));
      await batch.commit();
    }
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
