import {requireOptionalNativeModule} from 'expo-modules-core';

/**
 * Native geofencing for store-proximity notifications (android/src/main/java).
 * Optional so Jest and any build without the native module simply skip it.
 */

export type GeofenceStatus =
  | 'registered'
  | 'noStores'
  | 'needsFineLocation'
  | 'needsBackgroundLocation'
  | 'error';

export interface GeofenceStoreEntry {
  key: string; // normalized store name
  name: string; // shown in the notification
  reminderStoreIds: string[]; // every list behind the name
  cachedCount: number; // ranking, and the fallback when the live count fails
}

export interface GeofenceCandidateEntry {
  key: string;
  latitude: number;
  longitude: number;
}

export interface GeofencePool {
  stores: GeofenceStoreEntry[];
  candidates: GeofenceCandidateEntry[];
  reference: {latitude: number; longitude: number};
}

interface NativeModule {
  setPool(poolJson: string): Promise<GeofenceStatus>;
  clear(): Promise<void>;
  permissionProblem(): GeofenceStatus | null;
}

const native = requireOptionalNativeModule<NativeModule>('AllimGeofence');

export const allimGeofence = {
  isAvailable: native != null,

  async setPool(pool: GeofencePool): Promise<GeofenceStatus> {
    if (!native) {
      return 'error';
    }
    return native.setPool(JSON.stringify(pool));
  },

  async clear(): Promise<void> {
    await native?.clear();
  },

  permissionProblem(): GeofenceStatus | null {
    return native ? native.permissionProblem() : null;
  },
};
