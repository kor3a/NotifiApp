import functions from '@react-native-firebase/functions';
import {Coordinates} from './locationService';

// ─── Types ────────────────────────────────────────────────────────────────────

export interface SearchResultStore {
  id: string; // Normalized store name
  name: string;
  nearestDistanceMeters: number;
  locationCount: number;
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
};
