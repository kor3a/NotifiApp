import React, {useEffect, useMemo, useRef, useState} from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  Animated,
  Easing,
  PanResponder,
  LayoutChangeEvent,
} from 'react-native';
import Icon from '../../components/AppIcon';
import StoreLogo from '../../components/StoreLogo';
import {Colors} from '../../theme/AppTheme';
import {UserStoreItem} from '../../models';

// The "float" (grid) layout of the store list, ported from the iOS
// StoreFloatView: store logos in a honeycomb centred on the screen. Tap opens
// a store; a long press starts edit mode, where the icons wiggle, each carries
// a delete badge, and dragging one over another swaps them.

const CIRCLE_SIZE = 58;
const H_SPACING = 14;
const V_SPACING = 10;
const SIDE_PADDING = 24;

interface Point {
  x: number;
  y: number;
}

interface Props {
  stores: UserStoreItem[];
  onStoreTap: (item: UserStoreItem) => void;
  onStoreDelete: (item: UserStoreItem) => void;
  onReorder: (newOrder: UserStoreItem[]) => void;
  isEditMode: boolean;
  setEditMode: (editing: boolean) => void;
  // Room to leave clear at the bottom for the FAB.
  bottomInset?: number;
}

// Alternating-row honeycomb, centred vertically, rows stacked bottom-to-top:
// even rows hold `iconsPerRow` icons, odd rows one fewer, each sitting between
// the pair below it. A straight port of the iOS layoutPositions.
function layoutPositions(width: number, height: number, count: number): Point[] {
  if (count === 0 || width === 0) {
    return [];
  }
  const xStep = CIRCLE_SIZE + H_SPACING;
  const yStep = CIRCLE_SIZE + V_SPACING;
  const available = width - 2 * SIDE_PADDING;
  const iconsPerRow = Math.max(2, Math.floor((available + H_SPACING) / xStep));
  const fullSpan = (iconsPerRow - 1) * xStep;
  const rowCenterX = width / 2;

  const rows: number[][] = [];
  let placed = 0;
  let rowIdx = 0;
  while (placed < count) {
    const isWide = rowIdx % 2 === 0;
    const capacity = isWide ? iconsPerRow : iconsPerRow - 1;
    const n = Math.min(capacity, count - placed);
    const slotSpan = (capacity - 1) * xStep;
    const actualSpan = (n - 1) * xStep;
    const centreAdj = (slotSpan - actualSpan) / 2;
    const baseX = isWide
      ? rowCenterX - fullSpan / 2 + centreAdj
      : rowCenterX - fullSpan / 2 + xStep / 2 + centreAdj;
    rows.push(Array.from({length: n}, (_, i) => baseX + i * xStep));
    placed += n;
    rowIdx += 1;
  }

  const totalRows = rows.length;
  const totalHeight = (totalRows - 1) * yStep + CIRCLE_SIZE;
  const topY = (height - totalHeight) / 2 + CIRCLE_SIZE / 2;

  const positions: Point[] = [];
  rows.forEach((xs, ri) => {
    const y = topY + (totalRows - 1 - ri) * yStep;
    xs.forEach(x => positions.push({x, y}));
  });
  return positions;
}

function topLeft(p: Point): Point {
  return {x: p.x - CIRCLE_SIZE / 2, y: p.y - CIRCLE_SIZE / 2};
}

export default function StoreFloatView({
  stores,
  onStoreTap,
  onStoreDelete,
  onReorder,
  isEditMode,
  setEditMode,
  bottomInset = 0,
}: Props) {
  const [size, setSize] = useState({width: 0, height: 0});
  const [localStores, setLocalStores] = useState(stores);
  const [draggingId, setDraggingId] = useState<string | null>(null);

  const positionsById = useRef(new Map<string, Animated.ValueXY>()).current;
  const opacity = useRef(new Animated.Value(0)).current;
  const wiggle = useRef(new Animated.Value(0)).current;
  const appeared = useRef(false);

  // Latest values for the pan handlers, which are created once per icon.
  const state = useRef({
    localStores,
    positions: [] as Point[],
    isEditMode,
    draggingId: null as string | null,
    dragStart: {x: 0, y: 0},
    swapped: false,
  }).current;

  const height = Math.max(0, size.height - bottomInset);
  const positions = useMemo(
    () => layoutPositions(size.width, height, localStores.length),
    [size.width, height, localStores.length],
  );
  state.localStores = localStores;
  state.positions = positions;
  state.isEditMode = isEditMode;

  // Follow the parent's list, except mid-drag, when the local order is the
  // one on screen.
  useEffect(() => {
    if (!state.draggingId) {
      setLocalStores(stores);
    }
  }, [stores, state]);

  function valueFor(id: string): Animated.ValueXY {
    let v = positionsById.get(id);
    if (!v) {
      const center = topLeft({x: size.width / 2, y: height / 2});
      v = new Animated.ValueXY(center);
      positionsById.set(id, v);
    }
    return v;
  }

  // Move every icon to its slot. The first time the grid has a size, the icons
  // burst out of the centre one after another, as they do on iOS.
  useEffect(() => {
    if (positions.length === 0) {
      return;
    }
    const first = !appeared.current;
    appeared.current = true;
    if (first) {
      Animated.timing(opacity, {
        toValue: 1,
        duration: 250,
        useNativeDriver: true,
      }).start();
    }
    localStores.forEach((item, index) => {
      if (item.id === state.draggingId || index >= positions.length) {
        return;
      }
      Animated.spring(valueFor(item.id), {
        toValue: topLeft(positions[index]),
        delay: first ? index * 60 : 0,
        friction: 7,
        tension: 70,
        useNativeDriver: true,
      }).start();
    });
    // valueFor only reads refs and the current size.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [positions, localStores, opacity, state]);

  // Wiggle while editing; adjacent icons swing in opposite directions.
  useEffect(() => {
    if (!isEditMode) {
      wiggle.stopAnimation();
      Animated.spring(wiggle, {toValue: 0, useNativeDriver: true}).start();
      return;
    }
    wiggle.setValue(-1);
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(wiggle, {
          toValue: 1,
          duration: 140,
          easing: Easing.inOut(Easing.ease),
          useNativeDriver: true,
        }),
        Animated.timing(wiggle, {
          toValue: -1,
          duration: 140,
          easing: Easing.inOut(Easing.ease),
          useNativeDriver: true,
        }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [isEditMode, wiggle]);

  // ─── Drag to reorder ──────────────────────────────────────────────────────

  function beginDrag(id: string) {
    const index = state.localStores.findIndex(s => s.id === id);
    if (index < 0 || index >= state.positions.length) {
      return;
    }
    state.draggingId = id;
    state.dragStart = state.positions[index];
    state.swapped = false;
    setDraggingId(id);
  }

  function moveDrag(id: string, dx: number, dy: number) {
    if (state.draggingId !== id) {
      return;
    }
    // Anchored to where the drag began, so swapping the icon into another
    // slot doesn't move it out from under the finger.
    const finger = {x: state.dragStart.x + dx, y: state.dragStart.y + dy};
    valueFor(id).setValue(topLeft(finger));

    const dragIndex = state.localStores.findIndex(s => s.id === id);
    let closest = -1;
    let closestDistance = CIRCLE_SIZE * 0.85;
    state.positions.forEach((p, i) => {
      if (i === dragIndex || i >= state.localStores.length) {
        return;
      }
      const d = Math.hypot(finger.x - p.x, finger.y - p.y);
      if (d < closestDistance) {
        closestDistance = d;
        closest = i;
      }
    });
    if (closest >= 0) {
      const next = [...state.localStores];
      [next[dragIndex], next[closest]] = [next[closest], next[dragIndex]];
      state.localStores = next;
      state.swapped = true;
      setLocalStores(next);
    }
  }

  function endDrag(id: string) {
    if (state.draggingId !== id) {
      return;
    }
    state.draggingId = null;
    setDraggingId(null);
    const index = state.localStores.findIndex(s => s.id === id);
    if (index >= 0 && index < state.positions.length) {
      Animated.spring(valueFor(id), {
        toValue: topLeft(state.positions[index]),
        friction: 7,
        useNativeDriver: true,
      }).start();
    }
    if (state.swapped) {
      onReorder(state.localStores);
    }
  }

  function onLayout(e: LayoutChangeEvent) {
    const {width, height: h} = e.nativeEvent.layout;
    setSize({width, height: h});
  }

  return (
    <View style={styles.container} onLayout={onLayout}>
      {/* Tapping the empty space ends edit mode. */}
      {isEditMode && (
        <Pressable
          style={StyleSheet.absoluteFill}
          onPress={() => setEditMode(false)}
        />
      )}
      {size.width > 0 &&
        localStores.map((item, index) => (
          <FloatIcon
            key={item.id}
            item={item}
            index={index}
            position={valueFor(item.id)}
            opacity={opacity}
            wiggle={wiggle}
            isEditMode={isEditMode}
            isDragging={draggingId === item.id}
            onTap={() => onStoreTap(item)}
            onLongPress={() => setEditMode(true)}
            onDelete={() => onStoreDelete(item)}
            canDrag={() => state.isEditMode}
            onDragStart={() => beginDrag(item.id)}
            onDragMove={(dx, dy) => moveDrag(item.id, dx, dy)}
            onDragEnd={() => endDrag(item.id)}
          />
        ))}
    </View>
  );
}

interface IconProps {
  item: UserStoreItem;
  index: number;
  position: Animated.ValueXY;
  opacity: Animated.Value;
  wiggle: Animated.Value;
  isEditMode: boolean;
  isDragging: boolean;
  onTap: () => void;
  onLongPress: () => void;
  onDelete: () => void;
  canDrag: () => boolean;
  onDragStart: () => void;
  onDragMove: (dx: number, dy: number) => void;
  onDragEnd: () => void;
}

function FloatIcon(props: IconProps) {
  const {item, index, position, opacity, wiggle, isEditMode, isDragging} = props;
  const latest = useRef(props);
  latest.current = props;

  // Captures the gesture from the Pressable underneath once the finger moves
  // in edit mode — which includes straight after the long press that started
  // edit mode, without lifting the finger, as on iOS.
  const pan = useRef(
    PanResponder.create({
      onMoveShouldSetPanResponderCapture: (_, g) =>
        latest.current.canDrag() && (Math.abs(g.dx) > 4 || Math.abs(g.dy) > 4),
      onPanResponderGrant: () => latest.current.onDragStart(),
      onPanResponderMove: (_, g) => latest.current.onDragMove(g.dx, g.dy),
      onPanResponderRelease: () => latest.current.onDragEnd(),
      onPanResponderTerminate: () => latest.current.onDragEnd(),
      onPanResponderTerminationRequest: () => false,
    }),
  ).current;

  const phase = index % 2 === 0 ? 1 : -1;
  const rotate = wiggle.interpolate({
    inputRange: [-1, 1],
    outputRange: [`${-3 * phase}deg`, `${3 * phase}deg`],
  });
  const count = item.store.reminderCount ?? 0;

  return (
    <Animated.View
      {...pan.panHandlers}
      style={[
        styles.icon,
        {
          opacity,
          zIndex: isDragging ? 10 : 0,
          elevation: isDragging ? 10 : 0,
          transform: [
            ...position.getTranslateTransform(),
            // Always the animated node (it rests at 0 outside edit mode), so
            // the native-driven transform keeps the same shape every render.
            {rotate},
            {scale: isDragging ? 1.12 : 1},
          ],
        },
      ]}>
      <Pressable
        onPress={() => {
          if (!isEditMode) {
            props.onTap();
          }
        }}
        onLongPress={props.onLongPress}
        delayLongPress={500}
        accessibilityRole="button"
        accessibilityLabel={item.store.name}
        style={({pressed}) => ({
          transform: [{scale: pressed && !isEditMode ? 0.88 : 1}],
        })}>
        <StoreLogo storeName={item.store.name} size={CIRCLE_SIZE} />
        {count > 0 && (
          <View style={styles.countBadge}>
            <Text style={styles.countText}>{count}</Text>
          </View>
        )}
      </Pressable>
      {isEditMode && (
        <Pressable
          style={styles.deleteBadge}
          onPress={props.onDelete}
          hitSlop={8}
          accessibilityLabel={`Delete ${item.store.name}`}>
          <Icon name="remove" size={14} color={Colors.white} />
        </Pressable>
      )}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  icon: {
    position: 'absolute',
    left: 0,
    top: 0,
    width: CIRCLE_SIZE,
    height: CIRCLE_SIZE,
  },
  countBadge: {
    position: 'absolute',
    top: -5,
    right: -5,
    minWidth: 19,
    height: 19,
    borderRadius: 10,
    paddingHorizontal: 4,
    backgroundColor: Colors.blue,
    alignItems: 'center',
    justifyContent: 'center',
  },
  countText: {
    color: Colors.white,
    fontSize: 10,
    fontWeight: '700',
  },
  deleteBadge: {
    position: 'absolute',
    top: -6,
    left: -6,
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: Colors.red,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
