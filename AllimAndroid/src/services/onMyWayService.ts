import firestore from '@react-native-firebase/firestore';
import auth from '@react-native-firebase/auth';
import {UserStoreItem} from '../models';
import {findSharedUsers} from './sharedStoreUsers';
import {locationService} from './locationService';
import {placesSearchService} from './placesSearchService';

// ─── "On My Way" ─────────────────────────────────────────────────────────────
//
// Mirrors the iOS OnMyWayNotificationService + TravelTimeService: work out how
// far the user is from the store, then write one `on_my_way_notifications`
// document per person sharing it. The `onMyWayNotification` Cloud Function
// turns each document into a push on the recipient's device.

export interface TravelEstimate {
  travelTimeMinutes: number;
  distanceMeters: number;
  storeName: string;
}

// Same wording as the iOS TravelEstimate.formattedTravelTime.
export function formattedTravelTime(minutes: number): string {
  if (minutes < 60) {
    return `${minutes} min`;
  }
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return rest === 0 ? `${hours} hr` : `${hours} hr ${rest} min`;
}

// iOS asks MapKit for a driving ETA. Android has no routing service wired up,
// so the drive is estimated from the distance to the nearest branch (found by
// the same `searchNearbyStores` Cloud Function the Add Store sheet uses):
// roads run roughly 1.4x the straight line, at an average ~40 km/h in town.
const ROAD_DETOUR_FACTOR = 1.4;
const AVERAGE_SPEED_METERS_PER_MINUTE = 40_000 / 60;

function normalizedName(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]/g, '');
}

async function estimateTravelTime(storeName: string): Promise<TravelEstimate> {
  const granted = await locationService.requestPermission();
  if (!granted) {
    throw new Error('Location permission is needed to work out travel time.');
  }
  const here = await locationService.getCurrentPosition();
  const results = await placesSearchService.searchNearby(storeName, here);
  if (results.length === 0) {
    throw new Error(`Couldn't find a nearby ${storeName}.`);
  }
  // Prefer the result that is actually this store over whatever else the
  // search matched; results arrive nearest first.
  const wanted = normalizedName(storeName);
  const match =
    results.find(r => normalizedName(r.name) === wanted) ?? results[0];
  const distanceMeters = match.nearestDistanceMeters;
  const travelTimeMinutes = Math.max(
    1,
    Math.ceil(
      (distanceMeters * ROAD_DETOUR_FACTOR) / AVERAGE_SPEED_METERS_PER_MINUTE,
    ),
  );
  return {travelTimeMinutes, distanceMeters, storeName};
}

export const onMyWayService = {
  estimateTravelTime,

  // Returns how many people were notified. Throws when there is nobody to
  // tell, so the screen can say so rather than claim it sent something.
  async sendNotification(params: {
    item: UserStoreItem;
    estimate: TravelEstimate;
    currentUserId: string;
    currentUserName: string;
  }): Promise<number> {
    const {item, estimate, currentUserId, currentUserName} = params;
    const recipients = await findSharedUsers(item, currentUserId);
    if (recipients.length === 0) {
      throw new Error(
        `Nobody else is on ${item.store.name} right now, so there was no one to notify.`,
      );
    }

    const batch = firestore().batch();
    const now = Date.now() / 1000;
    // Verified sender identity: the rules reject a senderEmail that isn't the
    // caller's, and the push function trusts it over senderName.
    const senderEmail = auth().currentUser?.email;

    recipients.forEach(user => {
      const ref = firestore().collection('on_my_way_notifications').doc();
      const payload: {[key: string]: any} = {
        recipientUserId: user.userId,
        recipientEmail: user.email,
        senderName: currentUserName,
        storeName: item.store.name,
        travelTimeMinutes: estimate.travelTimeMinutes,
        createdAt: now,
      };
      if (senderEmail) {
        payload.senderEmail = senderEmail;
      }
      batch.set(ref, payload);
    });

    await batch.commit();
    return recipients.length;
  },
};
