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

interface SessionContextType {
  firebaseUser: any | null;
  currentUser: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  refreshUser: () => Promise<void>;
}

const SessionContext = createContext<SessionContextType>({
  firebaseUser: null,
  currentUser: null,
  isLoading: true,
  isAuthenticated: false,
  refreshUser: async () => {},
});

export function SessionProvider({children}: {children: React.ReactNode}) {
  const [firebaseUser, setFirebaseUser] = useState<any | null>(null);
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  // True once a signed-in user has been observed, so the FCM token is only
  // invalidated on real sign-outs — not on cold starts that begin signed out.
  const hasSeenSignedInUser = useRef(false);

  async function refreshUser() {
    const fbUser = auth().currentUser;
    if (!fbUser || !fbUser.email) {
      setCurrentUser(null);
      return;
    }
    const user = await userService.fetchUserByEmail(fbUser.email);
    setCurrentUser(user);
  }

  useEffect(() => {
    const unsubscribe = auth().onAuthStateChanged(async fbUser => {
      setFirebaseUser(fbUser);
      if (fbUser) {
        const user = fbUser.email
          ? await userService.fetchUserByEmail(fbUser.email)
          : null;
        setCurrentUser(user);

        // Save FCM token against the users doc (keyed by username, not uid).
        if (user) {
          try {
            const token = await messaging().getToken();
            await userService.saveFCMToken(user.userId, token);
          } catch (_) {}
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
        refreshUser,
      }}>
      {children}
    </SessionContext.Provider>
  );
}

export function useSession() {
  return useContext(SessionContext);
}
