import React from 'react';
import {
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  useColorScheme,
} from 'react-native';
import Icon from '../../components/AppIcon';
import StoreLogo from '../../components/StoreLogo';
import {UserStoreItem} from '../../models';
import {
  Colors,
  Radius,
  Spacing,
  cardBackground,
  textPrimary,
  textSecondary,
} from '../../theme/AppTheme';
import {ClusterStore} from './markerClusters';

const BOX_WIDTH = 240;
const ROW_HEIGHT = 48;
// Past this many rows the list scrolls instead of growing.
const MAX_VISIBLE_ROWS = 4;
const ARROW_SIZE = 8;
// From the marker's centre to the edge of its ring, plus a little air.
const MARKER_CLEARANCE = 22;
const EDGE_MARGIN = Spacing.md;
// Below this the box would run under the search bar, so it opens downwards.
const MIN_SPACE_ABOVE = 140 + ROW_HEIGHT * MAX_VISIBLE_ROWS;

// A small box pointing at a group marker, listing the stores it stands for, so
// stores right next to each other can still be told apart and picked.
export default function ClusterStoresPopup({
  stores,
  anchor,
  containerWidth,
  containerHeight,
  onSelect,
  onZoomIn,
}: {
  stores: ClusterStore[];
  // The marker's centre, in the map's own coordinates.
  anchor: {x: number; y: number};
  containerWidth: number;
  containerHeight: number;
  onSelect: (item: UserStoreItem) => void;
  // Left out when the map is already as close as a group zooms.
  onZoomIn?: () => void;
}) {
  const scheme = useColorScheme();
  const background = cardBackground(scheme);
  const below = anchor.y < MIN_SPACE_ABOVE;

  const left = Math.min(
    Math.max(anchor.x - BOX_WIDTH / 2, EDGE_MARGIN),
    containerWidth - BOX_WIDTH - EDGE_MARGIN,
  );
  const arrowLeft = Math.min(
    Math.max(anchor.x - left - ARROW_SIZE, Radius.md),
    BOX_WIDTH - Radius.md - ARROW_SIZE * 2,
  );
  const vertical = below
    ? {top: anchor.y + MARKER_CLEARANCE}
    : {bottom: containerHeight - anchor.y + MARKER_CLEARANCE};

  const arrow = (
    <View
      style={[
        styles.arrow,
        {marginLeft: arrowLeft, backgroundColor: background},
        below ? styles.arrowUp : styles.arrowDown,
      ]}
    />
  );

  return (
    <View style={[styles.container, {left}, vertical]}>
      {below && arrow}
      <View style={[styles.box, {backgroundColor: background}]}>
        <View style={styles.header}>
          <Text style={[styles.headerText, {color: textSecondary(scheme)}]}>
            {stores.length} {stores.length === 1 ? 'store' : 'stores'} here
          </Text>
          {onZoomIn && (
            <TouchableOpacity
              onPress={onZoomIn}
              hitSlop={8}
              accessibilityLabel="Zoom in">
              <Icon name="expand" size={16} color={Colors.blue} />
            </TouchableOpacity>
          )}
        </View>
        <ScrollView
          style={{maxHeight: ROW_HEIGHT * MAX_VISIBLE_ROWS}}
          bounces={false}>
          {stores.map(({item, branchCount}) => {
            const {name, reminderCount} = item.store;
            const details = [
              `${reminderCount} reminder${reminderCount !== 1 ? 's' : ''}`,
              branchCount > 1 ? `${branchCount} locations` : null,
            ]
              .filter(Boolean)
              .join(' · ');
            return (
              <TouchableOpacity
                key={item.id}
                style={styles.row}
                onPress={() => onSelect(item)}>
                <StoreLogo storeName={name} size={28} />
                <View style={styles.rowText}>
                  <Text
                    numberOfLines={1}
                    style={[styles.name, {color: textPrimary(scheme)}]}>
                    {name}
                  </Text>
                  <Text
                    numberOfLines={1}
                    style={[styles.details, {color: textSecondary(scheme)}]}>
                    {details}
                  </Text>
                </View>
                <Icon
                  name="chevron-forward"
                  size={16}
                  color={textSecondary(scheme)}
                />
              </TouchableOpacity>
            );
          })}
        </ScrollView>
      </View>
      {!below && arrow}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    width: BOX_WIDTH,
  },
  box: {
    borderRadius: Radius.md,
    paddingVertical: Spacing.xs,
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 4},
    shadowOpacity: 0.2,
    shadowRadius: 8,
    elevation: 8,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.md,
    paddingTop: Spacing.xs,
    paddingBottom: 2,
  },
  headerText: {
    fontSize: 12,
    fontWeight: '600',
  },
  row: {
    height: ROW_HEIGHT,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.md,
  },
  rowText: {
    flex: 1,
    marginLeft: Spacing.sm,
  },
  name: {
    fontSize: 15,
    fontWeight: '600',
  },
  details: {
    fontSize: 12,
    marginTop: 1,
  },
  // A rotated square, half of it tucked behind the box (one step lower, so the
  // box covers it), reads as a pointer.
  arrow: {
    width: ARROW_SIZE * 2,
    height: ARROW_SIZE * 2,
    transform: [{rotate: '45deg'}],
    elevation: 7,
  },
  arrowDown: {
    marginTop: -ARROW_SIZE,
  },
  arrowUp: {
    marginBottom: -ARROW_SIZE,
  },
});
