import {Region} from 'react-native-maps';
import {UserStoreItem} from '../../models';
import {StoreBranch} from '../../services/storeLocationService';

// ─── Grouping map markers ─────────────────────────────────────────────────────
//
// Google Maps on Android draws a custom marker from a bitmap of its view, so the
// number on screen has a real cost that MapKit's annotations don't. Markers that
// would overlap at the current zoom become one: a shop icon with a count.

// Wide enough that two logos in one group would touch or nearly touch.
const CLUSTER_RADIUS_DP = 44;
// A hard limit on top of grouping, whatever the map is showing.
export const MAX_VISIBLE_MARKERS = 40;
// Markers are kept slightly past the visible span so they don't pop in at the edge.
const VISIBLE_SPAN_MULTIPLIER = 1.5;
// The closest a tap on a group zooms: about 450 m across.
export const MIN_CLUSTER_ZOOM_DELTA = 0.004;
const CLUSTER_ZOOM_PADDING = 1.6;

export interface BranchMarker {
  item: UserStoreItem;
  branch: StoreBranch;
}

export interface MarkerCluster extends BranchMarker {
  id: string;
  members: StoreBranch[];
}

export function markerId({item, branch}: BranchMarker): string {
  return `${item.id}_${branch.id}`;
}

// The store with the most reminders anchors the group, and is what a tap opens
// when zooming can't pull the group apart. The ids break ties, so the same marker
// wins every time and groups don't shift while panning.
function byPriority(a: BranchMarker, b: BranchMarker): number {
  return (
    (b.item.store.reminderCount ?? 0) - (a.item.store.reminderCount ?? 0) ||
    markerId(a).localeCompare(markerId(b))
  );
}

export function clusterMarkers(
  markers: BranchMarker[],
  region: Region,
  screenWidth: number,
): MarkerCluster[] {
  const radiusLng = (region.longitudeDelta / screenWidth) * CLUSTER_RADIUS_DP;
  // A degree of latitude shrinks on screen towards the equator, Mercator-style.
  const radiusLat = radiusLng * Math.cos((region.latitude * Math.PI) / 180);

  const clusters: MarkerCluster[] = [];
  [...markers].sort(byPriority).forEach(marker => {
    const nearby = clusters.find(
      cluster =>
        Math.abs(cluster.branch.latitude - marker.branch.latitude) <= radiusLat &&
        Math.abs(cluster.branch.longitude - marker.branch.longitude) <= radiusLng,
    );
    if (nearby) {
      nearby.members.push(marker.branch);
    } else {
      clusters.push({
        ...marker,
        id: markerId(marker),
        members: [marker.branch],
      });
    }
  });
  return clusters;
}

// What's actually put on the map: groups in view, nearest the centre first if
// there are more than the limit.
export function visibleClusters(
  clusters: MarkerCluster[],
  region: Region,
): MarkerCluster[] {
  const maxLat = (region.latitudeDelta * VISIBLE_SPAN_MULTIPLIER) / 2;
  const maxLng = (region.longitudeDelta * VISIBLE_SPAN_MULTIPLIER) / 2;
  const distance = ({branch}: MarkerCluster) =>
    Math.hypot(
      branch.latitude - region.latitude,
      branch.longitude - region.longitude,
    );
  return clusters
    .filter(
      ({branch}) =>
        Math.abs(branch.latitude - region.latitude) <= maxLat &&
        Math.abs(branch.longitude - region.longitude) <= maxLng,
    )
    .sort((a, b) => distance(a) - distance(b))
    .slice(0, MAX_VISIBLE_MARKERS);
}

// Frames every branch in a group, which is close enough to pull them apart.
export function regionForCluster(members: StoreBranch[]): Region {
  const latitudes = members.map(branch => branch.latitude);
  const longitudes = members.map(branch => branch.longitude);
  const minLat = Math.min(...latitudes);
  const maxLat = Math.max(...latitudes);
  const minLng = Math.min(...longitudes);
  const maxLng = Math.max(...longitudes);
  return {
    latitude: (minLat + maxLat) / 2,
    longitude: (minLng + maxLng) / 2,
    latitudeDelta: Math.max(
      (maxLat - minLat) * CLUSTER_ZOOM_PADDING,
      MIN_CLUSTER_ZOOM_DELTA,
    ),
    longitudeDelta: Math.max(
      (maxLng - minLng) * CLUSTER_ZOOM_PADDING,
      MIN_CLUSTER_ZOOM_DELTA,
    ),
  };
}
