import React, {useEffect, useState, useRef} from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  TextInput,
  useColorScheme,
  ActivityIndicator,
  Alert,
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
import {storeService} from '../../services/storeService';
import {UserStoreItem} from '../../models';

export default function MapScreen() {
  const scheme = useColorScheme();
  const {currentUser, firebaseUser} = useSession();

  const mapRef = useRef<MapView>(null);
  const [stores, setStores] = useState<UserStoreItem[]>([]);
  const [currentLocation, setCurrentLocation] = useState<Coordinates | null>(null);
  const [loading, setLoading] = useState(true);
  const [region, setRegion] = useState<Region>({
    latitude: 37.7749,
    longitude: -122.4194,
    latitudeDelta: 0.05,
    longitudeDelta: 0.05,
  });
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedStore, setSelectedStore] = useState<UserStoreItem | null>(null);

  useEffect(() => {
    requestLocationAndLoad();
    // Load user stores for map markers
    if (firebaseUser && currentUser) {
      const unsub = storeService.subscribeToUserStores(
        firebaseUser.uid,
        currentUser.email,
        items => {
          setStores(items);
          setLoading(false);
        },
      );
      return unsub;
    }
  }, [firebaseUser, currentUser]);

  async function requestLocationAndLoad() {
    const granted = await locationService.requestPermission();
    if (!granted) {
      setLoading(false);
      return;
    }
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
    } finally {
      setLoading(false);
    }
  }

  function centerOnUser() {
    if (currentLocation) {
      mapRef.current?.animateToRegion({
        ...currentLocation,
        latitudeDelta: 0.02,
        longitudeDelta: 0.02,
      });
    }
  }

  // Dark map style for Android
  const darkMapStyle = [
    {elementType: 'geometry', stylers: [{color: '#242f3e'}]},
    {elementType: 'labels.text.stroke', stylers: [{color: '#242f3e'}]},
    {elementType: 'labels.text.fill', stylers: [{color: '#746855'}]},
    {
      featureType: 'road',
      elementType: 'geometry',
      stylers: [{color: '#38414e'}],
    },
    {
      featureType: 'road',
      elementType: 'geometry.stroke',
      stylers: [{color: '#212a37'}],
    },
    {
      featureType: 'water',
      elementType: 'geometry',
      stylers: [{color: '#17263c'}],
    },
  ];

  return (
    <View style={{flex: 1}}>
      {/* Map takes full screen */}
      <MapView
        ref={mapRef}
        style={StyleSheet.absoluteFill}
        provider={PROVIDER_GOOGLE}
        region={region}
        onRegionChangeComplete={setRegion}
        customMapStyle={scheme === 'dark' ? darkMapStyle : []}
        showsUserLocation
        showsMyLocationButton={false}>

        {/* Store markers */}
        {stores.map(store => (
          <Marker
            key={store.id}
            coordinate={{
              // Placeholder coords — real app would geocode store addresses
              latitude: region.latitude + (Math.random() - 0.5) * 0.02,
              longitude: region.longitude + (Math.random() - 0.5) * 0.02,
            }}
            onPress={() => setSelectedStore(store)}
            pinColor={Colors.blue}>
          </Marker>
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

        {/* Selected store info card */}
        {selectedStore && (
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
                    {selectedStore.store.name}
                  </Text>
                  <Text style={[styles.storeCardSub, {color: textSecondary(scheme)}]}>
                    {selectedStore.store.reminderCount} reminder
                    {selectedStore.store.reminderCount !== 1 ? 's' : ''}
                  </Text>
                </View>
                <TouchableOpacity onPress={() => setSelectedStore(null)}>
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
