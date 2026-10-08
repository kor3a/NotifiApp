import {useEffect, useState} from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {BackgroundColorId, isBackgroundColorId} from '../theme/BackgroundTheme';

// Each screen's chosen background, kept on the device rather than in Firestore
// — it's a per-device look, as on iOS. Keys follow the iOS UserDefaults names
// (backgroundColor_<surface>, backgroundShade_<surface>).

export type BackgroundSurface = 'stores';

export interface BackgroundPreference {
  color: BackgroundColorId;
  shade: number; // -1 (lighter) … 1 (deeper), 0 untouched
}

const DEFAULT: BackgroundPreference = {color: 'system', shade: 0};

const cache = new Map<BackgroundSurface, BackgroundPreference>();
const listeners = new Map<BackgroundSurface, Set<() => void>>();
const loads = new Map<BackgroundSurface, Promise<void>>();

const colorKey = (s: BackgroundSurface) => `backgroundColor_${s}`;
const shadeKey = (s: BackgroundSurface) => `backgroundShade_${s}`;

function notify(surface: BackgroundSurface) {
  listeners.get(surface)?.forEach(l => l());
}

function load(surface: BackgroundSurface): Promise<void> {
  let pending = loads.get(surface);
  if (!pending) {
    pending = AsyncStorage.multiGet([colorKey(surface), shadeKey(surface)])
      .then(([[, color], [, shade]]) => {
        // A change made while this was loading wins over what was on disk.
        if (cache.has(surface)) {
          return;
        }
        const parsedShade = Number(shade);
        cache.set(surface, {
          color: isBackgroundColorId(color) ? color : 'system',
          shade: Number.isFinite(parsedShade)
            ? Math.min(Math.max(parsedShade, -1), 1)
            : 0,
        });
        notify(surface);
      })
      .catch(() => {});
    loads.set(surface, pending);
  }
  return pending;
}

function persist(surface: BackgroundSurface, pref: BackgroundPreference) {
  const writes =
    pref.color === 'system' && pref.shade === 0
      ? AsyncStorage.multiRemove([colorKey(surface), shadeKey(surface)])
      : AsyncStorage.multiSet([
          [colorKey(surface), pref.color],
          [shadeKey(surface), String(pref.shade)],
        ]);
  writes.catch(() => {});
}

export const backgroundPreferences = {
  get(surface: BackgroundSurface): BackgroundPreference {
    return cache.get(surface) ?? DEFAULT;
  },

  set(surface: BackgroundSurface, change: Partial<BackgroundPreference>) {
    const next = {...this.get(surface), ...change};
    next.shade = Math.min(Math.max(next.shade, -1), 1);
    cache.set(surface, next);
    persist(surface, next);
    notify(surface);
  },

  reset(surface: BackgroundSurface) {
    this.set(surface, DEFAULT);
  },
};

// The surface's current background, re-rendering whenever it changes.
export function useBackgroundPreference(
  surface: BackgroundSurface,
): BackgroundPreference {
  const [pref, setPref] = useState(() => backgroundPreferences.get(surface));

  useEffect(() => {
    const listener = () => setPref(backgroundPreferences.get(surface));
    let set = listeners.get(surface);
    if (!set) {
      set = new Set();
      listeners.set(surface, set);
    }
    set.add(listener);
    load(surface);
    listener();
    return () => {
      set?.delete(listener);
    };
  }, [surface]);

  return pref;
}
