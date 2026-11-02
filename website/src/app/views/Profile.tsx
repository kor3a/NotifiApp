import { doc, updateDoc } from "firebase/firestore";
import { useState } from "react";
import { useFriendships, useRecipes, useUserStores } from "../data";
import { db } from "../firebase";
import { href, type Route } from "../router";
import { logOut, useUser } from "../auth";
import { Avatar, Button, Card, PageHeader, TextInput } from "../ui";

export default function Profile() {
  const user = useUser();
  const stores = useUserStores(user.userId);
  const friends = useFriendships(user.userId);
  const recipes = useRecipes(user.userId);
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(user.name);

  const premium = user.isSubscribed || user.adminSubscribed;
  const joined = new Date(user.joined * 1000).toLocaleDateString(undefined, { month: "long", day: "numeric", year: "numeric" });
  const sharedCount = stores.data.filter((s) => s.permission !== "owner" || s.sharedWith?.length).length;

  async function saveName() {
    const n = name.trim();
    if (n && n !== user.name) await updateDoc(doc(db, "users", user.userId), { name: n });
    setEditing(false);
  }

  const stats: { label: string; value: number; to: Route }[] = [
    { label: "Stores", value: stores.data.length, to: { name: "stores" } },
    { label: "Shared", value: sharedCount, to: { name: "stores" } },
    { label: "Friends", value: friends.data.filter((f) => f.status === "accepted").length, to: { name: "friends" } },
    { label: "Recipes", value: recipes.data.length, to: { name: "recipes" } },
  ];

  return (
    <>
      <PageHeader title="Profile" />

      <Card className="flex flex-col items-center gap-4 p-6 text-center sm:flex-row sm:text-left">
        <Avatar name={user.name} url={user.profilePictureURL} size={88} />
        <div className="min-w-0 flex-1">
          {editing ? (
            <div className="flex gap-2">
              <TextInput autoFocus value={name} onChange={(e) => setName(e.target.value)} onKeyDown={(e) => e.key === "Enter" && saveName()} />
              <Button onClick={saveName}>Save</Button>
            </div>
          ) : (
            <h2 className="display text-[28px] text-ink">{user.name}</h2>
          )}
          <p className="text-[15px] text-ink-2">@{user.userId}</p>
          <p className="text-[14px] text-ink-3">{user.email}</p>
        </div>
        {!editing && <Button variant="secondary" onClick={() => setEditing(true)}>Edit name</Button>}
      </Card>

      <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
        {stats.map((s) => (
          <a key={s.label} href={href(s.to)}>
            <Card className="p-4 transition-colors hover:border-teal/60">
              <p className="display text-[28px] text-ink">{s.value}</p>
              <p className="text-[13px] font-medium text-ink-3">{s.label}</p>
            </Card>
          </a>
        ))}
      </div>

      <Card className="mt-4 divide-y divide-line/70">
        <Row label="Plan">
          {premium ? (
            <span className="rounded-full bg-tag px-2.5 py-0.5 text-[13px] font-bold text-ink">Premium</span>
          ) : (
            <span className="text-ink-2">Free · upgrade in the iOS app</span>
          )}
        </Row>
        <Row label="Member since">{joined}</Row>
        <Row label="Username">@{user.userId}</Row>
      </Card>

      <p className="mt-4 text-[13px] text-ink-3">
        Photo, notifications, app icon, backgrounds and account deletion are managed in the phone app.
      </p>

      <Button variant="danger" className="mt-6 border border-meat/30" onClick={logOut}>
        Sign out
      </Button>
    </>
  );
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-4 px-5 py-3.5 text-[15px]">
      <span className="text-ink-3">{label}</span>
      <span className="text-right text-ink">{children}</span>
    </div>
  );
}
