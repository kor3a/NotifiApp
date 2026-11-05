import functions from '@react-native-firebase/functions';
import {Coordinates} from './locationService';

// ─── Types ────────────────────────────────────────────────────────────────────

export interface SearchResultStore {
  id: string; // Normalized store name
  name: string;
  nearestDistanceMeters: number;
  locationCount: number;
}

// One physical location, as opposed to the per-chain SearchResultStore.
export interface PlaceBranch {
  name: string;
  latitude: number;
  longitude: number;
}

export function distanceFormattedMiles(meters: number): string {
  const miles = meters * 0.000621371;
  return `${miles.toFixed(1)} mi`;
}

// ─── Service ──────────────────────────────────────────────────────────────────
//
// Nearby store search proxies through the `searchNearbyStores` Cloud Function
// (see functions/index.js). The Google Places API key lives in Firebase
// Functions secrets, not in this bundle, so it can't be extracted from the APK.

export const placesSearchService = {
  async searchNearby(
    query: string,
    userLocation: Coordinates,
  ): Promise<SearchResultStore[]> {
    if (!query.trim()) {return [];}
    const callable = functions().httpsCallable('searchNearbyStores');
    const {data} = await callable({
      query: query.trim(),
      latitude: userLocation.latitude,
      longitude: userLocation.longitude,
    });
    return (data?.results ?? []) as SearchResultStore[];
  },

  // Throws when the response has no `branches` at all (a function older than
  // this client) so that isn't mistaken for "no branches here" and cached.
  async searchBranches(
    query: string,
    center: Coordinates,
  ): Promise<PlaceBranch[]> {
    const callable = functions().httpsCallable<
      {query: string; latitude: number; longitude: number},
      {branches?: PlaceBranch[]}
    >('searchNearbyStores');
    const {data} = await callable({
      query: query.trim(),
      latitude: center.latitude,
      longitude: center.longitude,
    });
    if (!Array.isArray(data?.branches)) {
      throw new Error('searchNearbyStores returned no branches field.');
    }
    return data.branches;
  },
};
