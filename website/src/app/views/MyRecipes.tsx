import { addDoc, collection, deleteDoc, doc, updateDoc } from "firebase/firestore";
import { useState, type FormEvent } from "react";
import { useRecipes } from "../data";
import { db } from "../firebase";
import { href } from "../router";
import { useUser } from "../auth";
import { nowSeconds, type Recipe } from "../types";
import { timeAgo } from "../format";
import { Button, Card, Empty, ErrorNote, Modal, PageHeader, Spinner, TextInput } from "../ui";
import AddToStore from "./AddToStore";

export default function MyRecipes() {
  const user = useUser();
  const recipes = useRecipes(user.userId);
  const [editing, setEditing] = useState<Recipe | "new" | null>(null);
  const [adding, setAdding] = useState<Recipe | null>(null);
  const [toast, setToast] = useState("");

  function flash(msg: string) {
    setToast(msg);
    setTimeout(() => setToast(""), 3200);
  }

  return (
    <>
      <PageHeader
        title="My Recipes"
        subtitle="Recipes you've saved, ready to send to any store's list."
        actions={<Button onClick={() => setEditing("new")}>+ New recipe</Button>}
      />
      {recipes.error && <ErrorNote>{recipes.error}</ErrorNote>}

      {recipes.loading ? (
        <Spinner />
      ) : recipes.data.length === 0 ? (
        <Empty title="No recipes saved">
          Write one yourself, or ask <a className="font-semibold text-teal" href={href({ name: "ai-recipe" })}>AI Recipe</a> and save what it suggests.
        </Empty>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2">
          {recipes.data.map((r) => (
            <Card key={r.id} className="flex flex-col p-5">
              <div className="flex items-start justify-between gap-3">
                <h2 className="text-[18px] font-bold leading-snug text-ink">{r.name}</h2>
                <span className="shrink-0 text-[12px] text-ink-3">{timeAgo(r.createdAt)}</span>
              </div>
              <p className="mt-1 text-[13px] text-ink-3">{r.ingredients.length} ingredients</p>
              <ul className="mt-3 flex-1 space-y-1">
                {r.ingredients.slice(0, 6).map((i) => (
                  <li key={i} className="hand text-[22px] leading-6 text-pen">{i}</li>
                ))}
                {r.ingredients.length > 6 && <li className="text-[13px] text-ink-3">+ {r.ingredients.length - 6} more</li>}
              </ul>
              <div className="mt-4 flex flex-wrap gap-2">
                <Button onClick={() => setAdding(r)} disabled={r.ingredients.length === 0}>Add to a store</Button>
                <Button variant="ghost" onClick={() => setEditing(r)}>Edit</Button>
                <Button variant="danger" onClick={() => confirm(`Delete “${r.name}”?`) && deleteDoc(doc(db, "recipes", r.id))}>Delete</Button>
              </div>
            </Card>
          ))}
        </div>
      )}

      {editing && <Editor recipe={editing === "new" ? undefined : editing} onClose={() => setEditing(null)} />}
      {adding && (
        <AddToStore
          ingredients={adding.ingredients}
          onClose={() => setAdding(null)}
          onDone={(store, n) => flash(n ? `Added ${n} to ${store}` : `Everything was already on ${store}'s list`)}
        />
      )}
      {toast && (
        <div className="fixed bottom-24 left-1/2 z-50 -translate-x-1/2 rounded-full bg-ink px-4 py-2 text-[14px] font-medium text-white shadow-lg lg:bottom-8" role="status">
          {toast}
        </div>
      )}
    </>
  );
}

function Editor({ recipe, onClose }: { recipe?: Recipe; onClose: () => void }) {
  const user = useUser();
  const [name, setName] = useState(recipe?.name ?? "");
  const [ingredients, setIngredients] = useState((recipe?.ingredients ?? []).join("\n"));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function submit(e: FormEvent) {
    e.preventDefault();
    const list = ingredients.split("\n").map((s) => s.trim()).filter(Boolean);
    if (!name.trim()) return;
    setBusy(true);
    try {
      if (recipe) {
        await updateDoc(doc(db, "recipes", recipe.id), { name: name.trim(), ingredients: list });
      } else {
        await addDoc(collection(db, "recipes"), {
          userId: user.userId,
          userEmail: user.email,
          name: name.trim(),
          ingredients: list,
          createdAt: nowSeconds(),
        });
      }
      onClose();
    } catch (err) {
      setError((err as Error).message);
      setBusy(false);
    }
  }

  return (
    <Modal title={recipe ? "Edit recipe" : "New recipe"} onClose={onClose}>
      <form onSubmit={submit} className="space-y-3">
        <TextInput autoFocus placeholder="Recipe name" value={name} onChange={(e) => setName(e.target.value)} />
        <textarea
          rows={8}
          placeholder={"One ingredient per line\nGarlic\nOlive oil\nSpaghetti"}
          value={ingredients}
          onChange={(e) => setIngredients(e.target.value)}
          className="w-full rounded-xl border border-line bg-field/70 px-3.5 py-2.5 text-[15px] text-ink outline-none placeholder:text-ink-3 focus:border-teal focus:bg-card"
        />
        {error && <ErrorNote>{error}</ErrorNote>}
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onClose}>Cancel</Button>
          <Button type="submit" disabled={busy || !name.trim()}>{recipe ? "Save" : "Create"}</Button>
        </div>
      </form>
    </Modal>
  );
}
