import AsyncStorage from '@react-native-async-storage/async-storage';
import {Coordinates} from './locationService';
import {PlaceBranch, placesSearchService} from './placesSearchService';

// ─── Store branches for the map ───────────────────────────────────────────────
//
// A store is only a name, so the map has to look up where its branches are. iOS
// does that with MKLocalSearch, which is free. Android goes through the
// `searchNearbyStores` Cloud Function, where every lookup is a billed Places
// request, so results are kept on disk and shared by everything nearby: one
// store in one ~11 km tile costs one request per 30 days, however much the map
// moves. Google's terms also cap how long coordinates may be cached at 30 days.

const CACHE_KEY = 'storeBranchCache_v2';
const CACHE_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const SAVE_DELAY_MS = 500;
const TILE_DEGREES = 0.1;
// The same cap iOS puts on each store's search results.
const MAX_BRANCHES_PER_SEARCH = 10;
// About 150 m: closer than two branches of a chain, wider than a large store.
const SAME_SPOT_DEGREES = 0.0015;

export interface StoreBranch extends PlaceBranch {
  id: string;
}

interface CacheEntry {
  savedAt: number;
  branches: StoreBranch[];
}

// The centre of the tile a point falls in. Searches are made from here rather
// than the exact map centre so that nearby searches can share a cache entry.
export function searchTile(point: Coordinates): Coordinates {
  const snap = (value: number) =>
    Number((Math.round(value / TILE_DEGREES) * TILE_DEGREES).toFixed(1));
  return {latitude: snap(point.latitude), longitude: snap(point.longitude)};
}

function comparableName(name: string): string {
  return name.toLowerCase().replace(/[\s'’`".,&°()_-]/g, '');
}

// Places matches loosely and will happily return a competitor for a chain's
// name, so a result has to carry the store's name: "H Mart" takes "H Mart
// Diamond Bar", and "Starbucks Coffee Company" takes "Starbucks".
export function isSameStore(storeName: string, placeName: string): boolean {
  const store = comparableName(storeName);
  const place = comparableName(placeName);
  return (
    store.length > 0 &&
    place.length > 0 &&
    (place.includes(store) || store.includes(place))
  );
}

export function pickBranches(
  storeName: string,
  places: PlaceBranch[],
  center: Coordinates,
): StoreBranch[] {
  const distance = (place: PlaceBranch) =>
    Math.hypot(
      place.latitude - center.latitude,
      place.longitude - center.longitude,
    );
  // Places lists a store's departments separately ("Vons", "Vons Pharmacy", "Vons
  // Bakery"), which would stack logos on one building, so a spot counts once.
  const branches: StoreBranch[] = [];
  places
    .filter(place => isSameStore(storeName, place.name))
    .sort((a, b) => distance(a) - distance(b))
    .forEach(place => {
      const isNewSpot = !branches.some(
        kept =>
          Math.abs(kept.latitude - place.latitude) < SAME_SPOT_DEGREES &&
          Math.abs(kept.longitude - place.longitude) < SAME_SPOT_DEGREES,
      );
      if (isNewSpot) {
        branches.push({...place, id: `${place.latitude}_${place.longitude}`});
      }
    });
  return branches.slice(0, MAX_BRANCHES_PER_SEARCH);
}

let cache: Record<string, CacheEntry> | null = null;
let cacheLoad: Promise<Record<string, CacheEntry>> | null = null;
let saveTimer: ReturnType<typeof setTimeout> | null = null;
// Bumped on sign-out, so a search still in flight can't write back afterwards.
let generation = 0;
const inFlight = new Map<string, Promise<StoreBranch[]>>();

function loadCache(): Promise<Record<string, CacheEntry>> {
  if (cache) {
    return Promise.resolve(cache);
  }
  if (!cacheLoad) {
    const loadGeneration = generation;
    cacheLoad = AsyncStorage.getItem(CACHE_KEY)
      .then(saved => (saved ? JSON.parse(saved) : {}))
      .catch(() => ({}))
      .then((loaded: Record<string, CacheEntry>) => {
        const now = Date.now();
        const fresh = Object.fromEntries(
          Object.entries(loaded).filter(
            ([, entry]) => now - entry.savedAt < CACHE_TTL_MS,
          ),
        );
        if (loadGeneration !== generation) {
          return cache ?? {};
        }
        cache = fresh;
        cacheLoad = null;
        return fresh;
      });
  }
  return cacheLoad;
}

function scheduleSave() {
  if (saveTimer) {
    clearTimeout(saveTimer);
  }
  saveTimer = setTimeout(() => {
    saveTimer = null;
    if (cache) {
      AsyncStorage.setItem(CACHE_KEY, JSON.stringify(cache)).catch(() => {});
    }
  }, SAVE_DELAY_MS);
}

export const storeLocationService = {
  // The store's branches around `center`, nearest first. Rejects if the lookup
  // fails, and nothing is cached in that case, so the next attempt tries again.
  async nearbyBranches(
    storeName: string,
    center: Coordinates,
  ): Promise<StoreBranch[]> {
    const tile = searchTile(center);
    const key = `${comparableName(storeName)}|${tile.latitude},${tile.longitude}`;

    const entries = await loadCache();
    const cached = entries[key];
    if (cached && Date.now() - cached.savedAt < CACHE_TTL_MS) {
      return cached.branches;
    }

    const pending = inFlight.get(key);
    if (pending) {
      return pending;
    }

    const searchGeneration = generation;
    const search = placesSearchService
      .searchBranches(storeName, tile)
      .then(places => {
        const branches = pickBranches(storeName, places, tile);
        if (searchGeneration === generation && cache) {
          cache[key] = {savedAt: Date.now(), branches};
          scheduleSave();
        }
        return branches;
      })
      .finally(() => {
        inFlight.delete(key);
      });
    inFlight.set(key, search);
    return search;
  },

  // Drops the in-memory copy on sign-out; sessionCleanup removes the stored one.
  clearCache() {
    generation++;
    cache = null;
    cacheLoad = null;
    inFlight.clear();
    if (saveTimer) {
      clearTimeout(saveTimer);
      saveTimer = null;
    }
  },
};
