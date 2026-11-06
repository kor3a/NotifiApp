import { addDoc, collection } from "firebase/firestore";
import { useState, type FormEvent } from "react";
import { logoFor, useOpenCounts, useStoreLogos, useUserStores } from "../data";
import { db } from "../firebase";
import { href } from "../router";
import { useUser } from "../auth";
import { FREE_STORE_LIMIT, hasPremiumAccess, normalizedStoreId, nowSeconds, reminderStoreId } from "../types";
import { Button, Card, Empty, ErrorNote, Modal, PageHeader, Spinner, StoreLogo, TextInput } from "../ui";

export default function Stores() {
  const user = useUser();
  const stores = useUserStores(user.userId);
  const logos = useStoreLogos();
  const counts = useOpenCounts(stores.data.map(reminderStoreId));
  const [adding, setAdding] = useState(false);

  const totalOpen = Object.values(counts).reduce((a, b) => a + b, 0);

  return (
    <>
      <PageHeader
        title="Stores"
        subtitle={
          stores.loading
            ? " "
            : `${stores.data.length} ${stores.data.length === 1 ? "store" : "stores"} · ${totalOpen} items to pick up`
        }
        actions={<Button disabled={stores.loading} onClick={() => setAdding(true)}>+ Add store</Button>}
      />

      {stores.error && <ErrorNote>{stores.error}</ErrorNote>}
      {stores.loading ? (
        <Spinner />
      ) : stores.data.length === 0 ? (
        <Empty title="No stores yet">
          Add the places you shop, then keep a list for each one. The phone app reminds you when
          you're near.
        </Empty>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2">
          {stores.data.map((s) => {
            const open = counts[reminderStoreId(s)];
            const shared = s.permission !== "owner" || (s.sharedWith?.length ?? 0) > 0;
            return (
              <a key={s.id} href={href({ name: "reminders", userStoreId: s.id })} className="group">
                <Card className="flex items-center gap-4 p-4 transition-colors group-hover:border-teal/60">
                  <StoreLogo name={s.storeName} url={logoFor(logos, s.storeId) ?? s.imageURL} size={52} />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-[17px] font-bold text-ink">{s.storeName}</p>
                    <p className="truncate text-[13px] text-ink-3">
                      {s.permission !== "owner"
                        ? `Shared by ${s.sharedFromName ?? s.sharedFrom ?? "a friend"} · ${s.permission === "view" ? "View only" : "Can edit"}`
                        : shared
                          ? `Shared with ${s.sharedWith!.join(", ")}`
                          : s.storeAddress || "Your list"}
                    </p>
                  </div>
                  <span
                    className={
                      open
                        ? "rounded-full bg-orange-wash px-2.5 py-1 text-[13px] font-bold text-orange"
                        : "rounded-full bg-field px-2.5 py-1 text-[13px] font-semibold text-ink-3"
                    }
                  >
                    {open ?? "–"}
                  </span>
                </Card>
              </a>
            );
          })}
        </div>
      )}

      {adding && <AddStore onClose={() => setAdding(false)} existing={stores.data.map((s) => s.storeId)} />}
    </>
  );
}

function AddStore({ onClose, existing }: { onClose: () => void; existing: string[] }) {
  const user = useUser();
  const [name, setName] = useState("");
  const [address, setAddress] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  // Stores already over the limit are kept, but adding another needs Premium.
  if (!hasPremiumAccess(user) && existing.length >= FREE_STORE_LIMIT) {
    return (
      <Modal title="Add a store" onClose={onClose}>
        <p className="text-[15px] text-ink-2">
          Free accounts are limited to {FREE_STORE_LIMIT} stores. Upgrade to Allim Premium in the
          phone app to add more.
        </p>
        <div className="flex justify-end pt-4">
          <Button variant="ghost" onClick={onClose}>Close</Button>
        </div>
      </Modal>
    );
  }

  async function submit(e: FormEvent) {
    e.preventDefault();
    const storeName = name.trim();
    if (!storeName) return;
    const storeId = normalizedStoreId(storeName);
    if (existing.includes(storeId)) {
      setError(`${storeName} is already in your stores.`);
      return;
    }
    setBusy(true);
    try {
      // Same fields AddStoreView writes, minus the map pin: geofencing needs a
      // location, so set one from the phone app if you want arrival reminders.
      await addDoc(collection(db, "user_stores"), {
        userId: user.userId,
        userEmail: user.email,
        storeId,
        storeName,
        storeAddress: address.trim(),
        addedAt: nowSeconds(),
        sortOrder: existing.length,
        permission: "owner",
        notificationsEnabled: true,
        mergedFromOwnStore: false,
      });
      onClose();
    } catch (err) {
      setError((err as Error).message);
      setBusy(false);
    }
  }

  return (
    <Modal title="Add a store" onClose={onClose}>
      <form onSubmit={submit} className="space-y-3">
        <TextInput autoFocus placeholder="Store name, e.g. Trader Joe's" value={name} onChange={(e) => setName(e.target.value)} />
        <TextInput placeholder="Address (optional)" value={address} onChange={(e) => setAddress(e.target.value)} />
        <p className="text-[13px] text-ink-3">
          Location reminders need a map pin — add one from the phone app.
        </p>
        {error && <ErrorNote>{error}</ErrorNote>}
        <div className="flex justify-end gap-2 pt-1">
          <Button variant="ghost" onClick={onClose}>Cancel</Button>
          <Button type="submit" disabled={busy || !name.trim()}>Add store</Button>
        </div>
      </form>
    </Modal>
  );
}
