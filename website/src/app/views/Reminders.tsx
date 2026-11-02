import { useState, type FormEvent } from "react";
import { logoFor, useReminders, useStoreLogos, useUserStores } from "../data";
import { addItems, deleteItem, rename, setQuantity, toggleDone, toggleOutOfStock } from "../lists";
import { href } from "../router";
import { useUser } from "../auth";
import { reminderStoreId, type Reminder } from "../types";
import { categoryHue, cx } from "../format";
import { Button, Card, Empty, ErrorNote, PageHeader, Spinner, StoreLogo, TextInput } from "../ui";

export default function Reminders({ userStoreId }: { userStoreId: string }) {
  const user = useUser();
  const stores = useUserStores(user.userId);
  const store = stores.data.find((s) => s.id === userStoreId);
  const reminders = useReminders(store ? reminderStoreId(store) : null);
  const logos = useStoreLogos();
  const [error, setError] = useState("");

  if (stores.loading) return <Spinner />;
  if (!store) {
    return (
      <>
        <PageHeader title="Store not found" back={{ href: href({ name: "stores" }), label: "Stores" }} />
        <Empty title="Nothing here">This store isn't on your account any more.</Empty>
      </>
    );
  }

  const canEdit = store.permission !== "view";
  const open = reminders.data.filter((r) => !r.isDone);
  const done = reminders.data.filter((r) => r.isDone);

  // Aisles in the order their first item was added, uncategorized last — the
  // list reads in the same order you'd walk the store.
  const aisles = new Map<string, Reminder[]>();
  for (const r of open) {
    const key = r.category && r.category !== "Uncategorized" ? r.category : "";
    aisles.set(key, [...(aisles.get(key) ?? []), r]);
  }
  const aisleOrder = [...aisles.keys()].sort((a, b) => (a === "" ? 1 : b === "" ? -1 : 0));

  const guard = (p: Promise<unknown>) => p.catch((e: Error) => setError(e.message));

  return (
    <>
      <PageHeader
        back={{ href: href({ name: "stores" }), label: "Stores" }}
        title={
          <span className="flex items-center gap-3">
            <StoreLogo name={store.storeName} url={logoFor(logos, store.storeId) ?? store.imageURL} size={44} />
            {store.storeName}
          </span>
        }
        subtitle={
          store.permission !== "owner"
            ? `Shared by ${store.sharedFromName ?? store.sharedFrom ?? "a friend"} · ${canEdit ? "Can edit" : "View only"}`
            : store.sharedWith?.length
              ? `Shared with ${store.sharedWith.join(", ")}`
              : `${open.length} to get · ${done.length} in the cart`
        }
      />

      {canEdit && <AddItem onAdd={(title, quantity) => guard(addItems(store, user, [{ title, quantity }]))} />}
      {error && <div className="mb-4"><ErrorNote>{error}</ErrorNote></div>}

      {reminders.loading ? (
        <Spinner />
      ) : reminders.data.length === 0 ? (
        <Empty title="List is empty">{canEdit ? "Add the first thing you need from here." : "Nothing on this list yet."}</Empty>
      ) : (
        <div className="space-y-5">
          {aisleOrder.map((aisle) => (
            <section key={aisle || "other"}>
              <h2 className="mb-2 flex items-center gap-2 px-1 text-[13px] font-bold text-ink-2">
                <span className="h-2.5 w-2.5 rounded-full" style={{ background: categoryHue(aisle) }} />
                {aisle || "Other"}
                <span className="font-medium text-ink-3">{aisles.get(aisle)!.length}</span>
              </h2>
              <Card className="divide-y divide-line/70">
                {aisles.get(aisle)!.map((r) => (
                  <Row key={r.id} r={r} canEdit={canEdit} guard={guard} />
                ))}
              </Card>
            </section>
          ))}

          {done.length > 0 && (
            <section>
              <h2 className="mb-2 px-1 text-[13px] font-bold text-ink-3">In the cart · {done.length}</h2>
              <Card className="divide-y divide-line/70 bg-paper/70">
                {done.map((r) => (
                  <Row key={r.id} r={r} canEdit={canEdit} guard={guard} />
                ))}
              </Card>
            </section>
          )}
        </div>
      )}
    </>
  );
}

function AddItem({ onAdd }: { onAdd: (title: string, quantity?: number) => void }) {
  const [title, setTitle] = useState("");
  const [qty, setQty] = useState(1);
  function submit(e: FormEvent) {
    e.preventDefault();
    if (!title.trim()) return;
    onAdd(title.trim(), qty);
    setTitle("");
    setQty(1);
  }
  return (
    <form onSubmit={submit} className="mb-6 flex gap-2">
      <TextInput placeholder="Add an item…" value={title} onChange={(e) => setTitle(e.target.value)} className="flex-1" />
      <div className="flex items-center rounded-xl border border-line bg-field/70">
        <button type="button" className="h-full px-3 text-ink-2 hover:text-teal" onClick={() => setQty((q) => Math.max(1, q - 1))} aria-label="Less">−</button>
        <span className="mono w-6 text-center text-[14px]">{qty}</span>
        <button type="button" className="h-full px-3 text-ink-2 hover:text-teal" onClick={() => setQty((q) => q + 1)} aria-label="More">+</button>
      </div>
      <Button type="submit" disabled={!title.trim()}>Add</Button>
    </form>
  );
}

function Row({ r, canEdit, guard }: { r: Reminder; canEdit: boolean; guard: (p: Promise<unknown>) => void }) {
  const user = useUser();
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(r.title);
  const qty = r.quantity ?? 1;

  function commitRename() {
    setEditing(false);
    const t = draft.trim();
    if (t && t !== r.title) guard(rename(r, t, user));
    else setDraft(r.title);
  }

  const by = r.isDone ? r.checkedOffBy : (r.lastEditedBy ?? (r.isShared ? r.sharedFrom : undefined));

  return (
    <div className="group flex items-center gap-3 px-4 py-3">
      <button
        type="button"
        disabled={!canEdit}
        onClick={() => guard(toggleDone(r, user))}
        aria-label={r.isDone ? `Uncheck ${r.title}` : `Check off ${r.title}`}
        className={cx(
          "flex h-6 w-6 shrink-0 items-center justify-center rounded-full border-2 transition-colors",
          r.isDone ? "border-teal bg-teal text-white" : "border-line-strong hover:border-teal",
        )}
      >
        {r.isDone && <svg viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" strokeWidth="2.4"><path d="M3 8.5 6.5 12 13 4.5" /></svg>}
      </button>

      <div className="min-w-0 flex-1">
        {editing ? (
          <TextInput
            autoFocus
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onBlur={commitRename}
            onKeyDown={(e) => {
              if (e.key === "Enter") commitRename();
              if (e.key === "Escape") { setDraft(r.title); setEditing(false); }
            }}
            className="py-1.5"
          />
        ) : (
          <button
            type="button"
            disabled={!canEdit}
            onDoubleClick={() => setEditing(true)}
            className={cx("block max-w-full truncate text-left text-[16px]", r.isDone ? "text-ink-3 line-through" : "text-ink", r.isOutOfStock && "text-ink-3")}
            title={canEdit ? "Double-click to rename" : undefined}
          >
            {r.title}
            {qty > 1 && <span className="mono ml-2 text-[13px] text-ink-2">×{qty}</span>}
          </button>
        )}
        <div className="flex gap-2 text-[12px] text-ink-3">
          {r.isOutOfStock && <span className="font-semibold text-orange">Out of stock</span>}
          {by && <span>{r.isDone ? `Got by ${by}` : `by ${by}`}</span>}
        </div>
      </div>

      {r.photoURLs?.[0] && <img src={r.photoURLs[0]} alt="" className="h-10 w-10 rounded-lg object-cover" />}

      {canEdit && (
        <div className="flex items-center gap-0.5 opacity-100 transition-opacity sm:opacity-0 sm:group-hover:opacity-100 sm:focus-within:opacity-100">
          {!r.isDone && (
            <>
              <IconBtn label="Less" onClick={() => guard(setQuantity(r, qty - 1, user))} disabled={qty <= 1}>−</IconBtn>
              <IconBtn label="More" onClick={() => guard(setQuantity(r, qty + 1, user))}>+</IconBtn>
              <IconBtn label={r.isOutOfStock ? "Back in stock" : "Mark out of stock"} onClick={() => guard(toggleOutOfStock(r, user))}>
                <span className="text-[13px]">{r.isOutOfStock ? "↺" : "⌀"}</span>
              </IconBtn>
            </>
          )}
          <IconBtn label="Rename" onClick={() => setEditing(true)}><span className="text-[13px]">✎</span></IconBtn>
          <IconBtn label="Delete" onClick={() => guard(deleteItem(r, user))} danger>×</IconBtn>
        </div>
      )}
    </div>
  );
}

function IconBtn({ label, onClick, children, disabled, danger }: { label: string; onClick: () => void; children: React.ReactNode; disabled?: boolean; danger?: boolean }) {
  return (
    <button
      type="button"
      title={label}
      aria-label={label}
      disabled={disabled}
      onClick={onClick}
      className={cx("flex h-8 w-8 items-center justify-center rounded-full text-[17px] text-ink-3 hover:bg-field disabled:opacity-30", danger ? "hover:text-meat" : "hover:text-teal")}
    >
      {children}
    </button>
  );
}
