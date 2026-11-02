import { addDoc, collection, deleteDoc, doc, getDoc, updateDoc } from "firebase/firestore";
import { useState, type FormEvent } from "react";
import { useFriendships } from "../data";
import { db } from "../firebase";
import { openConversationWith } from "../messaging";
import { navigate } from "../router";
import { useUser } from "../auth";
import { nowSeconds, type AppUser, type Friendship } from "../types";
import { timeAgo } from "../format";
import { Avatar, Button, Card, Empty, ErrorNote, PageHeader, Spinner, TextInput } from "../ui";

function other(f: Friendship, me: string) {
  const mine = f.requesterId === me;
  return {
    id: mine ? f.receiverId : f.requesterId,
    name: mine ? f.receiverName : f.requesterName,
    email: mine ? f.receiverEmail : f.requesterEmail,
    photo: (mine ? f.receiverProfilePictureURL : f.requesterProfilePictureURL) || undefined,
  };
}

export default function Friends() {
  const user = useUser();
  const friendships = useFriendships(user.userId);
  const [error, setError] = useState("");

  const accepted = friendships.data.filter((f) => f.status === "accepted").sort((a, b) => other(a, user.userId).name.localeCompare(other(b, user.userId).name));
  const incoming = friendships.data.filter((f) => f.status === "pending" && f.receiverId === user.userId);
  const outgoing = friendships.data.filter((f) => f.status === "pending" && f.requesterId === user.userId);

  const guard = (p: Promise<unknown>) => p.catch((e: Error) => setError(e.message));

  return (
    <>
      <PageHeader title="Friends" subtitle="Share stores and lists with the people you shop with." />
      <AddFriend existing={friendships.data} />
      {error && <div className="mb-4"><ErrorNote>{error}</ErrorNote></div>}

      {friendships.loading ? (
        <Spinner />
      ) : (
        <div className="space-y-6">
          {incoming.length > 0 && (
            <Section title={`Requests · ${incoming.length}`}>
              {incoming.map((f) => {
                const o = other(f, user.userId);
                return (
                  <PersonRow key={f.id} name={o.name} sub={`@${o.id} · ${timeAgo(f.createdAt)}`} photo={o.photo}>
                    <Button onClick={() => guard(updateDoc(doc(db, "friends", f.id), { status: "accepted", acceptedAt: nowSeconds() }))}>Accept</Button>
                    <Button variant="ghost" onClick={() => guard(updateDoc(doc(db, "friends", f.id), { status: "rejected" }))}>Decline</Button>
                  </PersonRow>
                );
              })}
            </Section>
          )}

          <Section title={`Friends · ${accepted.length}`}>
            {accepted.length === 0 ? (
              <div className="p-4"><Empty title="No friends yet">Add someone by their Allim username above.</Empty></div>
            ) : (
              accepted.map((f) => {
                const o = other(f, user.userId);
                return (
                  <PersonRow key={f.id} name={o.name} sub={`@${o.id}`} photo={o.photo}>
                    <Button
                      variant="secondary"
                      onClick={() =>
                        guard(openConversationWith(user, { userId: o.id, name: o.name, email: o.email }).then((id) => navigate({ name: "messages", conversationId: id })))
                      }
                    >
                      Message
                    </Button>
                    <Button
                      variant="danger"
                      onClick={() => confirm(`Remove ${o.name} from your friends?`) && guard(deleteDoc(doc(db, "friends", f.id)))}
                    >
                      Remove
                    </Button>
                  </PersonRow>
                );
              })
            )}
          </Section>

          {outgoing.length > 0 && (
            <Section title={`Sent · ${outgoing.length}`}>
              {outgoing.map((f) => {
                const o = other(f, user.userId);
                return (
                  <PersonRow key={f.id} name={o.name} sub={`@${o.id} · waiting`} photo={o.photo}>
                    <Button variant="ghost" onClick={() => guard(deleteDoc(doc(db, "friends", f.id)))}>Cancel</Button>
                  </PersonRow>
                );
              })}
            </Section>
          )}
        </div>
      )}
    </>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section>
      <h2 className="mb-2 px-1 text-[13px] font-bold text-ink-2">{title}</h2>
      <Card className="divide-y divide-line/70">{children}</Card>
    </section>
  );
}

function PersonRow({ name, sub, photo, children }: { name: string; sub: string; photo?: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-wrap items-center gap-3 px-4 py-3">
      <Avatar name={name} url={photo} size={42} />
      <div className="min-w-0 flex-1">
        <p className="truncate text-[16px] font-semibold text-ink">{name}</p>
        <p className="truncate text-[13px] text-ink-3">{sub}</p>
      </div>
      <div className="flex gap-1.5">{children}</div>
    </div>
  );
}

function AddFriend({ existing }: { existing: Friendship[] }) {
  const user = useUser();
  const [username, setUsername] = useState("");
  const [note, setNote] = useState<{ ok: boolean; text: string } | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    const id = username.trim().toLowerCase().replace(/^@/, "");
    if (!id) return;
    if (id === user.userId) return setNote({ ok: false, text: "That's you." });
    const dupe = existing.find((f) => f.participantIds.includes(id) && f.status !== "rejected");
    if (dupe) {
      return setNote({ ok: false, text: dupe.status === "accepted" ? `You're already friends with @${id}.` : `There's already a pending request with @${id}.` });
    }
    setBusy(true);
    setNote(null);
    try {
      const snap = await getDoc(doc(db, "users", id));
      if (!snap.exists()) {
        setNote({ ok: false, text: `No one is called @${id}.` });
        return;
      }
      const them = snap.data() as AppUser;
      // FriendsService.sendFriendRequest's document, field for field.
      await addDoc(collection(db, "friends"), {
        requesterId: user.userId,
        requesterName: user.name,
        requesterEmail: user.email,
        requesterProfilePictureURL: user.profilePictureURL ?? "",
        receiverId: id,
        receiverName: them.name,
        receiverEmail: them.email,
        receiverProfilePictureURL: them.profilePictureURL ?? "",
        status: "pending",
        createdAt: nowSeconds(),
        participantIds: [user.userId, id],
      });
      setNote({ ok: true, text: `Request sent to ${them.name}.` });
      setUsername("");
    } catch (err) {
      setNote({ ok: false, text: (err as Error).message });
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} className="mb-6">
      <div className="flex gap-2">
        <TextInput placeholder="Add a friend by username" value={username} onChange={(e) => setUsername(e.target.value)} className="flex-1" />
        <Button type="submit" disabled={busy || !username.trim()}>{busy ? "Sending…" : "Send request"}</Button>
      </div>
      {note && <p className={note.ok ? "mt-2 text-[14px] text-produce" : "mt-2 text-[14px] text-orange"}>{note.text}</p>}
    </form>
  );
}
