import {PermissionsAndroid, Platform} from 'react-native';
import Geolocation from 'react-native-geolocation-service';

export interface Coordinates {
  latitude: number;
  longitude: number;
}

export const locationService = {
  async requestPermission(): Promise<boolean> {
    if (Platform.OS !== 'android') {return true;}
    const fine = await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
      {
        title: 'Location Permission',
        message: 'Allim needs location access to notify you near stores.',
        buttonNeutral: 'Ask Me Later',
        buttonNegative: 'Cancel',
        buttonPositive: 'OK',
      },
    );
    return fine === PermissionsAndroid.RESULTS.GRANTED;
  },

  async requestBackgroundPermission(): Promise<boolean> {
    if (Platform.OS !== 'android') {return true;}
    const bg = await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.ACCESS_BACKGROUND_LOCATION,
      {
        title: 'Background Location Permission',
        message:
          'Allim needs background location to notify you when you arrive near a store.',
        buttonNeutral: 'Ask Me Later',
        buttonNegative: 'Cancel',
        buttonPositive: 'OK',
      },
    );
    return bg === PermissionsAndroid.RESULTS.GRANTED;
  },

  getCurrentPosition(): Promise<Coordinates> {
    return new Promise((resolve, reject) => {
      Geolocation.getCurrentPosition(
        pos => resolve(pos.coords),
        err => reject(err),
        {enableHighAccuracy: true, timeout: 15000, maximumAge: 10000},
      );
    });
  },

  watchPosition(callback: (coords: Coordinates) => void): number {
    return Geolocation.watchPosition(
      pos => callback(pos.coords),
      err => console.warn('Location error:', err),
      {enableHighAccuracy: true, interval: 5000, fastestInterval: 3000},
    );
  },

  clearWatch(watchId: number): void {
    Geolocation.clearWatch(watchId);
  },

  // Haversine distance in meters
  distanceBetween(a: Coordinates, b: Coordinates): number {
    const R = 6371e3;
    const φ1 = (a.latitude * Math.PI) / 180;
    const φ2 = (b.latitude * Math.PI) / 180;
    const Δφ = ((b.latitude - a.latitude) * Math.PI) / 180;
    const Δλ = ((b.longitude - a.longitude) * Math.PI) / 180;
    const x =
      Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
      Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    return R * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
  },
};
