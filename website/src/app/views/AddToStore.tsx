import { useState } from "react";
import { logoFor, useStoreLogos, useUserStores } from "../data";
import { addItems } from "../lists";
import { useUser } from "../auth";
import { cx } from "../format";
import { Button, ErrorNote, Modal, Spinner, StoreLogo } from "../ui";

/** Picks a store and adds a recipe's ingredients to its list. Shared by AI Recipe and My Recipes. */
export default function AddToStore({
  ingredients,
  onClose,
  onDone,
}: {
  ingredients: string[];
  onClose: () => void;
  onDone: (storeName: string, added: number) => void;
}) {
  const user = useUser();
  const stores = useUserStores(user.userId);
  const logos = useStoreLogos();
  const editable = stores.data.filter((s) => s.permission !== "view");
  const [picked, setPicked] = useState<Set<string>>(() => new Set(ingredients));
  const [storeId, setStoreId] = useState<string>();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function add() {
    const store = editable.find((s) => s.id === storeId);
    if (!store) return;
    setBusy(true);
    try {
      const n = await addItems(store, user, [...picked].map((title) => ({ title })));
      onDone(store.storeName, n);
      onClose();
    } catch (err) {
      setError((err as Error).message);
      setBusy(false);
    }
  }

  return (
    <Modal title="Add to a store's list" onClose={onClose}>
      <p className="mb-2 text-[13px] font-semibold text-ink-2">Ingredients</p>
      <div className="mb-4 flex flex-wrap gap-1.5">
        {ingredients.map((i) => {
          const on = picked.has(i);
          return (
            <button
              key={i}
              type="button"
              onClick={() => setPicked((p) => { const n = new Set(p); if (on) n.delete(i); else n.add(i); return n; })}
              className={cx("rounded-full border px-3 py-1 text-[13px] transition-colors", on ? "border-teal bg-wash text-on-wash" : "border-line text-ink-3 line-through")}
            >
              {i}
            </button>
          );
        })}
      </div>

      <p className="mb-2 text-[13px] font-semibold text-ink-2">Store</p>
      {stores.loading ? (
        <Spinner />
      ) : editable.length === 0 ? (
        <p className="text-[14px] text-ink-3">Add a store first.</p>
      ) : (
        <div className="max-h-56 space-y-1 overflow-y-auto">
          {editable.map((s) => (
            <button
              key={s.id}
              type="button"
              onClick={() => setStoreId(s.id)}
              className={cx("flex w-full items-center gap-3 rounded-xl border px-3 py-2 text-left", storeId === s.id ? "border-teal bg-wash" : "border-transparent hover:bg-field")}
            >
              <StoreLogo name={s.storeName} url={logoFor(logos, s.storeId) ?? s.imageURL} size={32} />
              <span className="text-[15px] font-semibold text-ink">{s.storeName}</span>
            </button>
          ))}
        </div>
      )}

      {error && <div className="mt-3"><ErrorNote>{error}</ErrorNote></div>}
      <div className="mt-5 flex justify-end gap-2">
        <Button variant="ghost" onClick={onClose}>Cancel</Button>
        <Button onClick={add} disabled={busy || !storeId || picked.size === 0}>
          {busy ? "Adding…" : `Add ${picked.size} ${picked.size === 1 ? "item" : "items"}`}
        </Button>
      </div>
    </Modal>
  );
}
