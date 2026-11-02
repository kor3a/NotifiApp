import {
  collection,
  getDocs,
  onSnapshot,
  query,
  where,
  type DocumentData,
  type Query,
} from "firebase/firestore";
import { useEffect, useState } from "react";
import { db } from "./firebase";
import type { Conversation, Friendship, Recipe, Reminder, UserStore } from "./types";

export interface Live<T> {
  data: T[];
  loading: boolean;
  error?: string;
}

/**
 * Subscribes to a query for as long as the component is mounted. `key` must
 * change whenever the query does — Firestore Query objects aren't comparable,
 * so the caller names what the query depends on instead.
 */
export function useLiveQuery<T>(
  key: string | null,
  build: () => Query<DocumentData>,
): Live<T> {
  const [state, setState] = useState<Live<T> & { key: string | null }>({
    key: null,
    data: [],
    loading: true,
  });

  useEffect(() => {
    if (key === null) return;
    return onSnapshot(
      build(),
      (snap) =>
        setState({
          key,
          loading: false,
          data: snap.docs.map((d) => ({ ...d.data(), id: d.id }) as T),
        }),
      (err) => setState({ key, loading: false, data: [], error: err.message }),
    );
    // `build` closes over the same inputs `key` names.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);

  // A stale result from the previous key is never shown under the new one.
  if (key === null) return { data: [], loading: false };
  if (state.key !== key) return { data: [], loading: true };
  return state;
}

export function useUserStores(userId: string) {
  const live = useLiveQuery<UserStore>(`stores:${userId}`, () =>
    query(collection(db, "user_stores"), where("userId", "==", userId)),
  );
  const data = [...live.data]
    .map((s) => ({ ...s, permission: s.permission ?? "owner" }))
    .sort((a, b) => (a.sortOrder ?? 1e9) - (b.sortOrder ?? 1e9) || a.addedAt - b.addedAt);
  return { ...live, data };
}

export function useReminders(reminderStoreId: string | null) {
  const live = useLiveQuery<Reminder>(reminderStoreId && `reminders:${reminderStoreId}`, () =>
    query(collection(db, "reminders"), where("userStoreId", "==", reminderStoreId)),
  );
  const data = [...live.data].sort(
    (a, b) => (a.sortOrder ?? 1e9) - (b.sortOrder ?? 1e9) || a.createdAt - b.createdAt,
  );
  return { ...live, data };
}

export function useRecipes(userId: string) {
  const live = useLiveQuery<Recipe>(`recipes:${userId}`, () =>
    query(collection(db, "recipes"), where("userId", "==", userId)),
  );
  return { ...live, data: [...live.data].sort((a, b) => b.createdAt - a.createdAt) };
}

export function useFriendships(userId: string) {
  return useLiveQuery<Friendship>(`friends:${userId}`, () =>
    query(collection(db, "friends"), where("participantIds", "array-contains", userId)),
  );
}

export function useConversations(userId: string) {
  const live = useLiveQuery<Conversation>(`conversations:${userId}`, () =>
    query(collection(db, "conversations"), where("participantIds", "array-contains", userId)),
  );
  return {
    ...live,
    data: [...live.data].sort((a, b) => (b.lastMessageAt ?? 0) - (a.lastMessageAt ?? 0)),
  };
}

/** Counts of unchecked items per reminderStoreId, for the Stores list badges. */
export function useOpenCounts(storeIds: string[]): Record<string, number> {
  const [counts, setCounts] = useState<Record<string, number>>({});
  const key = storeIds.join("|");
  useEffect(() => {
    const ids = key ? key.split("|") : [];
    const unsubs = ids.map((id) =>
      onSnapshot(
        query(
          collection(db, "reminders"),
          where("userStoreId", "==", id),
          where("isDone", "==", false),
        ),
        (snap) => setCounts((c) => ({ ...c, [id]: snap.size })),
        () => {},
      ),
    );
    return () => unsubs.forEach((u) => u());
  }, [key]);
  return counts;
}

/**
 * stores_logos is keyed by normalized store ID. An exact key wins, then the
 * longest key the store's ID starts with ("walmart-supercenter" → "walmart"),
 * like StoreLogoProvider.bestLogoKey on iOS.
 */
let logoCache: Promise<Record<string, string>> | null = null;
export function useStoreLogos(): Record<string, string> {
  const [logos, setLogos] = useState<Record<string, string>>({});
  useEffect(() => {
    logoCache ??= getDocs(collection(db, "stores_logos"))
      .then((snap) => {
        const out: Record<string, string> = {};
        snap.forEach((d) => {
          const url = d.data().logoURL;
          if (typeof url === "string") out[d.id] = url;
        });
        return out;
      })
      .catch(() => ({}));
    let alive = true;
    logoCache.then((l) => alive && setLogos(l));
    return () => {
      alive = false;
    };
  }, []);
  return logos;
}

export function logoFor(logos: Record<string, string>, storeId: string): string | undefined {
  if (logos[storeId]) return logos[storeId];
  const prefix = Object.keys(logos)
    .filter((k) => storeId.startsWith(`${k}-`))
    .sort((a, b) => b.length - a.length)[0];
  return prefix ? logos[prefix] : undefined;
}
