import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getFunctions } from "firebase/functions";

/**
 * The same Firebase project the iOS and Android apps use (georeminder-pilot),
 * so signing in here shows your real stores, lists, friends and messages.
 *
 * The defaults are the client values from
 * Geolocation_v1.0.0/Support/GoogleService-Info.plist, which are public by
 * design (security comes from firestore.rules, not from hiding the key). To
 * point at a different project or a registered Web app, set the VITE_FIREBASE_*
 * variables in website/.env.development.local.
 */
const env = import.meta.env;

const app = initializeApp({
  apiKey: env.VITE_FIREBASE_API_KEY ?? "AIzaSyASp2GRow0A5_bDJrJbzURuG_VS2YstkpA",
  authDomain: env.VITE_FIREBASE_AUTH_DOMAIN ?? "georeminder-pilot.firebaseapp.com",
  projectId: env.VITE_FIREBASE_PROJECT_ID ?? "georeminder-pilot",
  storageBucket: env.VITE_FIREBASE_STORAGE_BUCKET ?? "georeminder-pilot.firebasestorage.app",
  messagingSenderId: env.VITE_FIREBASE_MESSAGING_SENDER_ID ?? "903190692128",
  ...(env.VITE_FIREBASE_APP_ID ? { appId: env.VITE_FIREBASE_APP_ID } : {}),
});

export const auth = getAuth(app);
export const db = getFirestore(app);
export const functions = getFunctions(app);
