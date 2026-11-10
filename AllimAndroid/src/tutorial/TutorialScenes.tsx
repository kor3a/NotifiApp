import React, {useEffect, useMemo, useRef, useState} from 'react';
import {
  Animated,
  ColorSchemeName,
  Easing,
  PanResponder,
  Pressable,
  StyleProp,
  StyleSheet,
  Switch,
  Text,
  TouchableOpacity,
  View,
  ViewStyle,
  useColorScheme,
} from 'react-native';
import Icon from '../components/AppIcon';
import ProfileAvatar from '../components/ProfileAvatar';
import {
  Colors,
  cardBackground,
  sheetBackground,
  sheetFill,
  textPrimary,
  textSecondary,
} from '../theme/AppTheme';

/**
 * The playable demos behind each tutorial chapter. Every scene is a small,
 * self-contained mock of one idea in the app — nothing here reads or writes
 * real data — and calls `onDone` the first time the user plays it through.
 * Port of the iOS TutorialScenes.
 */

type IconName = React.ComponentProps<typeof Icon>['name'];

// ─── Palette ──────────────────────────────────────────────────────────────────

/** The tutorial's roles, in the Android app's palette. */
export function tutorialPalette(scheme: ColorSchemeName) {
  const dark = scheme === 'dark';
  return {
    accent: Colors.blue,
    onAccent: Colors.white,
    blush: dark ? 'rgba(0,122,255,0.24)' : 'rgba(0,122,255,0.10)',
    inkOnBlush: dark ? '#7DBBFF' : '#0A5DC2',
    // The warm one, kept for the thing the app is telling you about.
    highlight: Colors.orange,
    highlightWash: dark ? 'rgba(255,149,0,0.22)' : 'rgba(255,149,0,0.14)',
    sage: dark ? '#1F3A28' : '#DDF3E3',
    sageInk: dark ? '#5FD982' : '#1E7A35',
    rust: Colors.red,
    rustWash: dark ? 'rgba(255,59,48,0.20)' : 'rgba(255,59,48,0.10)',
    outline: dark ? 'rgba(255,255,255,0.18)' : 'rgba(0,0,0,0.12)',
    // The card a demo plays on, the panels inside it, and anything raised
    // above those (chips, menus).
    surface: cardBackground(scheme),
    inset: sheetFill(scheme),
    raised: sheetBackground(scheme),
    ink: textPrimary(scheme),
    inkSoft: textSecondary(scheme),
    inkMuted: dark ? 'rgba(255,255,255,0.4)' : 'rgba(0,0,0,0.38)',
  };
}

type Palette = ReturnType<typeof tutorialPalette>;

type Category = 'Produce' | 'Dairy' | 'Bakery';

const CATEGORY_COLORS: Record<
  Category,
  {dot: [string, string]; tint: [string, string]; label: [string, string]}
> = {
  Produce: {dot: ['#3FA96B', '#5FC489'], tint: ['#E7F4EC', '#14301F'], label: ['#1C6640', '#A9E3C0']},
  Dairy: {dot: ['#4F8FD6', '#74ABE6'], tint: ['#E7F0FA', '#14243A'], label: ['#1F5490', '#B3D2F2']},
  Bakery: {dot: ['#B98A5A', '#D3A87A'], tint: ['#F4EBE1', '#2E2318'], label: ['#7A5432', '#E6CBAB']},
};

function categoryColors(category: Category, scheme: ColorSchemeName) {
  const index = scheme === 'dark' ? 1 : 0;
  const c = CATEGORY_COLORS[category];
  return {dot: c.dot[index], tint: c.tint[index], label: c.label[index]};
}

// ─── Shared pieces ────────────────────────────────────────────────────────────

/** Springs its children in when it mounts. */
export function Appear({
  children,
  from = 'below',
  delay = 0,
  style,
}: {
  children: React.ReactNode;
  from?: 'below' | 'above' | 'scale';
  delay?: number;
  style?: StyleProp<ViewStyle>;
}) {
  const value = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    Animated.spring(value, {
      toValue: 1,
      friction: 8,
      tension: 70,
      delay,
      useNativeDriver: true,
    }).start();
  }, [value, delay]);

  const transform =
    from === 'scale'
      ? [{scale: value.interpolate({inputRange: [0, 1], outputRange: [0.6, 1]})}]
      : [
          {
            translateY: value.interpolate({
              inputRange: [0, 1],
              outputRange: [from === 'below' ? 22 : -22, 0],
            }),
          },
        ];
  return <Animated.View style={[style, {opacity: value, transform}]}>{children}</Animated.View>;
}

/** A ring that breathes outward from whatever the user is asked to touch. */
export function Pulse({color, size = 58}: {color: string; size?: number}) {
  const value = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const loop = Animated.loop(
      Animated.timing(value, {
        toValue: 1,
        duration: 1400,
        easing: Easing.out(Easing.quad),
        useNativeDriver: true,
      }),
    );
    loop.start();
    return () => loop.stop();
  }, [value]);

  return (
    <Animated.View
      pointerEvents="none"
      style={{
        position: 'absolute',
        alignSelf: 'center',
        width: size,
        height: size,
        borderRadius: size / 2,
        borderWidth: 2,
        borderColor: color,
        opacity: value.interpolate({inputRange: [0, 1], outputRange: [0.8, 0]}),
        transform: [{scale: value.interpolate({inputRange: [0, 1], outputRange: [1, 1.7]})}],
      }}
    />
  );
}

/** A list item drawn as a chip, with the dot of the category it belongs to. */
export function Chip({name, category}: {name: string; category: Category}) {
  const scheme = useColorScheme();
  const p = tutorialPalette(scheme);
  return (
    <View style={[styles.chip, {backgroundColor: p.raised, borderColor: p.outline}]}>
      <View style={[styles.chipDot, {backgroundColor: categoryColors(category, scheme).dot}]} />
      <Text style={[styles.chipText, {color: p.ink}]} numberOfLines={1}>
        {name}
      </Text>
    </View>
  );
}

function StoreTile({p}: {p: Palette}) {
  return (
    <View style={[styles.storeTile, {backgroundColor: p.blush}]}>
      <Icon name="storefront" size={19} color={p.accent} />
    </View>
  );
}

type SceneProps = {onDone: () => void};

// ─── 01 · Add a store ─────────────────────────────────────────────────────────

const STORES = ['Whole Foods', "Trader Joe's", 'Costco'];

export function AddStoreScene({onDone, startsDone}: SceneProps & {startsDone: boolean}) {
  const p = tutorialPalette(useColorScheme());
  const [count, setCount] = useState(startsDone ? 1 : 0);
  const isFull = count >= STORES.length;

  function add() {
    if (isFull) {
      return;
    }
    setCount(count + 1);
    if (count === 0) {
      onDone();
    }
  }

  return (
    <View style={styles.scene}>
      <Text style={[styles.sceneTitle, {color: p.ink}]}>Stores</Text>

      {count === 0 && (
        <View style={[styles.emptyCard, {borderColor: p.outline}]}>
          <Icon name="storefront-outline" size={19} color={p.inkMuted} />
          <Text style={[styles.emptyText, {color: p.inkMuted}]}>No stores yet</Text>
        </View>
      )}

      {STORES.slice(0, count).map(name => (
        <Appear key={name}>
          <View style={[styles.panelRow, {backgroundColor: p.inset}]}>
            <StoreTile p={p} />
            <View style={{flex: 1}}>
              <Text style={[styles.rowTitle, {color: p.ink}]}>{name}</Text>
              <View style={styles.rowDetailLine}>
                <Icon name="location" size={10} color={p.inkSoft} />
                <Text style={[styles.rowDetail, {color: p.inkSoft}]}>Nearby alerts on</Text>
              </View>
            </View>
            <Icon name="chevron-forward" size={14} color={p.inkMuted} />
          </View>
        </Appear>
      ))}

      <View style={styles.fabWrap}>
        {count === 0 && <Pulse color={p.accent} />}
        <TouchableOpacity
          onPress={add}
          activeOpacity={0.8}
          accessibilityLabel="Add store"
          style={[styles.fab, {backgroundColor: p.accent, opacity: isFull ? 0.4 : 1}]}>
          <Icon name="add" size={28} color={p.onAccent} />
        </TouchableOpacity>
      </View>
    </View>
  );
}

// ─── 02 · Smart Category ──────────────────────────────────────────────────────

const ITEMS: {name: string; category: Category}[] = [
  {name: 'Bananas', category: 'Produce'},
  {name: 'Whole Milk', category: 'Dairy'},
  {name: 'Sourdough', category: 'Bakery'},
  {name: 'Spinach', category: 'Produce'},
  {name: 'Greek Yogurt', category: 'Dairy'},
  {name: 'Croissants', category: 'Bakery'},
];

export function SmartSortScene({onDone}: SceneProps) {
  const scheme = useColorScheme();
  const p = tutorialPalette(scheme);
  /** Names of the items added to the list, in the order they were tapped. */
  const [added, setAdded] = useState<string[]>([]);

  const waiting = ITEMS.filter(item => !added.includes(item.name));

  // Categories in the order their first item arrived, the way the real list
  // grows a section the first time something lands in it.
  const sections = useMemo(() => {
    const addedItems = added
      .map(name => ITEMS.find(item => item.name === name))
      .filter((item): item is (typeof ITEMS)[number] => !!item);
    const order: Category[] = [];
    addedItems.forEach(item => {
      if (!order.includes(item.category)) {
        order.push(item.category);
      }
    });
    return order.map(category => ({
      category,
      items: addedItems.filter(item => item.category === category),
    }));
  }, [added]);

  function add(name: string) {
    const next = [...added, name];
    setAdded(next);
    if (next.length === 2) {
      onDone();
    }
  }

  return (
    <View style={styles.scene}>
      <View style={styles.sceneHeader}>
        <Text style={[styles.sceneTitle, {color: p.ink}]}>Whole Foods</Text>
        {added.length > 0 && (
          <View style={[styles.countBadge, {backgroundColor: p.highlight}]}>
            <Text style={styles.countBadgeText}>{added.length}</Text>
          </View>
        )}
        <View style={{flex: 1}} />
        <Icon name="sparkles" size={16} color={p.accent} />
      </View>

      {added.length === 0 && (
        <Text style={[styles.rowDetail, {color: p.inkMuted, fontSize: 14}]}>
          Your list is empty.
        </Text>
      )}

      {sections.map(section => {
        const colors = categoryColors(section.category, scheme);
        return (
          <Appear key={section.category} from="above">
            <View style={[styles.section, {backgroundColor: colors.tint}]}>
              <Text style={[styles.sectionLabel, {color: colors.label}]}>{section.category}</Text>
              <View style={styles.sectionChips}>
                {section.items.map(item => (
                  <Appear key={item.name} from="scale">
                    <Chip name={item.name} category={item.category} />
                  </Appear>
                ))}
              </View>
            </View>
          </Appear>
        );
      })}

      <View style={{flex: 1}} />

      <View style={[styles.tray, {backgroundColor: p.inset}]}>
        <Text style={[styles.trayLabel, {color: p.inkMuted}]}>
          {waiting.length === 0 ? 'ALL SORTED' : 'ADD TO LIST'}
        </Text>
        {waiting.length === 0 ? (
          <TouchableOpacity
            onPress={() => setAdded([])}
            activeOpacity={0.7}
            style={styles.replay}>
            <Icon name="refresh" size={15} color={p.accent} />
            <Text style={[styles.replayText, {color: p.accent}]}>Play again</Text>
          </TouchableOpacity>
        ) : (
          <View style={styles.trayChips}>
            {waiting.map(item => (
              <TouchableOpacity key={item.name} onPress={() => add(item.name)} activeOpacity={0.7}>
                <Chip name={item.name} category={item.category} />
              </TouchableOpacity>
            ))}
          </View>
        )}
      </View>
    </View>
  );
}

// ─── 03 · Nearby alerts ───────────────────────────────────────────────────────

type Point = {x: number; y: number};

export function NearbyScene({onDone}: SceneProps) {
  const p = tutorialPalette(useColorScheme());
  const [size, setSize] = useState({width: 0, height: 0});
  /** Where the user has dragged themselves to; null until they first move. */
  const [position, setPosition] = useState<Point | null>(null);
  const [isInside, setIsInside] = useState(false);

  const store = {x: size.width * 0.64, y: size.height * 0.52};
  const radius = Math.min(size.width, size.height) * 0.27;
  const start = {x: size.width * 0.17, y: size.height * 0.8};
  const you = position ?? start;

  // The pan responder is created once, so it reads the live geometry and
  // state through this ref rather than from a stale render.
  const live = useRef({size, store, radius, you, isInside, onDone});
  live.current = {size, store, radius, you, isInside, onDone};
  const dragOrigin = useRef<Point>({x: 0, y: 0});

  function moveTo(target: Point) {
    const {store: s, radius: r, isInside: wasInside, onDone: done} = live.current;
    setPosition(target);
    const inside = Math.hypot(target.x - s.x, target.y - s.y) < r;
    if (inside !== wasInside) {
      setIsInside(inside);
      if (inside) {
        done();
      }
    }
  }
  const moveToRef = useRef(moveTo);
  moveToRef.current = moveTo;

  const pan = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: () => true,
      onPanResponderGrant: () => {
        dragOrigin.current = live.current.you;
      },
      onPanResponderMove: (_, gesture) => {
        const {width, height} = live.current.size;
        moveToRef.current({
          x: Math.min(Math.max(dragOrigin.current.x + gesture.dx, 20), width - 20),
          y: Math.min(Math.max(dragOrigin.current.y + gesture.dy, 20), height - 20),
        });
      },
      // The stage sits in nothing that scrolls, but never hand the drag away.
      onPanResponderTerminationRequest: () => false,
    }),
  ).current;

  const ready = size.width > 0;
  const road = p.surface;

  return (
    <View
      style={[StyleSheet.absoluteFill, {backgroundColor: p.inset}]}
      onLayout={e => setSize(e.nativeEvent.layout)}>
      {ready && (
        <>
          {/* A few streets and a park — enough to read as a map. */}
          <View
            style={{
              position: 'absolute',
              left: size.width * 0.06,
              top: size.height * 0.1,
              width: size.width * 0.3,
              height: size.height * 0.34,
              borderRadius: 18,
              backgroundColor: p.sage,
            }}
          />
          {[0.52, 0.94].map(f => (
            <View
              key={`h${f}`}
              style={[styles.roadH, {top: size.height * f - 6, backgroundColor: road}]}
            />
          ))}
          {[0.44, 0.93].map(f => (
            <View
              key={`v${f}`}
              style={[styles.roadV, {left: size.width * f - 6, backgroundColor: road}]}
            />
          ))}

          {/* The area Allim watches around the store. */}
          <View
            pointerEvents="none"
            style={{
              position: 'absolute',
              left: store.x - radius,
              top: store.y - radius,
              width: radius * 2,
              height: radius * 2,
              borderRadius: radius,
              borderWidth: 2,
              borderStyle: isInside ? 'solid' : 'dashed',
              borderColor: p.highlight,
              backgroundColor: p.highlightWash,
              transform: [{scale: isInside ? 1.06 : 1}],
            }}
          />

          {/* Tapping the store walks there, for anyone who'd rather not drag. */}
          <TouchableOpacity
            activeOpacity={0.8}
            accessibilityLabel="Walk to Whole Foods"
            onPress={() => moveTo({x: store.x - radius * 0.45, y: store.y + radius * 0.45})}
            style={[styles.storePin, {left: store.x - 50, top: store.y - 21}]}>
            <View style={[styles.storePinDisc, {backgroundColor: p.accent}]}>
              <Icon name="storefront" size={19} color={p.onAccent} />
            </View>
            <Text style={[styles.storePinLabel, {color: p.ink, backgroundColor: p.raised}]}>
              Whole Foods
            </Text>
          </TouchableOpacity>

          <View
            {...pan.panHandlers}
            accessibilityLabel="You"
            style={[styles.youWrap, {left: you.x - 32, top: you.y - 32}]}>
            {position === null && <Pulse color={p.accent} size={34} />}
            <View style={[styles.youDot, {backgroundColor: p.ink, borderColor: p.raised}]} />
          </View>

          {isInside && (
            <Appear from="above" style={styles.bannerWrap}>
              <View style={[styles.banner, {backgroundColor: p.raised}]}>
                <View style={[styles.bannerIcon, {backgroundColor: p.highlight}]}>
                  <Icon name="notifications" size={17} color={Colors.white} />
                </View>
                <View style={{flex: 1}}>
                  <Text style={[styles.bannerTitle, {color: p.ink}]}>You're near Whole Foods</Text>
                  <Text style={[styles.rowDetail, {color: p.inkSoft}]} numberOfLines={1}>
                    3 items waiting: Bananas, Whole Milk…
                  </Text>
                </View>
                <Text style={[styles.bannerTime, {color: p.inkMuted}]}>now</Text>
              </View>
            </Appear>
          )}
        </>
      )}
    </View>
  );
}

// ─── 04 · Shortcuts ───────────────────────────────────────────────────────────

const LIST_ITEMS = ['Bananas', 'Whole Milk', 'Sourdough'];

export function ShortcutsScene({onDone}: SceneProps) {
  const p = tutorialPalette(useColorScheme());
  const [checked, setChecked] = useState<string[]>([]);
  const [outOfStock, setOutOfStock] = useState<string[]>([]);
  /** The item whose touch-and-hold menu is open. */
  const [heldItem, setHeldItem] = useState<string | null>(null);
  const [showsListMenu, setShowsListMenu] = useState(false);
  const [autoDelete, setAutoDelete] = useState(false);
  const [smartCategory, setSmartCategory] = useState(true);

  const menuOpen = heldItem !== null || showsListMenu;

  function toggle(list: string[], item: string) {
    return list.includes(item) ? list.filter(i => i !== item) : [...list, item];
  }

  function closeMenus() {
    setHeldItem(null);
    setShowsListMenu(false);
  }

  // Rows fall back while a menu is open — all of them under the list menu,
  // every one but the held item under its shortcut menu.
  function isDimmed(item: string) {
    return showsListMenu || (heldItem !== null && heldItem !== item);
  }

  const itemMenu: {title: string; icon: IconName; action?: () => void}[] = heldItem
    ? [
        outOfStock.includes(heldItem)
          ? {
              title: 'Back in Stock',
              icon: 'checkmark-circle-outline',
              action: () => setOutOfStock(toggle(outOfStock, heldItem)),
            }
          : {
              title: 'Out of Stock',
              icon: 'close-circle-outline',
              action: () => setOutOfStock(toggle(outOfStock, heldItem)),
            },
        {title: 'Move to Store', icon: 'enter-outline'},
        {title: 'Add Photos', icon: 'images-outline'},
        {title: 'Add Quantity', icon: 'keypad-outline'},
        {title: 'Change Category', icon: 'pricetag-outline'},
      ]
    : [];

  return (
    <View style={styles.scene}>
      <View style={styles.sceneHeader}>
        <Text style={[styles.sceneTitle, {color: p.ink}]}>Whole Foods</Text>
        <View style={{flex: 1}} />
        <TouchableOpacity
          accessibilityLabel="List menu"
          activeOpacity={0.7}
          onPress={() => {
            setShowsListMenu(true);
            onDone();
          }}
          style={[styles.infoButton, {backgroundColor: p.blush}]}>
          <Icon name="information-circle-outline" size={23} color={p.accent} />
        </TouchableOpacity>
      </View>

      {LIST_ITEMS.map(item => {
        const isChecked = checked.includes(item);
        return (
          <Pressable
            key={item}
            delayLongPress={300}
            onLongPress={() => {
              setHeldItem(item);
              onDone();
            }}
            style={({pressed}) => [
              styles.listRow,
              {
                backgroundColor: p.inset,
                opacity: isDimmed(item) ? 0.3 : 1,
                transform: [{scale: pressed ? 0.96 : heldItem === item ? 1.03 : 1}],
              },
            ]}>
            <TouchableOpacity
              onPress={() => setChecked(toggle(checked, item))}
              hitSlop={8}
              accessibilityLabel={isChecked ? `Uncheck ${item}` : `Check ${item}`}>
              <Icon
                name={isChecked ? 'checkbox' : 'square-outline'}
                size={22}
                color={isChecked ? p.accent : p.inkSoft}
              />
            </TouchableOpacity>
            <Text
              style={[
                styles.listRowText,
                {color: isChecked ? p.inkMuted : p.ink},
                isChecked && {textDecorationLine: 'line-through'},
              ]}>
              {item}
            </Text>
            <View style={{flex: 1}} />
            {outOfStock.includes(item) && (
              <Text style={[styles.outTag, {color: p.rust, backgroundColor: p.rustWash}]}>
                Out of stock
              </Text>
            )}
          </Pressable>
        );
      })}

      {/* Catches a tap anywhere outside an open menu. */}
      {menuOpen && <Pressable style={StyleSheet.absoluteFill} onPress={closeMenus} />}

      {heldItem !== null && (
        <Appear from="scale" style={styles.itemMenuWrap}>
          <View style={[styles.menu, {width: 230, backgroundColor: p.raised}]}>
            {itemMenu.map((row, index) => (
              <TouchableOpacity
                key={row.title}
                activeOpacity={0.6}
                onPress={() => {
                  row.action?.();
                  closeMenus();
                }}
                style={[
                  styles.itemMenuRow,
                  index > 0 && {borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: p.outline},
                ]}>
                <Text style={[styles.itemMenuText, {color: p.ink}]}>{row.title}</Text>
                <Icon name={row.icon} size={17} color={p.ink} />
              </TouchableOpacity>
            ))}
          </View>
        </Appear>
      )}

      {showsListMenu && (
        <Appear from="scale" style={styles.listMenuWrap}>
          <View style={[styles.menu, {width: 266, backgroundColor: p.raised}]}>
            <ListMenuRow p={p} icon="trash-outline" title="Auto Delete" detail="Clear checked items">
              <Switch
                value={autoDelete}
                onValueChange={setAutoDelete}
                trackColor={{true: p.accent, false: p.outline}}
                thumbColor={Colors.white}
              />
            </ListMenuRow>
            <ListMenuRow
              p={p}
              divided
              icon="sparkles"
              title="Smart Category"
              detail="Sort new items for you">
              <Switch
                value={smartCategory}
                onValueChange={setSmartCategory}
                trackColor={{true: p.accent, false: p.outline}}
                thumbColor={Colors.white}
              />
            </ListMenuRow>
            <ListMenuRow
              p={p}
              divided
              icon="restaurant-outline"
              title="Recipes"
              detail="Add a recipe's ingredients">
              <Icon name="chevron-forward" size={14} color={p.inkMuted} />
            </ListMenuRow>
            <ListMenuRow
              p={p}
              divided
              icon="compass-outline"
              title="Visit store"
              detail="Open its app or website">
              <Icon name="open-outline" size={14} color={p.inkMuted} />
            </ListMenuRow>
          </View>
        </Appear>
      )}
    </View>
  );
}

function ListMenuRow({
  p,
  icon,
  title,
  detail,
  divided,
  children,
}: {
  p: Palette;
  icon: IconName;
  title: string;
  detail: string;
  divided?: boolean;
  children: React.ReactNode;
}) {
  return (
    <View
      style={[
        styles.listMenuRow,
        divided && {borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: p.outline},
      ]}>
      <View style={[styles.listMenuIcon, {backgroundColor: p.blush}]}>
        <Icon name={icon} size={15} color={p.accent} />
      </View>
      <View style={{flex: 1}}>
        <Text style={[styles.listMenuTitle, {color: p.ink}]}>{title}</Text>
        <Text style={[styles.listMenuDetail, {color: p.inkSoft}]} numberOfLines={1}>
          {detail}
        </Text>
      </View>
      {children}
    </View>
  );
}

// ─── 05 · Sharing ─────────────────────────────────────────────────────────────

const PEOPLE = [
  {name: 'Sam', isFamily: true},
  {name: 'Alex', isFamily: false},
  {name: 'Jamie', isFamily: false},
];

export function ShareScene({onDone}: SceneProps) {
  const p = tutorialPalette(useColorScheme());
  /** Who the list is shared with, in the order they were tapped. */
  const [shared, setShared] = useState<string[]>([]);

  function toggle(name: string) {
    if (shared.includes(name)) {
      setShared(shared.filter(n => n !== name));
      return;
    }
    if (shared.length === 0) {
      onDone();
    }
    setShared([...shared, name]);
  }

  return (
    <View style={styles.scene}>
      <View style={[styles.panelRow, {backgroundColor: p.inset}]}>
        <StoreTile p={p} />
        <View style={{flex: 1}}>
          <Text style={[styles.rowTitle, {color: p.ink}]}>Whole Foods</Text>
          <Text
            style={[styles.rowDetail, {color: shared.length ? p.sageInk : p.inkSoft}]}
            numberOfLines={1}>
            {shared.length ? `Shared with ${shared.join(', ')}` : 'Only you'}
          </Text>
        </View>
        <View style={styles.sharedAvatars}>
          {shared.map(name => (
            <Appear key={name} from="scale" style={{marginLeft: -8}}>
              <ProfileAvatar name={name} size={28} />
            </Appear>
          ))}
        </View>
      </View>

      <Text style={[styles.trayLabel, {color: p.inkMuted, marginTop: 6}]}>SHARE WITH</Text>

      <View style={styles.people}>
        {PEOPLE.map(person => {
          const isShared = shared.includes(person.name);
          return (
            <TouchableOpacity
              key={person.name}
              onPress={() => toggle(person.name)}
              activeOpacity={0.75}
              accessibilityLabel={
                isShared ? `Stop sharing with ${person.name}` : `Share with ${person.name}`
              }
              style={styles.person}>
              <View>
                {shared.length === 0 && person.isFamily && <Pulse color={p.accent} size={60} />}
                <View
                  style={[
                    styles.personRing,
                    {borderColor: isShared ? p.sageInk : 'transparent'},
                  ]}>
                  <ProfileAvatar name={person.name} size={54} />
                </View>
                {isShared && (
                  <Appear from="scale" style={styles.personCheckWrap}>
                    <View style={[styles.personCheck, {backgroundColor: p.sageInk}]}>
                      <Icon name="checkmark" size={12} color={Colors.white} />
                    </View>
                  </Appear>
                )}
              </View>
              <Text style={[styles.personName, {color: p.ink}]}>{person.name}</Text>
              <Text
                style={[
                  styles.familyTag,
                  {color: p.sageInk, backgroundColor: p.sage, opacity: person.isFamily ? 1 : 0},
                ]}>
                Family
              </Text>
            </TouchableOpacity>
          );
        })}
      </View>

      {shared.length > 0 && (
        <Appear key={shared[0]}>
          <View style={styles.message}>
            <ProfileAvatar name={shared[0]} size={26} />
            <View style={[styles.bubble, {backgroundColor: p.inset}]}>
              <Text style={[styles.bubbleName, {color: p.inkSoft}]}>{shared[0]}</Text>
              <Text style={[styles.bubbleText, {color: p.ink}]}>
                On my way to Whole Foods — I'll grab the milk.
              </Text>
            </View>
          </View>
        </Appear>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  scene: {
    flex: 1,
    padding: 18,
    gap: 9,
  },
  sceneHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  sceneTitle: {
    fontSize: 22,
    fontWeight: '800',
  },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 7,
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderRadius: 20,
    borderWidth: 1,
  },
  chipDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  chipText: {
    fontSize: 14,
    fontWeight: '600',
  },
  storeTile: {
    width: 42,
    height: 42,
    borderRadius: 13,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyCard: {
    height: 64,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
    borderRadius: 20,
    borderWidth: 1.5,
    borderStyle: 'dashed',
  },
  emptyText: {
    fontSize: 15,
    fontWeight: '600',
  },
  panelRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    padding: 11,
    borderRadius: 20,
  },
  rowTitle: {
    fontSize: 16,
    fontWeight: '700',
  },
  rowDetailLine: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  rowDetail: {
    fontSize: 12,
  },
  fabWrap: {
    position: 'absolute',
    right: 18,
    bottom: 18,
    justifyContent: 'center',
  },
  fab: {
    width: 58,
    height: 58,
    borderRadius: 29,
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 5,
  },
  countBadge: {
    paddingHorizontal: 8,
    paddingVertical: 1,
    borderRadius: 10,
  },
  countBadgeText: {
    color: Colors.white,
    fontSize: 12,
    fontWeight: '700',
  },
  section: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 18,
  },
  sectionLabel: {
    width: 62,
    fontSize: 13,
    fontWeight: '700',
  },
  sectionChips: {
    flex: 1,
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
  },
  tray: {
    gap: 8,
    padding: 12,
    borderRadius: 20,
  },
  trayLabel: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 1,
  },
  trayChips: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  replay: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  replayText: {
    fontSize: 14,
    fontWeight: '600',
  },
  roadH: {
    position: 'absolute',
    left: 0,
    right: 0,
    height: 12,
  },
  roadV: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    width: 12,
  },
  storePin: {
    position: 'absolute',
    width: 100,
    alignItems: 'center',
    gap: 4,
  },
  storePinDisc: {
    width: 42,
    height: 42,
    borderRadius: 21,
    alignItems: 'center',
    justifyContent: 'center',
  },
  storePinLabel: {
    fontSize: 11,
    fontWeight: '700',
    paddingHorizontal: 7,
    paddingVertical: 2,
    borderRadius: 9,
    overflow: 'hidden',
  },
  youWrap: {
    position: 'absolute',
    width: 64,
    height: 64,
    alignItems: 'center',
    justifyContent: 'center',
  },
  youDot: {
    width: 26,
    height: 26,
    borderRadius: 13,
    borderWidth: 4,
    elevation: 4,
  },
  bannerWrap: {
    position: 'absolute',
    left: 12,
    right: 12,
    top: 12,
  },
  banner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    padding: 10,
    borderRadius: 20,
    elevation: 6,
  },
  bannerIcon: {
    width: 36,
    height: 36,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  bannerTitle: {
    fontSize: 14,
    fontWeight: '700',
  },
  bannerTime: {
    fontSize: 11,
  },
  infoButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  listRow: {
    height: 50,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 14,
    borderRadius: 18,
  },
  listRowText: {
    fontSize: 16,
    fontWeight: '600',
  },
  outTag: {
    fontSize: 11,
    fontWeight: '700',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 10,
    overflow: 'hidden',
  },
  menu: {
    borderRadius: 22,
    elevation: 12,
  },
  itemMenuWrap: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 14,
    alignItems: 'center',
  },
  itemMenuRow: {
    height: 38,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginHorizontal: 16,
  },
  itemMenuText: {
    fontSize: 15,
  },
  listMenuWrap: {
    position: 'absolute',
    right: 14,
    top: 14,
  },
  listMenuRow: {
    height: 52,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginHorizontal: 14,
  },
  listMenuIcon: {
    width: 30,
    height: 30,
    borderRadius: 15,
    alignItems: 'center',
    justifyContent: 'center',
  },
  listMenuTitle: {
    fontSize: 14,
    fontWeight: '600',
  },
  listMenuDetail: {
    fontSize: 11,
  },
  sharedAvatars: {
    flexDirection: 'row',
    paddingLeft: 8,
  },
  people: {
    flexDirection: 'row',
  },
  person: {
    flex: 1,
    alignItems: 'center',
    gap: 4,
  },
  personRing: {
    padding: 2,
    borderRadius: 32,
    borderWidth: 3,
  },
  personCheckWrap: {
    position: 'absolute',
    right: 0,
    bottom: 0,
  },
  personCheck: {
    width: 20,
    height: 20,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  personName: {
    fontSize: 13,
    fontWeight: '600',
  },
  familyTag: {
    fontSize: 10,
    fontWeight: '700',
    paddingHorizontal: 7,
    paddingVertical: 2,
    borderRadius: 8,
    overflow: 'hidden',
  },
  message: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 8,
    marginTop: 4,
  },
  bubble: {
    flexShrink: 1,
    gap: 2,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 18,
  },
  bubbleName: {
    fontSize: 11,
    fontWeight: '700',
  },
  bubbleText: {
    fontSize: 14,
    lineHeight: 19,
  },
});
