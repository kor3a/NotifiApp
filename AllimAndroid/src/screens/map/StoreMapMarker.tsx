import React, {useCallback, useEffect, useRef} from 'react';
import {StyleSheet, Text, View} from 'react-native';
import {MapMarker, Marker} from 'react-native-maps';
import Icon from '../../components/AppIcon';
import StoreLogo from '../../components/StoreLogo';
import {UserStoreItem} from '../../models';
import {StoreBranch} from '../../services/storeLocationService';
import {Colors} from '../../theme/AppTheme';

const LOGO_SIZE = 30;
const RING_WIDTH = 2;
// Layout, logo load and badge changes tend to land together, and Android needs a
// moment to paint a loaded image, so they share one redraw just after the last.
const REDRAW_DELAY_MS = 100;

// The store's logo in a white ring with its reminder count — the iOS
// StoreIconView — or, standing for several nearby stores, a filled shop icon with
// how many there are.
//
// Android draws a marker from a bitmap of this view. `tracksViewChanges` would
// redo that bitmap 25 times a second per marker, which overwhelms the app with
// many on screen, so it's off and the bitmap is redone only when something here
// changes. This deliberately holds no React state: with dozens of logos loading
// at once, a state update for each exceeds React's limit on nested updates.
function StoreMapMarker({
  id,
  item,
  branch,
  groupSize,
  onPress,
}: {
  id: string;
  item: UserStoreItem;
  branch: StoreBranch;
  groupSize: number;
  onPress: (id: string) => void;
}) {
  const {name: storeName, reminderCount} = item.store;
  const marker = useRef<MapMarker>(null);
  const redrawTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const redraw = useCallback(() => {
    if (redrawTimer.current) {
      clearTimeout(redrawTimer.current);
    }
    redrawTimer.current = setTimeout(() => {
      redrawTimer.current = null;
      marker.current?.redraw();
    }, REDRAW_DELAY_MS);
  }, []);

  useEffect(() => {
    redraw();
  }, [redraw, reminderCount, groupSize]);

  useEffect(
    () => () => {
      if (redrawTimer.current) {
        clearTimeout(redrawTimer.current);
      }
    },
    [],
  );

  return (
    <Marker
      ref={marker}
      coordinate={{latitude: branch.latitude, longitude: branch.longitude}}
      anchor={{x: 0.5, y: 0.5}}
      tracksViewChanges={false}
      onPress={() => onPress(id)}>
      <View style={styles.container} collapsable={false} onLayout={redraw}>
        {groupSize > 1 ? (
          <>
            <View style={[styles.ring, styles.groupRing]}>
              <Icon name="storefront" size={18} color={Colors.white} />
            </View>
            <View style={[styles.badge, styles.groupBadge]}>
              <Text style={styles.badgeText}>{groupSize}</Text>
            </View>
          </>
        ) : (
          <>
            <View style={styles.ring}>
              <StoreLogo
                storeName={storeName}
                size={LOGO_SIZE}
                onDisplayChange={redraw}
              />
            </View>
            {reminderCount > 0 && (
              <View style={styles.badge}>
                <Text style={styles.badgeText}>{reminderCount}</Text>
              </View>
            )}
          </>
        )}
      </View>
    </Marker>
  );
}

export default React.memo(StoreMapMarker);

const styles = StyleSheet.create({
  // Square and centred on the ring, so the anchor lands on the logo's middle,
  // with enough margin that the badge isn't cut off by the bitmap.
  container: {
    width: 56,
    height: 56,
    alignItems: 'center',
    justifyContent: 'center',
  },
  ring: {
    width: LOGO_SIZE + RING_WIDTH * 2,
    height: LOGO_SIZE + RING_WIDTH * 2,
    borderRadius: (LOGO_SIZE + RING_WIDTH * 2) / 2,
    backgroundColor: Colors.white,
    alignItems: 'center',
    justifyContent: 'center',
  },
  badge: {
    position: 'absolute',
    top: 4,
    right: 4,
    minWidth: 18,
    height: 18,
    borderRadius: 9,
    paddingHorizontal: 4,
    backgroundColor: Colors.blue,
    borderWidth: 1.5,
    borderColor: Colors.white,
    alignItems: 'center',
    justifyContent: 'center',
  },
  groupRing: {
    backgroundColor: Colors.blue,
    borderWidth: RING_WIDTH,
    borderColor: Colors.white,
  },
  // Dark against the blue icon, and so it doesn't read as a reminder count.
  groupBadge: {
    backgroundColor: '#3A3A3C',
  },
  badgeText: {
    color: Colors.white,
    fontSize: 10,
    fontWeight: '700',
  },
});
