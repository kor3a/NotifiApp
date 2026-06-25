import {locationService, Coordinates} from './locationService';

// ─── Configuration ────────────────────────────────────────────────────────────
//
// To enable nearby store search:
//   1. In Google Cloud Console, enable the "Places API (New)" and set up
//      billing for the project.
//   2. Create an API key, restrict it to the Places API and (recommended)
//      to your Android app's package name + SHA-1.
//   3. Paste the key below.
//
// Leave empty to disable nearby search — the Add Store sheet will show an
// "API key not configured" message instead of crashing.
const GOOGLE_PLACES_API_KEY = '';

// Search radius around the user, in meters.
const SEARCH_RADIUS_METERS = 20000;

// ─── Types ────────────────────────────────────────────────────────────────────

export interface SearchResultStore {
  id: string; // Normalized store name
  name: string;
  nearestDistanceMeters: number;
  locationCount: number;
}

function normalizeStoreId(name: string): string {
  return name.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '');
}

export function distanceFormattedMiles(meters: number): string {
  const miles = meters * 0.000621371;
  return `${miles.toFixed(1)} mi`;
}

// ─── Service ──────────────────────────────────────────────────────────────────

export const placesSearchService = {
  isConfigured(): boolean {
    return GOOGLE_PLACES_API_KEY.length > 0;
  },

  async searchNearby(
    query: string,
    userLocation: Coordinates,
  ): Promise<SearchResultStore[]> {
    if (!query.trim()) {return [];}
    if (!GOOGLE_PLACES_API_KEY) {
      throw new Error(
        'Google Places API key is not configured. See src/services/placesSearchService.ts.',
      );
    }

    const res = await fetch(
      'https://places.googleapis.com/v1/places:searchText',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': GOOGLE_PLACES_API_KEY,
          'X-Goog-FieldMask': 'places.displayName,places.location',
        },
        body: JSON.stringify({
          textQuery: query,
          locationBias: {
            circle: {
              center: {
                latitude: userLocation.latitude,
                longitude: userLocation.longitude,
              },
              radius: SEARCH_RADIUS_METERS,
            },
          },
        }),
      },
    );

    if (!res.ok) {
      const errBody = await res.text().catch(() => '');
      throw new Error(
        `Places API error (${res.status}): ${errBody || res.statusText}`,
      );
    }

    const json = await res.json();
    const places: any[] = json.places ?? [];

    // Group results by normalized store name. Each unique store name appears
    // once with its nearest location's distance + total nearby location count.
    const groups = new Map<
      string,
      {displayName: string; distances: number[]}
    >();
    for (const p of places) {
      const name: string | undefined = p.displayName?.text;
      const loc = p.location;
      if (!name || !loc) {continue;}
      const dist = locationService.distanceBetween(userLocation, {
        latitude: loc.latitude,
        longitude: loc.longitude,
      });
      const id = normalizeStoreId(name);
      const existing = groups.get(id);
      if (existing) {
        existing.distances.push(dist);
      } else {
        groups.set(id, {displayName: name, distances: [dist]});
      }
    }

    const results: SearchResultStore[] = [];
    for (const [id, data] of groups.entries()) {
      const nearest = Math.min(...data.distances);
      results.push({
        id,
        name: data.displayName,
        nearestDistanceMeters: nearest,
        locationCount: data.distances.length,
      });
    }
    results.sort(
      (a, b) => a.nearestDistanceMeters - b.nearestDistanceMeters,
    );
    return results;
  },
};
