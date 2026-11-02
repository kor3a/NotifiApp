import { collection, query, where } from "firebase/firestore";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { useConversations, useLiveQuery } from "../data";
import { db } from "../firebase";
import { markRead, sendMessage } from "../messaging";
import { href } from "../router";
import { useUser } from "../auth";
import type { Conversation, Message } from "../types";
import { cx, timeAgo } from "../format";
import { Avatar, Button, Card, Empty, ErrorNote, PageHeader, Spinner, TextInput } from "../ui";

function titleOf(c: Conversation, me: string) {
  if (c.isGroup) return c.groupName ?? "Group";
  const otherId = c.participantIds.find((id) => id !== me);
  return (otherId && c.participantNames[otherId]) || "Unknown";
}

export default function Messages({ conversationId }: { conversationId?: string }) {
  const user = useUser();
  const conversations = useConversations(user.userId);
  const active = conversations.data.find((c) => c.id === conversationId);

  return (
    <>
      <PageHeader title="Messages" subtitle="Chat with friends and share lists." />
      {conversations.error && <ErrorNote>{conversations.error}</ErrorNote>}
      {conversations.loading ? (
        <Spinner />
      ) : conversations.data.length === 0 ? (
        <Empty title="No conversations">Start one from a friend's row on the Friends tab.</Empty>
      ) : (
        <Card className="flex h-[calc(100vh-15rem)] min-h-[420px] overflow-hidden lg:h-[calc(100vh-13rem)]">
          <ul className={cx("w-full overflow-y-auto border-line/70 md:w-72 md:shrink-0 md:border-r", active && "hidden md:block")}>
            {conversations.data.map((c) => {
              const unread = c.unreadCount?.[user.userId] ?? 0;
              const name = titleOf(c, user.userId);
              return (
                <li key={c.id}>
                  <a
                    href={href({ name: "messages", conversationId: c.id })}
                    className={cx("flex items-center gap-3 border-b border-line/50 px-4 py-3 transition-colors", c.id === conversationId ? "bg-wash" : "hover:bg-paper")}
                  >
                    <Avatar name={name} size={40} />
                    <div className="min-w-0 flex-1">
                      <div className="flex items-baseline gap-2">
                        <p className={cx("truncate text-[15px] text-ink", unread ? "font-bold" : "font-semibold")}>{name}</p>
                        <span className="ml-auto shrink-0 text-[12px] text-ink-3">{timeAgo(c.lastMessageAt)}</span>
                      </div>
                      <p className={cx("truncate text-[13px]", unread ? "text-ink" : "text-ink-3")}>
                        {c.lastMessageContent || "No messages yet"}
                      </p>
                    </div>
                    {unread > 0 && <span className="h-2.5 w-2.5 shrink-0 rounded-full bg-orange" aria-label={`${unread} unread`} />}
                  </a>
                </li>
              );
            })}
          </ul>
          {active ? (
            <Thread key={active.id} conversation={active} />
          ) : (
            <div className="hidden flex-1 items-center justify-center text-[15px] text-ink-3 md:flex">Pick a conversation</div>
          )}
        </Card>
      )}
    </>
  );
}

function Thread({ conversation }: { conversation: Conversation }) {
  const user = useUser();
  const messages = useLiveQuery<Message>(`messages:${conversation.id}`, () =>
    query(collection(db, "messages"), where("conversationId", "==", conversation.id)),
  );
  const sorted = [...messages.data].sort((a, b) => a.createdAt - b.createdAt);
  const [text, setText] = useState("");
  const [error, setError] = useState("");
  const bottom = useRef<HTMLDivElement>(null);
  const unread = conversation.unreadCount?.[user.userId] ?? 0;

  useEffect(() => {
    bottom.current?.scrollIntoView({ block: "end" });
  }, [sorted.length]);

  useEffect(() => {
    if (unread > 0) markRead(conversation.id, user.userId).catch(() => {});
  }, [conversation.id, user.userId, unread]);

  async function submit(e: FormEvent) {
    e.preventDefault();
    const content = text.trim();
    if (!content) return;
    setText("");
    try {
      await sendMessage(conversation, user, content);
    } catch (err) {
      setError((err as Error).message);
      setText(content);
    }
  }

  return (
    <div className="flex min-w-0 flex-1 flex-col">
      <div className="flex items-center gap-3 border-b border-line/70 px-4 py-3">
        <a href={href({ name: "messages" })} className="text-[20px] text-teal md:hidden" aria-label="Back">‹</a>
        <p className="truncate text-[16px] font-bold text-ink">{titleOf(conversation, user.userId)}</p>
        {conversation.isGroup && <p className="truncate text-[13px] text-ink-3">{Object.values(conversation.participantNames).join(", ")}</p>}
      </div>

      <div className="flex-1 space-y-2 overflow-y-auto bg-paper/50 px-4 py-4">
        {messages.loading && <Spinner />}
        {sorted.map((m, i) => {
          const mine = m.senderId === user.userId;
          const showName = conversation.isGroup && !mine && sorted[i - 1]?.senderId !== m.senderId;
          return (
            <div key={m.id} className={cx("flex flex-col", mine ? "items-end" : "items-start")}>
              {showName && <span className="mb-0.5 px-2 text-[12px] text-ink-3">{m.senderName}</span>}
              <div className={cx("max-w-[78%] rounded-2xl px-3.5 py-2 text-[15px] leading-snug", mine ? "rounded-br-md bg-teal text-white" : "rounded-bl-md bg-card text-ink shadow-sm")}>
                {m.photoURLs?.map((u) => <img key={u} src={u} alt="" className="mb-1 max-h-60 rounded-lg" />)}
                {m.linkedStore && (
                  <Attachment mine={mine} label="Shared a store" title={m.linkedStore.storeName} detail={m.linkedStore.reminderTitles?.join(", ")} />
                )}
                {m.linkedReminder && (
                  <Attachment mine={mine} label={`Item for ${m.linkedReminder.storeName}`} title={m.linkedReminder.reminderTitle} />
                )}
                {m.content && <p className="whitespace-pre-wrap break-words">{m.content}</p>}
              </div>
              <span className="mt-0.5 px-2 text-[11px] text-ink-3">{timeAgo(m.createdAt)}</span>
            </div>
          );
        })}
        <div ref={bottom} />
      </div>

      {error && <div className="px-4 pt-2"><ErrorNote>{error}</ErrorNote></div>}
      <form onSubmit={submit} className="flex gap-2 border-t border-line/70 p-3">
        <TextInput placeholder="Message" value={text} onChange={(e) => setText(e.target.value)} className="flex-1" />
        <Button type="submit" disabled={!text.trim()}>Send</Button>
      </form>
    </div>
  );
}

function Attachment({ mine, label, title, detail }: { mine: boolean; label: string; title: string; detail?: string }) {
  return (
    <div className={cx("mb-1 rounded-xl px-3 py-2", mine ? "bg-white/15" : "bg-wash")}>
      <p className={cx("text-[11px] font-semibold", mine ? "text-white/80" : "text-on-wash")}>{label}</p>
      <p className="font-bold">{title}</p>
      {detail && <p className={cx("text-[13px]", mine ? "text-white/80" : "text-ink-2")}>{detail}</p>}
      <p className={cx("mt-1 text-[11px]", mine ? "text-white/70" : "text-ink-3")}>Accept it in the phone app</p>
    </div>
  );
}
