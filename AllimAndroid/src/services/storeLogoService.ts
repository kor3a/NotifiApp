import firestore from '@react-native-firebase/firestore';

// ─── Store logos ─────────────────────────────────────────────────────────────
//
// The iOS StoreLogoProvider reads the global `stores_logos` catalog (document
// id = normalized store name, field `logoURL`) once and keeps it in memory.
// This is the same lookup. The iOS app's further fallbacks (Logo.dev search,
// MapKit website domains) are not ported — a store without a catalog entry
// shows its initial instead.

// Must match iOS `Store.normalizedId(from:)` exactly, since that is how the
// catalog documents are keyed. It is not the same normalization storeService
// uses for `storeId`.
export function logoKeyFor(storeName: string): string {
  return storeName
    .toLowerCase()
    .trim()
    .replace(/ /g, '-')
    .replace(/'/g, '')
    .replace(/\./g, '')
    .replace(/,/g, '')
    .replace(/&/g, 'and');
}

let logos: Map<string, string> | null = null;
let inFlight: Promise<Map<string, string>> | null = null;

export const storeLogoService = {
  // Loads the catalog once per app session; later calls share the result.
  load(): Promise<Map<string, string>> {
    if (logos) {
      return Promise.resolve(logos);
    }
    if (!inFlight) {
      inFlight = firestore()
        .collection('stores_logos')
        .get()
        .then(snap => {
          const map = new Map<string, string>();
          snap.docs.forEach(doc => {
            const url = doc.data().logoURL;
            if (typeof url === 'string' && url) {
              map.set(doc.id, url);
            }
          });
          logos = map;
          return map;
        })
        .catch(() => {
          // Allow a retry on the next call rather than caching the failure.
          inFlight = null;
          return new Map<string, string>();
        });
    }
    return inFlight;
  },

  logoURL(storeName: string): string | undefined {
    return logos?.get(logoKeyFor(storeName));
  },
};
