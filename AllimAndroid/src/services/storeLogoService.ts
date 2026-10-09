import AsyncStorage from '@react-native-async-storage/async-storage';
import firestore from '@react-native-firebase/firestore';
import functions from '@react-native-firebase/functions';
import Constants from 'expo-constants';
import {
  businessSuffixes,
  civicNamePhrases,
  storeDomains,
} from './storeLogoDomains';

// ─── Store logos ─────────────────────────────────────────────────────────────
//
// The same resolution as the iOS StoreLogoProvider:
//   1. The global `stores_logos` catalog (document id = normalized store name,
//      field `logoURL`) — exact, canonical or prefix match, so "Walmart
//      Supercenter" still finds the "walmart" logo.
//   2. A Logo.dev image for the store's domain: a `store_websites` override,
//      the built-in domain map, or a domain Brand Search confirmed earlier.
//   3. A guessed "{name}.com", asked for with `fallback=404` so a wrong guess
//      fails to load instead of showing Logo.dev's generic monogram.
//   4. When nothing resolves, or the image fails, the `logoBrandSearch` Cloud
//      Function looks the name up; a confident hit is remembered on the device.
// Steps 2–4 need the publishable Logo.dev token (`extra.logoDevToken`); without
// it only the catalog is used. iOS also learns domains from MapKit place
// records — the Places search here doesn't return websites, so that isn't
// ported.

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

// iOS `canonicalLogoKey`: symbols dropped and separators collapsed to a single
// hyphen, so "85°c-bakery-cafe" and "85c bakery cafe" match.
export function canonicalLogoKey(value: string): string {
  return value
    .toLowerCase()
    .replace(/&/g, 'and')
    .replace(/[\s\-_/]+/g, '-')
    .replace(/[^\p{L}\p{N}-]/gu, '')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

// The longest key, measured by `length` — the iOS tie-break throughout.
function longest(
  keys: string[],
  length: (key: string) => number = key => key.length,
): string | undefined {
  return keys.reduce<string | undefined>(
    (best, key) => (!best || length(key) > length(best) ? key : best),
    undefined,
  );
}

const canonicalLength = (key: string) => canonicalLogoKey(key).length;

// A key naming the same store: literal, or differing only by punctuation.
function exactKey(keys: string[], id: string): string | undefined {
  if (keys.includes(id)) {
    return id;
  }
  const canonicalId = canonicalLogoKey(id);
  return longest(keys.filter(key => canonicalLogoKey(key) === canonicalId));
}

// The catalog key for a store: exact, then the longest raw or canonical prefix
// ("walmart-supercenter" → "walmart"). Mirrors iOS `bestLogoKey(for:)`.
export function bestLogoKey(keys: string[], id: string): string | undefined {
  const canonicalId = canonicalLogoKey(id);
  return (
    exactKey(keys, id) ??
    longest(keys.filter(key => id.startsWith(key))) ??
    longest(
      keys.filter(key => canonicalId.startsWith(canonicalLogoKey(key))),
      canonicalLength,
    )
  );
}

const domainKeys = Object.keys(storeDomains);

// The built-in domain map, with iOS `mappedDomain(for:)`'s fuzzy steps: a
// leading "the-" stripped, the longest prefix, then a business-type suffix
// stripped. Never a bare guess from the stripped name — "zion-market" is not
// zion.com.
export function mappedDomain(id: string): string | undefined {
  const exact = exactKey(domainKeys, id);
  if (exact) {
    return storeDomains[exact];
  }
  const withoutThe = id.startsWith('the-') ? id.slice(4) : id;
  if (storeDomains[withoutThe]) {
    return storeDomains[withoutThe];
  }
  for (const candidate of new Set([id, withoutThe])) {
    const prefix = longest(domainKeys.filter(key => candidate.startsWith(key)));
    if (prefix) {
      return storeDomains[prefix];
    }
  }
  const canonicalId = canonicalLogoKey(id);
  const canonicalPrefix = longest(
    domainKeys.filter(key => canonicalId.startsWith(canonicalLogoKey(key))),
    canonicalLength,
  );
  if (canonicalPrefix) {
    return storeDomains[canonicalPrefix];
  }
  for (const suffix of businessSuffixes) {
    const stripped = id.endsWith(suffix) ? id.slice(0, -suffix.length) : '';
    if (stripped && storeDomains[stripped]) {
      return storeDomains[stripped];
    }
  }
  return undefined;
}

// "zion-market" → zionmarket.com, "starbucks" → starbucks.com. Civic names
// (libraries, city halls…) never own such a domain, so they get no guess.
export function guessedDomain(id: string): string | undefined {
  const padded = `-${id}-`;
  if (civicNamePhrases.some(phrase => padded.includes(phrase))) {
    return undefined;
  }
  const parts = id.split('-').filter(Boolean);
  return parts.length >= 1 && parts.length <= 4
    ? `${parts.join('')}.com`
    : undefined;
}

// "https://www.snrtea.com/menu" → "snrtea.com".
function hostOf(url: string): string | undefined {
  const host = url
    .trim()
    .toLowerCase()
    .replace(/^[a-z]+:\/\//, '')
    .split(/[/?#]/)[0]
    .replace(/^www\./, '');
  return host || undefined;
}

// Publishable — it only goes into image URLs. Set from app.config.js.
const LOGO_DEV_TOKEN: string | undefined =
  (Constants.expoConfig?.extra as any)?.logoDevToken || undefined;

function logoDevURL(domain: string, speculative = false): string | undefined {
  if (!LOGO_DEV_TOKEN) {
    return undefined;
  }
  const url = `https://img.logo.dev/${domain}?token=${LOGO_DEV_TOKEN}`;
  return speculative ? `${url}&fallback=404` : url;
}

const SEARCHED_DOMAINS_KEY = 'storeLogo.searchedDomains';

let logos: Map<string, string> | null = null;
let logoKeys: string[] = [];
let websites = new Map<string, string>();
let searchedDomains = new Map<string, string>();
let inFlight: Promise<void> | null = null;
// Brand searches by normalized ID — each name is searched once per session.
const searches = new Map<string, Promise<string | undefined>>();
// `logoURL` results, cleared whenever the data behind them changes.
const resolved = new Map<string, string | undefined>();

async function readCollection(
  name: string,
  field: string,
): Promise<Map<string, string>> {
  const snap = await firestore().collection(name).get();
  const map = new Map<string, string>();
  snap.docs.forEach(doc => {
    const value = doc.data()[field];
    if (typeof value === 'string' && value) {
      map.set(doc.id, value);
    }
  });
  return map;
}

async function readSearchedDomains(): Promise<Map<string, string>> {
  try {
    const raw = await AsyncStorage.getItem(SEARCHED_DOMAINS_KEY);
    return new Map(Object.entries(raw ? JSON.parse(raw) : {}));
  } catch {
    return new Map();
  }
}

// A trusted domain for the store — never a guess. iOS `resolvedDomain(for:)`.
function resolvedDomain(id: string): string | undefined {
  const override = exactKey([...websites.keys()], id);
  return (
    (override ? hostOf(websites.get(override)!) : undefined) ??
    mappedDomain(id) ??
    searchedDomains.get(id)
  );
}

function computeLogoURL(id: string): string | undefined {
  const key = bestLogoKey(logoKeys, id);
  if (key) {
    return logos!.get(key);
  }
  const domain = resolvedDomain(id);
  if (domain) {
    return logoDevURL(domain);
  }
  const guess = guessedDomain(id);
  return guess ? logoDevURL(guess, true) : undefined;
}

export const storeLogoService = {
  // Loads the catalog, website overrides and remembered search results once per
  // app session; later calls share the result.
  load(): Promise<void> {
    if (logos) {
      return Promise.resolve();
    }
    if (!inFlight) {
      inFlight = Promise.all([
        readCollection('stores_logos', 'logoURL'),
        // Overrides only refine Logo.dev lookups; the catalog works without them.
        readCollection('store_websites', 'websiteURL').catch(
          () => new Map<string, string>(),
        ),
        readSearchedDomains(),
      ])
        .then(([catalog, overrides, searched]) => {
          logos = catalog;
          logoKeys = [...catalog.keys()];
          websites = overrides;
          searchedDomains = searched;
          resolved.clear();
        })
        .catch(() => {
          // Allow a retry on the next call rather than caching the failure.
          inFlight = null;
        });
    }
    return inFlight;
  },

  // The best logo URL known right now, or undefined when only a Brand Search
  // could find one (see `searchLogoURL`). Before `load` finishes this is
  // undefined, so a catalog logo never loses to a guessed one.
  logoURL(storeName: string): string | undefined {
    const id = logoKeyFor(storeName);
    if (!logos || !id) {
      return undefined;
    }
    if (!resolved.has(id)) {
      resolved.set(id, computeLogoURL(id));
    }
    return resolved.get(id);
  },

  // Looks the store up with Logo.dev Brand Search — for when `logoURL` had
  // nothing or its image failed to load. Resolves to the new URL, or undefined
  // when there is no confident match. A hit is kept on the device, so a store
  // is searched at most once per session, and once ever when it succeeds.
  searchLogoURL(storeName: string): Promise<string | undefined> {
    const id = logoKeyFor(storeName);
    const pending = searches.get(id);
    if (pending) {
      return pending;
    }
    // A remembered domain is already what `logoURL` returned; searching again
    // would only find it a second time.
    if (!LOGO_DEV_TOKEN || !id || searchedDomains.has(id)) {
      return Promise.resolve(undefined);
    }
    const search = functions()
      .httpsCallable('logoBrandSearch')({query: storeName})
      .then(({data}) => {
        const domain = (data as any)?.domain;
        if (typeof domain !== 'string' || !domain) {
          return undefined;
        }
        searchedDomains.set(id, domain);
        resolved.delete(id);
        AsyncStorage.setItem(
          SEARCHED_DOMAINS_KEY,
          JSON.stringify(Object.fromEntries(searchedDomains)),
        ).catch(() => {});
        return logoDevURL(domain);
      })
      .catch(() => undefined);
    searches.set(id, search);
    return search;
  },
};
