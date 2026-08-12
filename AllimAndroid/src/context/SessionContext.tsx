import React, {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
} from 'react';
import auth from '@react-native-firebase/auth';
import messaging from '@react-native-firebase/messaging';
import {User} from '../models';
import {userService} from '../services/userService';

/**
 * Where the signed-in account stands relative to its Firestore profile.
 *
 * `needsSetup` is only ever reported when a lookup came back *empty* — never
 * when it failed. A first-time Google sign-in has a Firebase account but no
 * profile yet and must go to ProfileSetupScreen; an offline password user must
 * not be sent there, or they would be asked to pick a username they already
 * have and the write would collide.
 */
export type ProfileStatus = 'unknown' | 'ready' | 'needsSetup';

interface SessionContextType {
  firebaseUser: any | null;
  currentUser: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  profileStatus: ProfileStatus;
  refreshUser: () => Promise<void>;
}

const SessionContext = createContext<SessionContextType>({
  firebaseUser: null,
  currentUser: null,
  isLoading: true,
  isAuthenticated: false,
  profileStatus: 'unknown',
  refreshUser: async () => {},
});

export function SessionProvider({children}: {children: React.ReactNode}) {
  const [firebaseUser, setFirebaseUser] = useState<any | null>(null);
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [profileStatus, setProfileStatus] = useState<ProfileStatus>('unknown');
  const [isLoading, setIsLoading] = useState(true);
  // True once a signed-in user has been observed, so the FCM token is only
  // invalidated on real sign-outs — not on cold starts that begin signed out.
  const hasSeenSignedInUser = useRef(false);

  // Register this device for the account's pushes. Non-fatal: the app works
  // without it and the token is refreshed on the next sign-in.
  async function saveDeviceToken(user: User) {
    try {
      const token = await messaging().getToken();
      await userService.saveFCMToken(user.userId, token);
    } catch (_) {}
  }

  async function refreshUser() {
    const fbUser = auth().currentUser;
    if (!fbUser || !fbUser.email) {
      setCurrentUser(null);
      setProfileStatus('unknown');
      return;
    }
    const user = await userService.fetchUserByEmail(fbUser.email);
    setCurrentUser(user);
    setProfileStatus(user ? 'ready' : 'needsSetup');
    if (user) {
      await saveDeviceToken(user);
    }
  }

  useEffect(() => {
    const unsubscribe = auth().onAuthStateChanged(async fbUser => {
      setFirebaseUser(fbUser);
      if (fbUser) {
        hasSeenSignedInUser.current = true;

        // The profile read is racing sign-out: logging in with an unverified
        // email signs straight back out, and a Firestore read that lands after
        // that is rejected with firestore/permission-denied. Swallow it (and
        // any offline error) so it can't become an unhandled rejection that
        // leaves isLoading stuck true and the app parked on the splash screen.
        // A failed read stays 'unknown' — only a read that succeeded and found
        // nothing means the account genuinely has no profile.
        let user: User | null = null;
        let status: ProfileStatus = 'unknown';
        try {
          if (fbUser.email) {
            user = await userService.fetchUserByEmail(fbUser.email);
            status = user ? 'ready' : 'needsSetup';
          }
        } catch (_) {}
        // Don't apply a stale result over a newer auth state.
        if (auth().currentUser?.uid !== fbUser.uid) {
          setIsLoading(false);
          return;
        }
        setCurrentUser(user);
        setProfileStatus(status);

        // Save FCM token against the users doc (keyed by username, not uid).
        if (user) {
          await saveDeviceToken(user);
        }
      } else {
        // Signed out: invalidate this device's token so pushes addressed to
        // any account that still stores it bounce instead of being shown to
        // the next user who signs in on this device. A replacement token is
        // fetched and saved on the next sign-in above.
        if (hasSeenSignedInUser.current) {
          try {
            await messaging().deleteToken();
          } catch (_) {}
        }
        setCurrentUser(null);
        setProfileStatus('unknown');
      }
      setIsLoading(false);
    });
    return unsubscribe;
  }, []);

  return (
    <SessionContext.Provider
      value={{
        firebaseUser,
        currentUser,
        isLoading,
        isAuthenticated: !!firebaseUser,
        profileStatus,
        refreshUser,
      }}>
      {children}
    </SessionContext.Provider>
  );
}

export function useSession() {
  return useContext(SessionContext);
}
