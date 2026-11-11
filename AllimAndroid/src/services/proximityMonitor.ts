import {AppState, NativeEventSubscription} from 'react-native';
import firestore from '@react-native-firebase/firestore';
import {
  GeofenceCandidateEntry,
  allimGeofence,
} from '../../modules/allim-geofence';
import {UserStoreItem, reminderStoreIdFor} from '../models';
import {locationService} from './locationService';
import {
  LatLng,
  MonitoredUserStore,
  groupStores,
  pickCandidates,
} from './proximityPlanner';
import {activeReminderCount} from './storeService';
import {storeLocationService} from './storeLocationService';

// ─── "You're near <store>" ───────────────────────────────────────────────────
//
// Port of the iOS LocationMonitoringManager. While the app runs, this keeps the
// native geofence pool (modules/allim-geofence) in step with the user's stores,
// their reminder counts and where they are. The geofences themselves, the live
// count check and the notification all live natively, so they keep working
// after the app is closed — this only has to run now and then to refresh them.

// The burst of count updates on first load is folded into one sync — the iOS
// priorityRefreshCoalesceDelay.
const SYNC_DELAY_MS = 2000;
// A fix this recent is reused rather than asking for another.
const POSITION_MAX_AGE_MS = 2 * 60 * 1000;

interface Session {
  userId: string;
  stores: MonitoredUserStore[];
  counts: Map<string, number>;
  countUnsubs: Map<string, () => void>;
  unsubscribeStores: () => void;
  appState: NativeEventSubscription;
  timer: ReturnType<typeof setTimeout> | null;
}

let session: Session | null = null;
let lastPosition: {coords: LatLng; at: number} | null = null;
let syncing = false;
let syncAgain = false;

function log(...args: unknown[]) {
  if (__DEV__) {
    console.log('[proximity]', ...args);
  }
}

async function currentPosition(): Promise<LatLng | null> {
  if (lastPosition && Date.now() - lastPosition.at < POSITION_MAX_AGE_MS) {
    return lastPosition.coords;
  }
  try {
    const coords = await locationService.getCurrentPosition();
    lastPosition = {
      coords: {latitude: coords.latitude, longitude: coords.longitude},
      at: Date.now(),
    };
    return lastPosition.coords;
  } catch (error) {
    log('No location fix', error);
    return lastPosition?.coords ?? null;
  }
}

function scheduleSync() {
  const current = session;
  if (!current) {
    return;
  }
  if (current.timer) {
    clearTimeout(current.timer);
  }
  current.timer = setTimeout(() => {
    current.timer = null;
    runSync().catch(error => log('Sync failed', error));
  }, SYNC_DELAY_MS);
}

// One sync at a time; a request that lands mid-sync runs once it's done.
async function runSync() {
  if (syncing) {
    syncAgain = true;
    return;
  }
  syncing = true;
  try {
    do {
      syncAgain = false;
      await syncOnce();
    } while (syncAgain);
  } finally {
    syncing = false;
  }
}

async function syncOnce() {
  const current = session;
  if (!current || !allimGeofence.isAvailable) {
    return;
  }

  // Nothing would fire, so don't spend (billed) branch lookups on it. The next
  // foreground after the user grants it syncs again.
  const problem = allimGeofence.permissionProblem();
  if (problem) {
    log('Geofencing unavailable:', problem);
    return;
  }

  const position = await currentPosition();
  if (!position || session !== current) {
    return;
  }

  const stores = groupStores(current.stores, current.counts);
  const candidates: GeofenceCandidateEntry[] = [];
  let failedLookups = 0;
  for (const store of stores) {
    try {
      const branches = await storeLocationService.nearbyBranches(store.name, position);
      candidates.push(...pickCandidates(store.key, branches, position));
    } catch (error) {
      failedLookups++;
      log(`Branch lookup failed for '${store.name}'`, error);
    }
  }

  // Every lookup failed — most likely offline. Keep the fences already
  // registered rather than replacing them with nothing, as iOS does.
  if (stores.length > 0 && failedLookups === stores.length) {
    return;
  }
  // Signed out, or someone else signed in, while the lookups ran.
  if (session !== current) {
    return;
  }

  const status = await allimGeofence.setPool({stores, candidates, reference: position});
  log(`${status}: ${stores.length} store(s), ${candidates.length} branch(es)`);
}

function syncCountListeners(current: Session) {
  const wanted = new Set(current.stores.map(store => store.reminderStoreId));

  current.countUnsubs.forEach((unsub, id) => {
    if (!wanted.has(id)) {
      unsub();
      current.countUnsubs.delete(id);
      current.counts.delete(id);
    }
  });

  wanted.forEach(id => {
    if (current.countUnsubs.has(id)) {
      return;
    }
    const unsub = firestore()
      .collection('reminders')
      .where('userStoreId', '==', id)
      .onSnapshot(
        snap => {
          const count = activeReminderCount(snap.docs);
          // Whether a list is empty decides which stores win the fences and
          // is the native fallback count, so a change re-syncs.
          if (current.counts.get(id) !== count) {
            current.counts.set(id, count);
            scheduleSync();
          }
        },
        () => {},
      );
    current.countUnsubs.set(id, unsub);
  });
}

export const proximityMonitor = {
  /** Watch the signed-in user's stores. `userId` is the username user_stores are keyed by. */
  start(userId: string) {
    if (session?.userId === userId) {
      return;
    }
    proximityMonitor.stop();

    const current: Session = {
      userId,
      stores: [],
      counts: new Map(),
      countUnsubs: new Map(),
      unsubscribeStores: () => {},
      // Returning to the app is when permissions may have changed (Settings) and
      // when Android may have dropped the fences (location switched off).
      appState: AppState.addEventListener('change', state => {
        if (state === 'active') {
          scheduleSync();
        }
      }),
      timer: null,
    };
    session = current;

    current.unsubscribeStores = firestore()
      .collection('user_stores')
      .where('userId', '==', userId)
      .onSnapshot(
        snap => {
          current.stores = snap.docs.map(doc => {
            const data = doc.data();
            return {
              storeName: (data.storeName as string) ?? '',
              // A store the user created carries no permission: they own it.
              reminderStoreId: reminderStoreIdFor({
                id: doc.id,
                permission: data.permission ?? 'owner',
                sourceUserStoreId: data.sourceUserStoreId,
                sharedStoreGroupId: data.sharedStoreGroupId,
              } as UserStoreItem),
              // Set to false on iOS to mute a store's proximity alerts.
              notificationsEnabled: data.notificationsEnabled !== false,
            };
          });
          syncCountListeners(current);
          scheduleSync();
        },
        error => log('Could not watch stores', error),
      );
  },

  /**
   * Stop watching. The registered geofences stay: they're what notifies the
   * user once the app is closed.
   */
  stop() {
    const current = session;
    if (!current) {
      return;
    }
    session = null;
    if (current.timer) {
      clearTimeout(current.timer);
    }
    current.appState.remove();
    current.unsubscribeStores();
    current.countUnsubs.forEach(unsub => unsub());
    current.countUnsubs.clear();
  },

  /** Re-sync soon, e.g. right after a permission prompt. */
  refresh() {
    scheduleSync();
  },

  /** Sign-out: stop, and drop the account's geofences and saved stores. */
  async clear() {
    proximityMonitor.stop();
    lastPosition = null;
    await allimGeofence.clear();
  },
};
