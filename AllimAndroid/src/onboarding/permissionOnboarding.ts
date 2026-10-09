import {useEffect, useState} from 'react';
import {PermissionsAndroid, Platform} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

/**
 * Drives the two permission primer screens a brand-new account sees after it
 * has a username and name, and before the tutorial and the Stores tab: first
 * location, then notifications. Port of the iOS PermissionOnboardingManager.
 *
 * Android only lets an app show each system prompt a couple of times before it
 * stops asking for good. Firing them straight at a user who just signed up
 * spends those asks before they know what the app does with either
 * permission, so each one is introduced by a screen that explains it and asks
 * the user to tap through to the real prompt themselves.
 */

export type PermissionStep = 'location' | 'notifications';

/**
 * Where the signed-in account sits in the walkthrough. The root navigator
 * switches on this once the profile is ready.
 *
 * `evaluating` holds a neutral screen rather than guessing — guessing
 * "finished" would flash the app before the primer appeared.
 */
export type PermissionOnboardingState =
  | {kind: 'evaluating'}
  | {kind: 'active'; steps: PermissionStep[]}
  | {kind: 'finished'};

// Keyed by Auth UID rather than username, as on iOS: usernames can be reused
// across accounts, and the walkthrough is about this device's prompts.
function completionKey(uid: string) {
  return `hasCompletedPermissionOnboarding_auth_${uid}`;
}

// POST_NOTIFICATIONS only exists from Android 13 (API 33); below that,
// notifications are allowed without asking.
const NEEDS_NOTIFICATION_PROMPT =
  Platform.OS === 'android' && (Platform.Version as number) >= 33;

const LOCATION_PERMISSIONS = [
  PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
  PermissionsAndroid.PERMISSIONS.ACCESS_COARSE_LOCATION,
];

export async function hasLocationPermission(): Promise<boolean> {
  if (Platform.OS !== 'android') {
    return true;
  }
  // Either grant counts: "Approximate" on Android 12+ still finds the stores
  // nearby, and asking again for precise would just be a second prompt.
  const [fine, coarse] = await Promise.all(
    LOCATION_PERMISSIONS.map(permission => PermissionsAndroid.check(permission)),
  );
  return fine || coarse;
}

export async function hasNotificationPermission(): Promise<boolean> {
  if (!NEEDS_NOTIFICATION_PROMPT) {
    return true;
  }
  return PermissionsAndroid.check(PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS);
}

/**
 * Shows the system location prompt. Fine and coarse are asked for together:
 * from Android 12 that is what produces the precise/approximate choice, and a
 * request for fine alone is ignored outright.
 */
export async function requestLocationPermission(): Promise<void> {
  if (Platform.OS !== 'android') {
    return;
  }
  await PermissionsAndroid.requestMultiple(LOCATION_PERMISSIONS);
}

export async function requestNotificationPermission(): Promise<void> {
  if (!NEEDS_NOTIFICATION_PROMPT) {
    return;
  }
  await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS);
}

/**
 * The walkthrough state for the signed-in account. Pass `uid` once the profile
 * is ready (null before), so a second account on the same device gets its own
 * primer.
 */
export function usePermissionOnboarding(uid: string | null): {
  state: PermissionOnboardingState;
  finish: () => void;
} {
  const [state, setState] = useState<PermissionOnboardingState>({kind: 'evaluating'});

  useEffect(() => {
    if (!uid) {
      setState({kind: 'evaluating'});
      return;
    }
    let cancelled = false;
    setState({kind: 'evaluating'});

    (async () => {
      let steps: PermissionStep[] = [];
      try {
        const completed = await AsyncStorage.getItem(completionKey(uid));
        if (completed === 'true') {
          if (!cancelled) {
            setState({kind: 'finished'});
          }
          return;
        }
        // A step is only worth showing while its permission is still missing.
        // Anyone who has already granted both — including an existing user
        // updating into this build — drops straight into the app.
        const [location, notifications] = await Promise.all([
          hasLocationPermission(),
          hasNotificationPermission(),
        ]);
        if (!location) {
          steps.push('location');
        }
        if (!notifications) {
          steps.push('notifications');
        }
      } catch (_) {
        // A storage or permission lookup that fails shouldn't park the user on
        // the loading screen; let them into the app.
        steps = [];
      }
      if (cancelled) {
        return;
      }
      if (steps.length === 0) {
        AsyncStorage.setItem(completionKey(uid), 'true').catch(() => {});
        setState({kind: 'finished'});
      } else {
        setState({kind: 'active', steps});
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [uid]);

  function finish() {
    if (uid) {
      AsyncStorage.setItem(completionKey(uid), 'true').catch(() => {});
    }
    setState({kind: 'finished'});
  }

  return {state, finish};
}
