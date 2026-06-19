import {Coordinates} from './locationService';
import {GOOGLE_MAPS_API_KEY} from '../config/maps';

// A concrete branch of a store chain near the user, resolved from the store
// name via the Google Places API. Mirrors the iOS app, which uses MKLocalSearch
// to find nearby branches of each saved store.
export interface StoreLocation {
  id: string; // Places place_id
  userStoreId: string; // the user_store this branch belongs to
  storeId: string;
  storeName: string;
  name: string; // branch name from Places (usually same as store name)
  address?: string;
  coordinate: Coordinates;
}

export const placesService = {
  // Find nearby branches of a store chain by name, biased to `near`.
  async searchStoreLocations(
    storeName: string,
    near: Coordinates,
    opts: {userStoreId: string; storeId: string; radiusMeters?: number; limit?: number},
  ): Promise<StoreLocation[]> {
    if (!GOOGLE_MAPS_API_KEY) {return [];}
    const radius = opts.radiusMeters ?? 8000;
    const url =
      'https://maps.googleapis.com/maps/api/place/textsearch/json' +
      `?query=${encodeURIComponent(storeName)}` +
      `&location=${near.latitude},${near.longitude}` +
      `&radius=${radius}` +
      `&key=${GOOGLE_MAPS_API_KEY}`;

    try {
      const res = await fetch(url);
      const json: any = await res.json();
      if (json.status !== 'OK' && json.status !== 'ZERO_RESULTS') {
        // REQUEST_DENIED usually means the Places API isn't enabled for the key.
        console.warn(
          `Places search for "${storeName}" failed: ${json.status} ${json.error_message ?? ''}`,
        );
        return [];
      }
      const results: any[] = json.results ?? [];
      return results.slice(0, opts.limit ?? 8).map(r => ({
        id: r.place_id,
        userStoreId: opts.userStoreId,
        storeId: opts.storeId,
        storeName,
        name: r.name ?? storeName,
        address: r.formatted_address,
        coordinate: {
          latitude: r.geometry?.location?.lat,
          longitude: r.geometry?.location?.lng,
        },
      })).filter(
        l =>
          typeof l.coordinate.latitude === 'number' &&
          typeof l.coordinate.longitude === 'number',
      );
    } catch (e) {
      console.warn(`Places search for "${storeName}" error:`, e);
      return [];
    }
  },
};
