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
import {withLatestAccess} from '../services/subscription';
import {isSignupInProgress} from '../services/authService';
import {clearSignedOutUserData} from '../services/sessionCleanup';
import {notificationInbox} from '../services/notificationInbox';

// The wipe of the previous account's local data, while it runs. A sign-in that
// lands mid-wipe waits for it, so the new account never reads through a
// Firestore cache that still holds the old one's documents (or through an
// instance that is being shut down).
let pendingCleanup: Promise<void> = Promise.resolve();

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
  // without it and the token is saved again on the next launch or sign-in.
  async function saveDeviceToken(user: User) {
    try {
      const token = await messaging().getToken();
      await userService.saveFCMToken(user.userId, token);
    } catch (error) {
      console.warn('Could not save the push token', error);
    }
  }

  async function refreshUser() {
    const fbUser = auth().currentUser;
    if (!fbUser || !fbUser.email) {
      setCurrentUser(null);
      setProfileStatus('unknown');
      return;
    }
    await pendingCleanup;
    const user = await userService.fetchUserByEmail(fbUser.email);
    // Signed out (or into someone else) while the lookup ran.
    if (auth().currentUser?.uid !== fbUser.uid) {
      return;
    }
    setCurrentUser(user);
    setProfileStatus(user ? 'ready' : 'needsSetup');
    if (user) {
      await saveDeviceToken(user);
    }
  }

  useEffect(() => {
    const unsubscribe = auth().onAuthStateChanged(async fbUser => {
      // Sign Up's own account is signed in only long enough to write its
      // profile, then signed straight back out to await verification. Routing
      // on it would flash the app and tear down the auth screens mid-signup.
      if (fbUser && isSignupInProgress()) {
        return;
      }
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
          await pendingCleanup;
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
        // Drop the account from memory before anything else, so no screen can
        // render it again while the cleanup below runs.
        setCurrentUser(null);
        setProfileStatus('unknown');

        if (hasSeenSignedInUser.current) {
          // Invalidate this device's token so pushes addressed to any account
          // that still stores it bounce instead of being shown to the next
          // user who signs in on this device. A replacement token is fetched
          // and saved on the next sign-in above.
          try {
            await messaging().deleteToken();
          } catch (_) {}
          // Then wipe what the account left on the device: Firestore's offline
          // cache, stored preferences and its notifications.
          pendingCleanup = clearSignedOutUserData();
          await pendingCleanup;
        }
      }
      setIsLoading(false);
    });
    return unsubscribe;
  }, []);

  // FCM can replace the token while the app is running. Without this, pushes go
  // to the old token until the next launch.
  const signedInUserId = currentUser?.userId;
  useEffect(() => {
    if (!signedInUserId) {
      return;
    }
    return messaging().onTokenRefresh(token => {
      userService.saveFCMToken(signedInUserId, token).catch(error => {
        console.warn('Could not save the refreshed push token', error);
      });
    });
  }, [signedInUserId]);

  // Keep access current while the app is open. The profile is otherwise read
  // once at sign-in, so a subscription granted or removed would go unnoticed
  // until the next launch.
  const signedInEmail = currentUser?.email;
  useEffect(() => {
    if (!signedInEmail) {
      return;
    }
    return userService.subscribeToUser(
      signedInEmail,
      latest => setCurrentUser(current => withLatestAccess(current, latest)),
      error => console.warn('Could not watch subscription status', error),
    );
  }, [signedInEmail]);

  // Consume the notification documents other people write for this account,
  // so they don't pile up in Firestore. Keyed on the Auth email, which is what
  // the rules match recipients on, and only once the profile has loaded, so an
  // account that is signed straight back out (unverified email) never starts
  // it. Sign-out also stops it in clearSignedOutUserData, before the Firestore
  // instance it runs on is shut down.
  const inboxEmail: string | undefined = currentUser
    ? firebaseUser?.email ?? undefined
    : undefined;
  useEffect(() => {
    if (!inboxEmail) {
      return;
    }
    notificationInbox.start(inboxEmail);
    return () => notificationInbox.stop();
  }, [inboxEmail]);

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
