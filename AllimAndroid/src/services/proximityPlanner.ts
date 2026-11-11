import type {
  GeofenceCandidateEntry,
  GeofenceStoreEntry,
} from '../../modules/allim-geofence';

// ─── Store-proximity planning ────────────────────────────────────────────────
//
// The pure half of proximityMonitor: which stores to watch, and which of their
// branches are worth a geofence. Kept free of Firebase and native imports so it
// can be tested on its own.

/**
 * How far out a branch is still worth a geofence — the iOS searchRadius. The
 * notification itself only fires inside the 150 m fence.
 */
export const SEARCH_RADIUS_METERS = 15000;

/**
 * Branches per store. iOS stops at 2 because Core Location allows 20 regions;
 * Android allows 100, and native re-ranks the whole pool as the user moves.
 */
export const MAX_BRANCHES_PER_STORE = 5;

/** One user_store row, reduced to what proximity needs. */
export interface MonitoredUserStore {
  storeName: string;
  reminderStoreId: string; // where its reminders live (shared-aware)
  notificationsEnabled: boolean;
}

export interface LatLng {
  latitude: number;
  longitude: number;
}

/** Groups rows that name the same store. Mirrors iOS Store.normalizedId. */
export function proximityStoreKey(name: string): string {
  return name.trim().toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '');
}

/**
 * One entry per store name. A name can have several lists behind it (an owned
 * one plus one shared in by a friend); all of them count toward what's waiting
 * there, and a list two rows both point at is only counted once.
 */
export function groupStores(
  userStores: MonitoredUserStore[],
  counts: ReadonlyMap<string, number>,
): GeofenceStoreEntry[] {
  const byKey = new Map<string, {name: string; ids: Set<string>}>();
  userStores.forEach(store => {
    if (!store.notificationsEnabled) {
      return;
    }
    const key = proximityStoreKey(store.storeName);
    if (!key) {
      return;
    }
    const entry = byKey.get(key) ?? {name: store.storeName.trim(), ids: new Set()};
    entry.ids.add(store.reminderStoreId);
    byKey.set(key, entry);
  });

  return [...byKey.entries()].map(([key, {name, ids}]) => {
    const reminderStoreIds = [...ids];
    return {
      key,
      name,
      reminderStoreIds,
      cachedCount: reminderStoreIds.reduce((sum, id) => sum + (counts.get(id) ?? 0), 0),
    };
  });
}

// Haversine, in meters.
export function distanceMeters(a: LatLng, b: LatLng): number {
  const R = 6371e3;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(b.latitude - a.latitude);
  const dLng = toRad(b.longitude - a.longitude);
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.latitude)) * Math.cos(toRad(b.latitude)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
}

/** A store's nearest branches within the search radius. */
export function pickCandidates(
  storeKey: string,
  branches: LatLng[],
  position: LatLng,
): GeofenceCandidateEntry[] {
  return branches
    .map(branch => ({branch, distance: distanceMeters(position, branch)}))
    .filter(({distance}) => distance <= SEARCH_RADIUS_METERS)
    .sort((a, b) => a.distance - b.distance)
    .slice(0, MAX_BRANCHES_PER_STORE)
    .map(({branch}) => ({
      key: storeKey,
      latitude: branch.latitude,
      longitude: branch.longitude,
    }));
}
