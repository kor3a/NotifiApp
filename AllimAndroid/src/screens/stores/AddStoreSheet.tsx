import React, {useEffect, useRef, useState} from 'react';
import {
  View,
  Text,
  Modal,
  TextInput,
  StyleSheet,
  TouchableOpacity,
  FlatList,
  ActivityIndicator,
  useColorScheme,
  Alert,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import Icon from '@expo/vector-icons/Ionicons';
import LinearGradient from 'react-native-linear-gradient';

import {
  Colors,
  Spacing,
  Radius,
  textPrimary,
  textSecondary,
  cardBackground,
  cardBorder,
} from '../../theme/AppTheme';
import {locationService, Coordinates} from '../../services/locationService';
import {
  placesSearchService,
  SearchResultStore,
  distanceFormattedMiles,
} from '../../services/placesSearchService';
import {UserStoreItem} from '../../models';

interface Props {
  visible: boolean;
  onClose: () => void;
  onSelectStore: (storeName: string) => Promise<void> | void;
  existingStores: UserStoreItem[];
}

function normalizeStoreId(name: string): string {
  return name.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '');
}

export default function AddStoreSheet({
  visible,
  onClose,
  onSelectStore,
  existingStores,
}: Props) {
  const scheme = useColorScheme();

  const [query, setQuery] = useState('');
  const [results, setResults] = useState<SearchResultStore[]>([]);
  const [searching, setSearching] = useState(false);
  const [userLocation, setUserLocation] = useState<Coordinates | null>(null);
  const [locationError, setLocationError] = useState<string>('');
  const [permissionGranted, setPermissionGranted] = useState<boolean>(false);
  const [submittingId, setSubmittingId] = useState<string | null>(null);

  const searchTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Reset state each time the sheet opens, then try to get location.
  useEffect(() => {
    if (!visible) {return;}
    setQuery('');
    setResults([]);
    setSearching(false);
    setLocationError('');
    setSubmittingId(null);
    requestLocation();
  }, [visible]);

  async function requestLocation() {
    try {
      const granted = await locationService.requestPermission();
      setPermissionGranted(granted);
      if (!granted) {
        setLocationError('Location permission denied. Enable it in Settings.');
        return;
      }
      const coords = await locationService.getCurrentPosition();
      setUserLocation(coords);
      setLocationError('');
    } catch (err: any) {
      setLocationError(
        err?.message ?? 'Failed to get your location. Please try again.',
      );
    }
  }

  // Debounced search whenever query or userLocation changes.
  useEffect(() => {
    if (searchTimer.current) {clearTimeout(searchTimer.current);}
    if (!query.trim() || !userLocation) {
      setResults([]);
      setSearching(false);
      return;
    }
    setSearching(true);
    searchTimer.current = setTimeout(async () => {
      try {
        const items = await placesSearchService.searchNearby(
          query.trim(),
          userLocation,
        );
        setResults(items);
      } catch (err: any) {
        setResults([]);
        setLocationError(err?.message ?? 'Search failed.');
      } finally {
        setSearching(false);
      }
    }, 400);
    return () => {
      if (searchTimer.current) {clearTimeout(searchTimer.current);}
    };
  }, [query, userLocation]);

  function isAlreadyAdded(item: SearchResultStore): boolean {
    return existingStores.some(
      s => normalizeStoreId(s.store.name) === item.id,
    );
  }

  async function handleSelect(item: SearchResultStore) {
    if (isAlreadyAdded(item) || submittingId) {return;}
    setSubmittingId(item.id);
    try {
      await onSelectStore(item.name);
      onClose();
    } catch (err: any) {
      Alert.alert('Error', err?.message ?? 'Failed to add store.');
    } finally {
      setSubmittingId(null);
    }
  }

  function renderItem({item}: {item: SearchResultStore}) {
    const added = isAlreadyAdded(item);
    const submitting = submittingId === item.id;
    return (
      <TouchableOpacity
        style={[
          styles.resultRow,
          {borderBottomColor: cardBorder(scheme)},
          added && {opacity: 0.55},
        ]}
        onPress={() => handleSelect(item)}
        disabled={added || !!submittingId}
        activeOpacity={0.7}>
        <LinearGradient
          colors={[Colors.blue + '33', Colors.purple + '33']}
          style={styles.resultIcon}>
          <Icon name="storefront" size={20} color={Colors.blue} />
        </LinearGradient>
        <View style={styles.resultText}>
          <Text style={[styles.resultName, {color: textPrimary(scheme)}]}>
            {item.name}
          </Text>
          <Text
            style={[styles.resultMeta, {color: textSecondary(scheme)}]}>
            {item.locationCount === 1
              ? '1 location nearby'
              : `${item.locationCount} locations nearby`}
          </Text>
          <View style={styles.resultDistanceRow}>
            <Icon name="location" size={11} color={Colors.blue} />
            <Text style={[styles.resultDistance, {color: Colors.blue}]}>
              Nearest: {distanceFormattedMiles(item.nearestDistanceMeters)}
            </Text>
          </View>
        </View>
        {submitting ? (
          <ActivityIndicator color={Colors.blue} />
        ) : added ? (
          <Icon name="checkmark-circle" size={24} color={Colors.green} />
        ) : (
          <Icon name="add-circle-outline" size={24} color={Colors.blue} />
        )}
      </TouchableOpacity>
    );
  }

  function renderBody() {
    if (!permissionGranted || locationError) {
      return (
        <View style={styles.stateContainer}>
          <Icon
            name="location-outline"
            size={50}
            color={Colors.orange}
          />
          <Text style={[styles.stateTitle, {color: textPrimary(scheme)}]}>
            Location access required
          </Text>
          {!!locationError && (
            <Text
              style={[styles.stateSubtitle, {color: textSecondary(scheme)}]}>
              {locationError}
            </Text>
          )}
          <TouchableOpacity
            style={[styles.retryBtn, {backgroundColor: Colors.blue}]}
            onPress={requestLocation}>
            <Text style={styles.retryBtnText}>Enable Location</Text>
          </TouchableOpacity>
        </View>
      );
    }

    if (!userLocation) {
      return (
        <View style={styles.stateContainer}>
          <ActivityIndicator size="large" color={Colors.blue} />
          <Text style={[styles.stateSubtitle, {color: textSecondary(scheme)}]}>
            Getting your location…
          </Text>
        </View>
      );
    }

    if (searching) {
      return (
        <View style={styles.stateContainer}>
          <ActivityIndicator size="large" color={Colors.blue} />
          <Text style={[styles.stateSubtitle, {color: textSecondary(scheme)}]}>
            Searching nearby stores…
          </Text>
        </View>
      );
    }

    if (!query.trim()) {
      return (
        <View style={styles.stateContainer}>
          <Icon name="search" size={50} color={textSecondary(scheme)} />
          <Text style={[styles.stateTitle, {color: textPrimary(scheme)}]}>
            Search for nearby stores
          </Text>
          <Text style={[styles.stateSubtitle, {color: textSecondary(scheme)}]}>
            Type a store name to find locations near you.
          </Text>
        </View>
      );
    }

    if (results.length === 0) {
      return (
        <View style={styles.stateContainer}>
          <Icon name="storefront-outline" size={50} color={textSecondary(scheme)} />
          <Text style={[styles.stateTitle, {color: textPrimary(scheme)}]}>
            No stores found
          </Text>
          <Text style={[styles.stateSubtitle, {color: textSecondary(scheme)}]}>
            Try a different search term.
          </Text>
        </View>
      );
    }

    return (
      <FlatList
        data={results}
        renderItem={renderItem}
        keyExtractor={item => item.id}
        keyboardShouldPersistTaps="handled"
      />
    );
  }

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}>
      <SafeAreaView
        style={[
          styles.container,
          {backgroundColor: scheme === 'dark' ? Colors.backgroundTopDark : Colors.backgroundTopLight},
        ]}>
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity onPress={onClose}>
            <Text style={[styles.cancel, {color: Colors.blue}]}>Cancel</Text>
          </TouchableOpacity>
          <Text style={[styles.title, {color: textPrimary(scheme)}]}>
            Add Store
          </Text>
          <View style={{width: 60}} />
        </View>

        {/* Search box */}
        <View
          style={[
            styles.searchBox,
            {
              backgroundColor: cardBackground(scheme),
              borderColor: cardBorder(scheme),
            },
          ]}>
          <Icon name="search" size={18} color={textSecondary(scheme)} />
          <TextInput
            placeholder="Search for store name"
            placeholderTextColor={textSecondary(scheme)}
            value={query}
            onChangeText={setQuery}
            style={[styles.searchInput, {color: textPrimary(scheme)}]}
            autoFocus
            returnKeyType="search"
            autoCorrect={false}
            autoCapitalize="words"
          />
          {query.length > 0 && (
            <TouchableOpacity onPress={() => setQuery('')}>
              <Icon
                name="close-circle"
                size={18}
                color={textSecondary(scheme)}
              />
            </TouchableOpacity>
          )}
        </View>

        <View style={{flex: 1}}>{renderBody()}</View>
      </SafeAreaView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
  },
  cancel: {
    fontSize: 17,
    width: 60,
  },
  title: {
    fontSize: 17,
    fontWeight: '600',
  },
  searchBox: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    marginHorizontal: Spacing.md,
    marginBottom: Spacing.sm,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm + 2,
    borderRadius: Radius.md,
    borderWidth: 1,
  },
  searchInput: {
    flex: 1,
    fontSize: 16,
    padding: 0,
  },
  stateContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: Spacing.xl,
    gap: Spacing.md,
  },
  stateTitle: {
    fontSize: 18,
    fontWeight: '600',
  },
  stateSubtitle: {
    fontSize: 14,
    textAlign: 'center',
    lineHeight: 20,
  },
  retryBtn: {
    marginTop: Spacing.sm,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.sm + 4,
    borderRadius: Radius.md,
  },
  retryBtnText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '600',
  },
  resultRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  resultIcon: {
    width: 40,
    height: 40,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  resultText: {
    flex: 1,
  },
  resultName: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 2,
  },
  resultMeta: {
    fontSize: 12,
    marginBottom: 2,
  },
  resultDistanceRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  resultDistance: {
    fontSize: 12,
    fontWeight: '500',
  },
});
