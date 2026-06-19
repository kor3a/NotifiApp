import React, {useEffect, useState, useRef, useCallback} from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  TextInput,
  useColorScheme,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import MapView, {Marker, PROVIDER_GOOGLE, Region} from 'react-native-maps';
import Icon from 'react-native-vector-icons/Ionicons';

import {
  Colors,
  Spacing,
  Radius,
  textPrimary,
  textSecondary,
  cardBackground,
} from '../../theme/AppTheme';
import {useSession} from '../../context/SessionContext';
import {locationService, Coordinates} from '../../services/locationService';
import {placesService, StoreLocation} from '../../services/placesService';
import {storeService} from '../../services/storeService';
import {UserStoreItem} from '../../models';

export default function MapScreen() {
  const scheme = useColorScheme();
  const {currentUser} = useSession();

  const mapRef = useRef<MapView>(null);
  const [stores, setStores] = useState<UserStoreItem[]>([]);
  const [storeLocations, setStoreLocations] = useState<StoreLocation[]>([]);
  const [currentLocation, setCurrentLocation] = useState<Coordinates | null>(null);
  const [region, setRegion] = useState<Region>({
    latitude: 37.7749,
    longitude: -122.4194,
    latitudeDelta: 0.05,
    longitudeDelta: 0.05,
  });
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedLocation, setSelectedLocation] = useState<StoreLocation | null>(
    null,
  );

  const lastSearchCenter = useRef<Coordinates | null>(null);
  const searchTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    requestLocationAndLoad();
    if (currentUser) {
      const unsub = storeService.subscribeToUserStores(
        currentUser.userId,
        currentUser.email,
        setStores,
      );
      return unsub;
    }
  }, [currentUser]);

  async function requestLocationAndLoad() {
    const granted = await locationService.requestPermission();
    if (!granted) {return;}
    try {
      const coords = await locationService.getCurrentPosition();
      setCurrentLocation(coords);
      setRegion({
        latitude: coords.latitude,
        longitude: coords.longitude,
        latitudeDelta: 0.05,
        longitudeDelta: 0.05,
      });
    } catch (err) {
      console.warn('Could not get location:', err);
    }
  }

  // Resolve nearby branches of each saved store via Places, biased to `center`.
  const runStoreSearch = useCallback(
    async (center: Coordinates, items: UserStoreItem[]) => {
      // De-duplicate by store name so a chain is only searched once.
      const seen = new Set<string>();
      const unique = items.filter(s => {
        const key = s.store.name.toLowerCase();
        if (seen.has(key)) {return false;}
        seen.add(key);
        return true;
      });

      const results = await Promise.all(
        unique.map(s =>
          placesService.searchStoreLocations(s.store.name, center, {
            userStoreId: s.id,
            storeId: s.store.id,
          }),
        ),
      );
      setStoreLocations(results.flat());
    },
    [],
  );

  // Search when stores change or the map is panned far enough (debounced).
  useEffect(() => {
    if (stores.length === 0) {
      setStoreLocations([]);
      return;
    }
    if (searchTimer.current) {clearTimeout(searchTimer.current);}
    searchTimer.current = setTimeout(() => {
      const center = {latitude: region.latitude, longitude: region.longitude};
      const last = lastSearchCenter.current;
      const movedFar =
        !last || locationService.distanceBetween(last, center) > 2000;
      if (!movedFar) {return;}
      lastSearchCenter.current = center;
      runStoreSearch(center, stores);
    }, 700);
    return () => {
      if (searchTimer.current) {clearTimeout(searchTimer.current);}
    };
  }, [stores, region, runStoreSearch]);

  function centerOnUser() {
    if (currentLocation) {
      mapRef.current?.animateToRegion({
        ...currentLocation,
        latitudeDelta: 0.02,
        longitudeDelta: 0.02,
      });
    }
  }

  const visibleLocations = searchQuery.trim()
    ? storeLocations.filter(l =>
        l.storeName.toLowerCase().includes(searchQuery.trim().toLowerCase()),
      )
    : storeLocations;

  // Dark map style for Android
  const darkMapStyle = [
    {elementType: 'geometry', stylers: [{color: '#242f3e'}]},
    {elementType: 'labels.text.stroke', stylers: [{color: '#242f3e'}]},
    {elementType: 'labels.text.fill', stylers: [{color: '#746855'}]},
    {featureType: 'road', elementType: 'geometry', stylers: [{color: '#38414e'}]},
    {
      featureType: 'road',
      elementType: 'geometry.stroke',
      stylers: [{color: '#212a37'}],
    },
    {featureType: 'water', elementType: 'geometry', stylers: [{color: '#17263c'}]},
  ];

  return (
    <View style={{flex: 1}}>
      <MapView
        ref={mapRef}
        style={StyleSheet.absoluteFill}
        provider={PROVIDER_GOOGLE}
        region={region}
        onRegionChangeComplete={setRegion}
        customMapStyle={scheme === 'dark' ? darkMapStyle : []}
        showsUserLocation
        showsMyLocationButton={false}>
        {visibleLocations.map(loc => (
          <Marker
            key={loc.id}
            coordinate={loc.coordinate}
            title={loc.name}
            description={loc.address}
            onPress={() => setSelectedLocation(loc)}
            pinColor={Colors.blue}
          />
        ))}
      </MapView>

      <SafeAreaView style={{flex: 1}} pointerEvents="box-none">
        {/* Search bar */}
        <View style={[styles.searchBar, {backgroundColor: cardBackground(scheme)}]}>
          <Icon name="search" size={18} color={textSecondary(scheme)} />
          <TextInput
            placeholder="Search stores..."
            placeholderTextColor={textSecondary(scheme)}
            value={searchQuery}
            onChangeText={setSearchQuery}
            style={[styles.searchInput, {color: textPrimary(scheme)}]}
          />
        </View>

        {/* Location button */}
        <TouchableOpacity
          style={[styles.locationBtn, {backgroundColor: cardBackground(scheme)}]}
          onPress={centerOnUser}>
          <Icon name="locate" size={22} color={Colors.blue} />
        </TouchableOpacity>

        {/* Selected location info card */}
        {selectedLocation && (
          <View style={styles.storeCard}>
            <View
              style={[
                styles.storeCardInner,
                {backgroundColor: cardBackground(scheme)},
              ]}>
              <View style={styles.storeCardRow}>
                <Icon name="cart" size={20} color={Colors.blue} />
                <View style={{marginLeft: Spacing.md, flex: 1}}>
                  <Text style={[styles.storeCardName, {color: textPrimary(scheme)}]}>
                    {selectedLocation.name}
                  </Text>
                  {!!selectedLocation.address && (
                    <Text
                      style={[styles.storeCardSub, {color: textSecondary(scheme)}]}
                      numberOfLines={2}>
                      {selectedLocation.address}
                    </Text>
                  )}
                </View>
                <TouchableOpacity onPress={() => setSelectedLocation(null)}>
                  <Icon name="close" size={20} color={textSecondary(scheme)} />
                </TouchableOpacity>
              </View>
            </View>
          </View>
        )}
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  searchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    margin: Spacing.md,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: Radius.lg,
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 2},
    shadowOpacity: 0.15,
    shadowRadius: 4,
    elevation: 4,
  },
  searchInput: {
    flex: 1,
    fontSize: 16,
    marginLeft: Spacing.sm,
    paddingVertical: Spacing.xs,
  },
  locationBtn: {
    position: 'absolute',
    right: Spacing.md,
    top: 80,
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 2},
    shadowOpacity: 0.15,
    shadowRadius: 4,
    elevation: 4,
  },
  storeCard: {
    position: 'absolute',
    bottom: Spacing.lg,
    left: Spacing.md,
    right: Spacing.md,
  },
  storeCardInner: {
    borderRadius: Radius.lg,
    padding: Spacing.md,
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 4},
    shadowOpacity: 0.2,
    shadowRadius: 8,
    elevation: 6,
  },
  storeCardRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  storeCardName: {
    fontSize: 17,
    fontWeight: '600',
  },
  storeCardSub: {
    fontSize: 13,
    marginTop: 2,
  },
});
