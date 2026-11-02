import { addDoc, collection } from "firebase/firestore";
import { useEffect, useRef, useState, type FormEvent, type ReactNode } from "react";
import { extractIngredients, recipeChat, recipeNameFrom } from "../ai";
import { db } from "../firebase";
import { useUser } from "../auth";
import { nowSeconds } from "../types";
import { cx } from "../format";
import { Button, Card, ErrorNote, PageHeader, TextInput } from "../ui";
import AddToStore from "./AddToStore";

interface Turn {
  id: number;
  role: "user" | "assistant";
  content: string;
  /** Pulled out of the reply in a second call; undefined while that runs. */
  ingredients?: string[];
}

const SUGGESTIONS = [
  "A quick weeknight pasta for four",
  "Toddler-friendly dinner with hidden veggies",
  "Korean doenjang jjigae",
  "What can I make with chicken thighs, rice and spinach?",
];

let nextId = 1;

export default function AIRecipe() {
  const user = useUser();
  const [turns, setTurns] = useState<Turn[]>([]);
  const [text, setText] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [toast, setToast] = useState("");
  const [adding, setAdding] = useState<string[] | null>(null);
  const bottom = useRef<HTMLDivElement>(null);

  // Braces matter: newer Chromium returns a Promise from scrollIntoView, and
  // React would take a returned value for a cleanup function.
  useEffect(() => {
    bottom.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [turns.length, busy]);

  async function ask(content: string) {
    const q = content.trim();
    if (!q || busy) return;
    const history = [...turns, { id: nextId++, role: "user" as const, content: q }];
    setTurns(history);
    setText("");
    setBusy(true);
    setError("");
    try {
      const reply = await recipeChat(history.map(({ role, content }) => ({ role, content })));
      const id = nextId++;
      setTurns((t) => [...t, { id, role: "assistant", content: reply }]);
      extractIngredients(reply)
        .catch(() => [] as string[])
        .then((ingredients) => setTurns((t) => t.map((x) => (x.id === id ? { ...x, ingredients } : x))));
    } catch (err) {
      setError((err as Error).message || "The recipe assistant didn't answer. Try again.");
    } finally {
      setBusy(false);
    }
  }

  async function save(turn: Turn) {
    const name = recipeNameFrom(turn.content);
    try {
      await addDoc(collection(db, "recipes"), {
        userId: user.userId,
        userEmail: user.email,
        name,
        ingredients: turn.ingredients ?? [],
        createdAt: nowSeconds(),
      });
      flash(`Saved “${name}” to My Recipes`);
    } catch (err) {
      setError((err as Error).message);
    }
  }

  function flash(msg: string) {
    setToast(msg);
    setTimeout(() => setToast(""), 3200);
  }

  return (
    <>
      <PageHeader
        title="AI Recipe"
        subtitle="Ask for a recipe, then send its ingredients straight to a store's list."
        actions={turns.length > 0 && <Button variant="secondary" onClick={() => { setTurns([]); setError(""); }}>New chat</Button>}
      />

      {turns.length === 0 && (
        <div className="mb-6 grid gap-2 sm:grid-cols-2">
          {SUGGESTIONS.map((s) => (
            <button key={s} type="button" onClick={() => ask(s)} className="rounded-2xl border border-line bg-card px-4 py-3 text-left text-[15px] text-ink-2 transition-colors hover:border-teal hover:text-teal">
              {s}
            </button>
          ))}
        </div>
      )}

      <div className="space-y-4">
        {turns.map((t) =>
          t.role === "user" ? (
            <div key={t.id} className="flex justify-end">
              <p className="max-w-[80%] rounded-2xl rounded-br-md bg-teal px-4 py-2.5 text-[15px] text-white">{t.content}</p>
            </div>
          ) : (
            <Card key={t.id} className="p-5">
              <Markdown text={t.content} />
              <div className="mt-4 border-t border-line/70 pt-4">
                {t.ingredients === undefined ? (
                  <p className="text-[13px] text-ink-3">Picking out the ingredients…</p>
                ) : t.ingredients.length === 0 ? null : (
                  <>
                    <div className="mb-3 flex flex-wrap gap-1.5">
                      {t.ingredients.map((i) => (
                        <span key={i} className="rounded-full bg-field px-2.5 py-1 text-[13px] text-ink-2">{i}</span>
                      ))}
                    </div>
                    <div className="flex flex-wrap gap-2">
                      <Button onClick={() => setAdding(t.ingredients!)}>Add to a store</Button>
                      <Button variant="secondary" onClick={() => save(t)}>Save to My Recipes</Button>
                    </div>
                  </>
                )}
              </div>
            </Card>
          ),
        )}
        {busy && (
          <Card className="p-5">
            <p className="flex items-center gap-2 text-[15px] text-ink-3">
              <span className="h-4 w-4 animate-spin rounded-full border-2 border-line-strong border-t-teal" /> Cooking something up…
            </p>
          </Card>
        )}
        {error && <ErrorNote>{error}</ErrorNote>}
        <div ref={bottom} />
      </div>

      <form
        onSubmit={(e: FormEvent) => { e.preventDefault(); ask(text); }}
        className="sticky bottom-24 mt-6 flex gap-2 rounded-2xl border border-line bg-paper/95 p-2 shadow-lg backdrop-blur lg:bottom-6"
      >
        <TextInput placeholder="What do you want to cook?" value={text} onChange={(e) => setText(e.target.value)} className="flex-1 border-transparent bg-card" />
        <Button type="submit" disabled={busy || !text.trim()}>Ask</Button>
      </form>

      {adding && (
        <AddToStore ingredients={adding} onClose={() => setAdding(null)} onDone={(store, n) => flash(n ? `Added ${n} to ${store}` : `Everything was already on ${store}'s list`)} />
      )}
      {toast && (
        <div className="fixed bottom-24 left-1/2 z-50 -translate-x-1/2 rounded-full bg-ink px-4 py-2 text-[14px] font-medium text-white shadow-lg lg:bottom-8" role="status">
          {toast}
        </div>
      )}
    </>
  );
}

/** Just enough markdown for the assistant's replies: headings, lists, bold. */
function Markdown({ text }: { text: string }) {
  const out: ReactNode[] = [];
  let list: { ordered: boolean; items: string[] } | null = null;
  const flush = () => {
    if (!list) return;
    const Tag = list.ordered ? "ol" : "ul";
    out.push(
      <Tag key={out.length} className={cx("my-2 space-y-1 pl-5 text-[15px] text-ink", list.ordered ? "list-decimal" : "list-disc")}>
        {list.items.map((i, n) => <li key={n}>{inline(i)}</li>)}
      </Tag>,
    );
    list = null;
  };
  for (const raw of text.split("\n")) {
    const line = raw.trim();
    const h = line.match(/^(#{1,4})\s+(.*)$/);
    const ul = line.match(/^[-*•]\s+(.*)$/);
    const ol = line.match(/^\d+[.)]\s+(.*)$/);
    if (h) {
      flush();
      out.push(
        h[1].length <= 2
          ? <h2 key={out.length} className="display mb-1 mt-1 text-[22px] text-ink">{inline(h[2])}</h2>
          : <h3 key={out.length} className="mb-1 mt-4 text-[16px] font-bold text-ink">{inline(h[2])}</h3>,
      );
    } else if (ul || ol) {
      const ordered = !!ol;
      if (list && list.ordered !== ordered) flush();
      list ??= { ordered, items: [] };
      list.items.push((ul ?? ol)![1]);
    } else if (line) {
      flush();
      out.push(<p key={out.length} className="my-2 text-[15px] leading-relaxed text-ink">{inline(line)}</p>);
    } else {
      flush();
    }
  }
  flush();
  return <div>{out}</div>;
}

function inline(s: string): ReactNode {
  return s.split(/(\*\*[^*]+\*\*)/g).map((part, i) =>
    part.startsWith("**") && part.endsWith("**") ? <strong key={i}>{part.slice(2, -2)}</strong> : part,
  );
}
