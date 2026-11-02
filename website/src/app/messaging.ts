import {
  addDoc,
  collection,
  doc,
  getDocs,
  increment,
  query,
  updateDoc,
  where,
  writeBatch,
} from "firebase/firestore";
import { db } from "./firebase";
import { nowSeconds, type AppUser, type Conversation } from "./types";

/** Writes for Messages, matching MessagingService.swift. */

/** The existing 1:1 thread with this person, or a new one. Resolves to its ID. */
export async function openConversationWith(
  me: AppUser,
  them: { userId: string; name: string; email: string },
): Promise<string> {
  const snap = await getDocs(
    query(collection(db, "conversations"), where("participantIds", "array-contains", me.userId)),
  );
  const existing = snap.docs.find((d) => {
    const c = d.data() as Conversation;
    return !c.isGroup && c.participantIds.length === 2 && c.participantIds.includes(them.userId);
  });
  if (existing) return existing.id;

  const now = nowSeconds();
  const ref = await addDoc(collection(db, "conversations"), {
    participantIds: [me.userId, them.userId],
    participantEmails: [me.email, them.email],
    participantNames: { [me.userId]: me.name, [them.userId]: them.name },
    createdAt: now,
    lastMessageContent: "",
    lastMessageAt: now,
    lastMessageSenderId: "",
    unreadCount: { [me.userId]: 0, [them.userId]: 0 },
  });
  return ref.id;
}

export async function sendMessage(conversation: Conversation, me: AppUser, content: string) {
  const now = nowSeconds();
  await addDoc(collection(db, "messages"), {
    conversationId: conversation.id,
    senderId: me.userId,
    senderName: me.name,
    content,
    createdAt: now,
    isRead: false,
  });
  // Bump everyone else's unread count. increment() keeps two people sending
  // at once from overwriting each other, which the read-modify-write on iOS can.
  const bumps: Record<string, unknown> = {};
  for (const id of conversation.participantIds) {
    if (id !== me.userId) bumps[`unreadCount.${id}`] = increment(1);
  }
  await updateDoc(doc(db, "conversations", conversation.id), {
    lastMessageContent: content,
    lastMessageAt: now,
    lastMessageSenderId: me.userId,
    ...bumps,
  });
}

export async function markRead(conversationId: string, userId: string) {
  const snap = await getDocs(
    query(
      collection(db, "messages"),
      where("conversationId", "==", conversationId),
      where("isRead", "==", false),
    ),
  );
  const batch = writeBatch(db);
  snap.docs.filter((d) => d.data().senderId !== userId).forEach((d) => batch.update(d.ref, { isRead: true }));
  batch.update(doc(db, "conversations", conversationId), { [`unreadCount.${userId}`]: 0 });
  await batch.commit();
}
