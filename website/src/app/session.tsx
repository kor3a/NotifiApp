import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, onSnapshot, query, where } from "firebase/firestore";
import { useEffect, useState, type ReactNode } from "react";
import { SessionContext, type SessionState } from "./auth";
import { auth, db } from "./firebase";
import type { AppUser } from "./types";

export function SessionProvider({ children }: { children: ReactNode }) {
  const [firebaseUser, setFirebaseUser] = useState<User | null | undefined>(undefined);
  const [profile, setProfile] = useState<AppUser | null | undefined>(undefined);

  useEffect(() => onAuthStateChanged(auth, setFirebaseUser), []);

  // users/ is keyed by username, so the signed-in account is found by email —
  // the same lookup UserSessionManager.fetchUser() does on iOS.
  useEffect(() => {
    if (!firebaseUser?.email) return;
    const q = query(collection(db, "users"), where("email", "==", firebaseUser.email));
    return onSnapshot(
      q,
      (snap) => {
        const doc = snap.docs[0];
        setProfile(doc ? ({ ...(doc.data() as AppUser), userId: doc.id }) : null);
      },
      () => setProfile(null),
    );
  }, [firebaseUser]);

  let state: SessionState;
  if (firebaseUser === undefined) state = { status: "loading" };
  else if (firebaseUser === null) state = { status: "signedOut" };
  else if (profile === undefined) state = { status: "loading" };
  else if (profile === null) state = { status: "noProfile", firebaseUser };
  else state = { status: "signedIn", firebaseUser, user: profile };

  return <SessionContext.Provider value={state}>{children}</SessionContext.Provider>;
}
