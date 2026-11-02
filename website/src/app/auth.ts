import { signInWithEmailAndPassword, signOut, type User } from "firebase/auth";
import { createContext, useContext } from "react";
import { auth } from "./firebase";
import type { AppUser } from "./types";

export type SessionState =
  | { status: "loading" }
  | { status: "signedOut" }
  /** Signed in to Firebase, but no users/{username} doc matches the email (signup never finished). */
  | { status: "noProfile"; firebaseUser: User }
  | { status: "signedIn"; firebaseUser: User; user: AppUser };

export const SessionContext = createContext<SessionState>({ status: "loading" });

export function useSession() {
  return useContext(SessionContext);
}

/** The signed-in user. Only call below the signed-in gate in Root. */
export function useUser(): AppUser {
  const s = useContext(SessionContext);
  if (s.status !== "signedIn") throw new Error("useUser() called while signed out");
  return s.user;
}

export async function logIn(email: string, password: string) {
  const { user } = await signInWithEmailAndPassword(auth, email.trim(), password);
  // The apps refuse unverified accounts, so the web client does too.
  if (!user.emailVerified) {
    await signOut(auth);
    throw new Error(
      "Please verify your email before logging in. Check your inbox for the verification link.",
    );
  }
}

export function logOut() {
  return signOut(auth);
}

/** Firebase Auth error codes, worded like LoginViewModel.parseAuthError on iOS. */
export function authErrorMessage(err: unknown): string {
  const code = (err as { code?: string })?.code ?? "";
  switch (code) {
    case "auth/invalid-credential":
    case "auth/wrong-password":
    case "auth/user-not-found":
      return "The email or password you entered is incorrect.";
    case "auth/invalid-email":
      return "That email address doesn't look right.";
    case "auth/user-disabled":
      return "This account has been disabled. Please contact support.";
    case "auth/too-many-requests":
      return "Too many unsuccessful attempts. Wait a few minutes and try again.";
    case "auth/network-request-failed":
      return "Network error. Check your connection and try again.";
    default:
      return err instanceof Error ? err.message : "Something went wrong. Please try again.";
  }
}
