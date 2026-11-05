import React, {useCallback, useEffect, useMemo, useState, useRef} from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  TextInput,
  useColorScheme,
  ActivityIndicator,
  Alert,
  useWindowDimensions,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import MapView, {PROVIDER_GOOGLE, Region} from 'react-native-maps';
import Icon from '../../components/AppIcon';
import StoreMapMarker from './StoreMapMarker';
import {
  BranchMarker,
  clusterMarkers,
  MIN_CLUSTER_ZOOM_DELTA,
  regionForCluster,
  visibleClusters,
} from './markerClusters';
import {useTutorialTarget} from '../../tutorial/tutorialManager';

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
import {
  searchTile,
  StoreBranch,
  storeLocationService,
} from '../../services/storeLocationService';
import {UserStoreItem} from '../../models';

// Same pause as iOS: wait for a pan or pinch to settle before searching.
const BRANCH_SEARCH_DEBOUNCE_MS = 600;
// Past about 35 miles across, one search from the map's centre can't represent
// the view, and panning would spend a paid lookup per store on every new area.
// Zoomed out that far, the map shows what it has already found.
const MAX_SEARCH_LATITUDE_SPAN = 0.5;
const PLACEHOLDER_REGION: Region = {
  latitude: 37.7749,
  longitude: -122.4194,
  latitudeDelta: 0.05,
  longitudeDelta: 0.05,
};

export default function MapScreen() {
  const scheme = useColorScheme();
  const {width: screenWidth} = useWindowDimensions();
  const {currentUser, firebaseUser} = useSession();

  const mapRef = useRef<MapView>(null);
  const [stores, setStores] = useState<UserStoreItem[]>([]);
  const [currentLocation, setCurrentLocation] = useState<Coordinates | null>(null);
  const [loading, setLoading] = useState(true);
  const [mapReady, setMapReady] = useState(false);
  // The map opens on a placeholder city. Branch lookups are paid, so they wait
  // until it shows somewhere real: the user's location, or wherever they pan to
  // if that isn't available.
  const [searchEnabled, setSearchEnabled] = useState(false);
  const hasCentered = useRef(false);
  const [branchesByStore, setBranchesByStore] = useState<
    Record<string, StoreBranch[]>
  >({});
  const [region, setRegion] = useState<Region>(PLACEHOLDER_REGION);
  const [searchQuery, setSearchQuery] = useState('');
  const searchTarget = useTutorialTarget('tutorial_mapSearch');
  const [selectedStore, setSelectedStore] = useState<UserStoreItem | null>(null);

  useEffect(() => {
    requestLocationAndLoad();
    // Load user stores for map markers
    if (currentUser) {
      const unsub = storeService.subscribeToUserStores(
        currentUser.userId,
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
      setCurrentLocation(await locationService.getCurrentPosition());
    } catch (err) {
      console.warn('Could not get location:', err);
    } finally {
      setLoading(false);
    }
  }

  // Moves to the user once, when both the map and their location are in, in
  // whichever order those arrive. A camera move made before the map is ready
  // is dropped.
  useEffect(() => {
    if (!mapReady || !currentLocation || hasCentered.current) {
      return;
    }
    hasCentered.current = true;
    const target = {
      latitude: currentLocation.latitude,
      longitude: currentLocation.longitude,
      latitudeDelta: 0.05,
      longitudeDelta: 0.05,
    };
    setRegion(target);
    setSearchEnabled(true);
    mapRef.current?.animateToRegion(target, 0);
  }, [mapReady, currentLocation]);

  // The map reports settling on the placeholder as it opens, sometimes after the
  // location is already in. Only a real move counts until it has been centred.
  function handleRegionChangeComplete(
    next: Region,
    details?: {isGesture?: boolean},
  ) {
    if (details?.isGesture) {
      setSearchEnabled(true);
    } else if (!hasCentered.current) {
      return;
    }
    setRegion(next);
  }

  // Stores carry no coordinates, so each one's branches are looked up around the
  // map. Keyed on the search tile, not the region: moving within a tile can't
  // find anything new, and every lookup costs a paid Places request.
  const storeNames = stores.map(item => item.store.name).join('\n');
  const {latitude: tileLat, longitude: tileLng} = searchTile(region);
  const zoomedTooFarToSearch = region.latitudeDelta > MAX_SEARCH_LATITUDE_SPAN;
  useEffect(() => {
    if (!searchEnabled || !storeNames || zoomedTooFarToSearch) {
      return;
    }
    const timer = setTimeout(() => {
      storeNames.split('\n').forEach(name => {
        storeLocationService
          .nearbyBranches(name, {latitude: tileLat, longitude: tileLng})
          .then(found => {
            setBranchesByStore(previous => {
              const known = previous[name] ?? [];
              const merged = new Map(known.map(b => [b.id, b]));
              found.forEach(branch => merged.set(branch.id, branch));
              return merged.size === known.length
                ? previous
                : {...previous, [name]: [...merged.values()]};
            });
          })
          .catch(err => console.warn(`Could not find ${name}:`, err));
      });
    }, BRANCH_SEARCH_DEBOUNCE_MS);
    return () => clearTimeout(timer);
  }, [searchEnabled, storeNames, tileLat, tileLng, zoomedTooFarToSearch]);

  const clusters = useMemo(() => {
    const markers: BranchMarker[] = stores.flatMap(item =>
      (branchesByStore[item.store.name] ?? []).map(branch => ({item, branch})),
    );
    return visibleClusters(
      clusterMarkers(markers, region, screenWidth),
      region,
    );
  }, [stores, branchesByStore, region, screenWidth]);

  // Read through a ref so the handler stays the same function and an unchanged
  // marker doesn't re-render every time the map settles.
  const pressContext = useRef({clusters, region});
  pressContext.current = {clusters, region};
  const handleMarkerPress = useCallback((id: string) => {
    const {clusters: current, region: now} = pressContext.current;
    const cluster = current.find(c => c.id === id);
    if (!cluster) {
      return;
    }
    // A group opens up on zooming in, unless it's as close as zooming goes.
    if (cluster.members.length > 1 && now.latitudeDelta > MIN_CLUSTER_ZOOM_DELTA) {
      mapRef.current?.animateToRegion(regionForCluster(cluster.members));
    } else {
      setSelectedStore(cluster.item);
    }
  }, []);

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
        initialRegion={PLACEHOLDER_REGION}
        onMapReady={() => setMapReady(true)}
        onRegionChangeComplete={handleRegionChangeComplete}
        customMapStyle={scheme === 'dark' ? darkMapStyle : []}
        showsUserLocation
        showsMyLocationButton={false}>

        {/* Each nearby branch of the user's stores */}
        {clusters.map(cluster => (
          <StoreMapMarker
            key={cluster.id}
            id={cluster.id}
            item={cluster.item}
            branch={cluster.branch}
            groupSize={cluster.members.length}
            onPress={handleMarkerPress}
          />
        ))}
      </MapView>

      <SafeAreaView
        style={{flex: 1}}
        edges={['top', 'left', 'right']}
        pointerEvents="box-none">
        {/* Search bar */}
        <View
          {...searchTarget}
          style={[styles.searchBar, {backgroundColor: cardBackground(scheme)}]}>
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
