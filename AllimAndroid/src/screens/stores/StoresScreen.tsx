import React, {useEffect, useState, useRef, useCallback} from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Animated,
  PanResponder,
  useColorScheme,
  ActivityIndicator,
  NativeScrollEvent,
  NativeSyntheticEvent,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {useNavigation} from '@react-navigation/native';
import {NativeStackNavigationProp} from '@react-navigation/native-stack';
import {Swipeable} from 'react-native-gesture-handler';
import AsyncStorage from '@react-native-async-storage/async-storage';
import Icon from '../../components/AppIcon';

import SurfaceBackground from '../../components/SurfaceBackground';
import ProfileAvatar from '../../components/ProfileAvatar';
import StoreLogo from '../../components/StoreLogo';
import AddStoreSheet from './AddStoreSheet';
import ShareStoreSheet from './ShareStoreSheet';
import StoreFloatView from './StoreFloatView';
import OnMyWayDialog from './OnMyWayDialog';
import BackgroundPickerSheet from './BackgroundPickerSheet';
import RecipesSheet from '../recipe/RecipesSheet';
import {
  Colors,
  Spacing,
  Radius,
  cardStyle,
  textPrimary,
  textSecondary,
  cardBackground,
  sheetBackground,
} from '../../theme/AppTheme';
import {useSession} from '../../context/SessionContext';
import {storeService} from '../../services/storeService';
import {
  canAddStore,
  hasPremiumAccess,
  isStoreLimitError,
} from '../../services/subscription';
import {
  onMyWayService,
  TravelEstimate,
  formattedTravelTime,
} from '../../services/onMyWayService';
import {
  UserStoreItem,
  isRecipientStore,
  reminderStoreIdFor,
} from '../../models';
import {StoresStackParamList} from '../../navigation/AppNavigator';
import {useTutorialActive, useTutorialTarget} from '../../tutorial/tutorialManager';
import {TUTORIAL_STORES} from '../../tutorial/tutorialMockData';

type Nav = NativeStackNavigationProp<StoresStackParamList, 'StoresList'>;
type StoreViewMode = 'list' | 'float';

// Same key the iOS app keeps its @AppStorage under.
const VIEW_MODE_KEY = 'storeViewMode';
const FAB_SIZE = 60;
const FAB_SHRUNK_SIZE = 28;
const FAB_INACTIVITY_MS = 5000;

export default function StoresScreen() {
  const scheme = useColorScheme();
  const navigation = useNavigation<Nav>();
  const {currentUser, firebaseUser} = useSession();

  const [liveStores, setStores] = useState<UserStoreItem[]>([]);
  const [liveLoading, setLoading] = useState(true);

  // While the tutorial runs, the screen shows a few stand-in stores so the
  // tour has a list and its toolbar to point at — iOS TutorialMockData. The
  // overlay keeps every touch off them.
  const tutorialActive = useTutorialActive();
  const stores = tutorialActive ? TUTORIAL_STORES : liveStores;
  const loading = liveLoading && !tutorialActive;
  const fabTarget = useTutorialTarget('tutorial_fab');
  const toolbarTarget = useTutorialTarget('tutorial_toolbar');
  const profileTarget = useTutorialTarget('tutorial_profile');
  const [showAddSheet, setShowAddSheet] = useState(false);
  const [showRecipes, setShowRecipes] = useState(false);
  const [showColors, setShowColors] = useState(false);
  const [storeToShare, setStoreToShare] = useState<UserStoreItem | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [viewMode, setViewMode] = useState<StoreViewMode>('list');

  // Reordering: long-press a row (or icon, in the grid) to start; the header
  // shows Done while it lasts, as on iOS.
  const [isReordering, setIsReordering] = useState(false);
  const [isFloatEditMode, setIsFloatEditMode] = useState(false);
  const [dragIndex, setDragIndex] = useState<number | null>(null);
  const [hoverIndex, setHoverIndex] = useState<number | null>(null);
  const dragY = useRef(new Animated.Value(0)).current;
  const rowHeight = useRef(0);
  const drag = useRef({index: -1, hover: -1});

  // A just-written order wins over listener emissions that predate it, so the
  // list doesn't flick back while the write lands (iOS isManuallyReordering).
  const pendingOrder = useRef<{ids: string[]; until: number} | null>(null);

  // On My Way
  const [onMyWayStore, setOnMyWayStore] = useState<UserStoreItem | null>(null);
  const [estimate, setEstimate] = useState<TravelEstimate | null>(null);
  const [isEstimating, setIsEstimating] = useState(false);
  const [estimateUnavailable, setEstimateUnavailable] = useState(false);
  const [isSending, setIsSending] = useState(false);
  const estimateToken = useRef(0);

  // FAB shrinks out of the way after a few idle seconds or a scroll in list
  // mode, and grows back on tap or at the bottom of the list.
  const [isFabShrunk, setIsFabShrunk] = useState(false);
  const fabShrink = useRef(new Animated.Value(0)).current;
  const fabTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const isUserScrolling = useRef(false);

  // Only one row stays open at a time, the way a list row behaves on iOS.
  const openRow = useRef<Swipeable | null>(null);

  useEffect(() => {
    if (!firebaseUser || !currentUser) {return;}
    const unsub = storeService.subscribeToUserStores(
      currentUser.userId,
      currentUser.email,
      items => {
        const pending = pendingOrder.current;
        if (pending && Date.now() < pending.until) {
          const rank = new Map(pending.ids.map((id, i) => [id, i]));
          items = [...items].sort(
            (a, b) =>
              (rank.get(a.id) ?? Number.MAX_SAFE_INTEGER) -
              (rank.get(b.id) ?? Number.MAX_SAFE_INTEGER),
          );
        } else {
          pendingOrder.current = null;
        }
        setStores(items);
        setLoading(false);
      },
    );
    return unsub;
  }, [firebaseUser, currentUser]);

  // The chosen layout is remembered between launches.
  useEffect(() => {
    AsyncStorage.getItem(VIEW_MODE_KEY)
      .then(mode => {
        if (mode === 'list' || mode === 'float') {
          setViewMode(mode);
        }
      })
      .catch(() => {});
  }, []);

  // ─── FAB shrink ───────────────────────────────────────────────────────────

  useEffect(() => {
    Animated.spring(fabShrink, {
      // Held at full size while the tutorial is pointing at it.
      toValue: isFabShrunk && !tutorialActive ? 1 : 0,
      friction: 7,
      tension: 60,
      useNativeDriver: true,
    }).start();
  }, [isFabShrunk, tutorialActive, fabShrink]);

  const clearFabTimer = useCallback(() => {
    if (fabTimer.current) {
      clearTimeout(fabTimer.current);
      fabTimer.current = null;
    }
  }, []);

  const startFabTimer = useCallback(() => {
    clearFabTimer();
    fabTimer.current = setTimeout(() => setIsFabShrunk(true), FAB_INACTIVITY_MS);
  }, [clearFabTimer]);

  useEffect(() => {
    setIsFabShrunk(false);
    setMenuOpen(false);
    if (viewMode === 'list') {
      startFabTimer();
    } else {
      clearFabTimer();
    }
    return clearFabTimer;
  }, [viewMode, startFabTimer, clearFabTimer]);

  // Never shrunk with nothing to scroll past — the FAB is the way in.
  const fabEffectivelyShrunk =
    isFabShrunk && viewMode === 'list' && stores.length > 0;

  function handleFabPress() {
    if (fabEffectivelyShrunk) {
      setIsFabShrunk(false);
      startFabTimer();
    } else if (menuOpen) {
      setMenuOpen(false);
    } else {
      setMenuOpen(true);
      setIsFabShrunk(false);
      clearFabTimer();
    }
  }

  function handleListScroll(e: NativeSyntheticEvent<NativeScrollEvent>) {
    const {contentOffset, layoutMeasurement, contentSize} = e.nativeEvent;
    const atBottom =
      contentOffset.y + layoutMeasurement.height >= contentSize.height - 20;
    if (atBottom) {
      clearFabTimer();
      setIsFabShrunk(false);
    } else if (isUserScrolling.current && !isFabShrunk) {
      clearFabTimer();
      setIsFabShrunk(true);
    }
  }

  // ─── Store actions ────────────────────────────────────────────────────────

  // The Premium paywall sits above the tabs, so the navigate bubbles up to it.
  function openPaywall() {
    (navigation as NativeStackNavigationProp<any>).navigate('Subscription');
  }

  // Free-tier store limit: stores already over the limit are kept, but adding
  // another requires a subscription. The tour's stand-in stores don't count.
  function openAddStore() {
    if (
      tutorialActive ||
      canAddStore(hasPremiumAccess(currentUser), liveStores.length)
    ) {
      setShowAddSheet(true);
    } else {
      openPaywall();
    }
  }

  // The + menu's three entries, in the iOS order.
  const fabMenuItems: {
    icon: React.ComponentProps<typeof Icon>['name'];
    title: string;
    open: () => void;
  }[] = [
    {icon: 'cart-outline', title: 'Add Store', open: openAddStore},
    {icon: 'reader-outline', title: 'Add Recipe', open: () => setShowRecipes(true)},
    {icon: 'color-palette-outline', title: 'Colors', open: () => setShowColors(true)},
  ];

  async function handleSelectStore(storeName: string) {
    if (!firebaseUser || !currentUser) {return;}
    try {
      await storeService.addStore(
        currentUser.userId,
        currentUser.email,
        storeName,
      );
    } catch (err) {
      if (!isStoreLimitError(err)) {
        throw err;
      }
      setShowAddSheet(false);
      openPaywall();
    }
  }

  function openStore(item: UserStoreItem) {
    navigation.navigate('Reminders', {
      userStoreId: item.id,
      // Reminders for a store shared with this user live under the
      // owner's user_store, not this user's own doc.
      reminderStoreId: reminderStoreIdFor(item),
      storeName: item.store.name,
      storeId: item.store.id,
      permission: item.permission,
      isSharedStore: item.isShared,
      sharedWith: item.sharedWith,
      sharedFromName: item.sharedFromName,
    });
  }

  // Wording follows the iOS delete alert: say who else is affected and that
  // they'll be told.
  function deleteAlertMessage(item: UserStoreItem): string {
    const name = item.store.name;
    if (item.sharedFromName) {
      return `This will only remove ${name} from your account. ${item.sharedFromName} will be notified that you removed the shared store.`;
    }
    if (item.sharedWith && item.sharedWith.length > 0) {
      return `${name} is currently shared with ${item.sharedWith.join(', ')}. Deleting it will remove the store from their accounts too, and they will be notified.`;
    }
    if (item.permission === 'edit' && item.sharedStoreGroupId) {
      return `${name} is a shared store. Deleting it will remove it from all shared accounts, and they will be notified.`;
    }
    return `All reminders for ${name} will also be deleted.`;
  }

  function handleDeleteStore(item: UserStoreItem) {
    if (!firebaseUser || !currentUser) {return;}
    // A store the user was given is only removed from their own account;
    // deleting the reminders too is the owner's action alone.
    const isRecipient = isRecipientStore(item);
    Alert.alert(
      isRecipient ? `Remove ${item.store.name}?` : `Delete ${item.store.name}?`,
      deleteAlertMessage(item),
      [
        {text: 'Cancel', style: 'cancel'},
        {
          text: isRecipient ? 'Remove' : 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await storeService.removeStoreFromUser(item, currentUser);
            } catch (err: any) {
              Alert.alert('Error', err.message);
            }
          },
        },
      ],
    );
  }

  // ─── Ordering ─────────────────────────────────────────────────────────────

  // Shows the new order at once and writes it as every store's sortOrder —
  // the same field, and the same 0..n numbering, the iOS app writes.
  function applyOrder(newOrder: UserStoreItem[]) {
    pendingOrder.current = {
      ids: newOrder.map(s => s.id),
      until: Date.now() + 1500,
    };
    setStores(newOrder);
    storeService
      .reorderStores(newOrder.map((s, i) => ({id: s.id, order: i})))
      .catch(err => Alert.alert('Error', err.message));
  }

  // One tap permanently reorders the stores, most reminders first.
  function handleSortByReminderCount() {
    setIsReordering(false);
    const sorted = [...stores].sort(
      (a, b) => (b.store.reminderCount ?? 0) - (a.store.reminderCount ?? 0),
    );
    applyOrder(sorted);
  }

  function toggleViewMode() {
    const next: StoreViewMode = viewMode === 'list' ? 'float' : 'list';
    setIsReordering(false);
    setIsFloatEditMode(false);
    setViewMode(next);
    AsyncStorage.setItem(VIEW_MODE_KEY, next).catch(() => {});
  }

  function startReordering() {
    openRow.current?.close();
    setIsReordering(true);
  }

  function beginDrag(index: number) {
    drag.current = {index, hover: index};
    dragY.setValue(0);
    setDragIndex(index);
    setHoverIndex(index);
  }

  function moveDrag(dy: number) {
    const {index} = drag.current;
    if (index < 0 || rowHeight.current === 0) {return;}
    dragY.setValue(dy);
    const hover = Math.max(
      0,
      Math.min(stores.length - 1, index + Math.round(dy / rowHeight.current)),
    );
    if (hover !== drag.current.hover) {
      drag.current.hover = hover;
      setHoverIndex(hover);
    }
  }

  function endDrag() {
    const {index, hover} = drag.current;
    drag.current = {index: -1, hover: -1};
    dragY.setValue(0);
    setDragIndex(null);
    setHoverIndex(null);
    if (index < 0 || index === hover) {return;}
    const next = [...stores];
    const [moved] = next.splice(index, 1);
    next.splice(hover, 0, moved);
    applyOrder(next);
    // iOS drops out of edit mode shortly after a move lands.
    setTimeout(() => setIsReordering(false), 500);
  }

  // ─── On My Way ────────────────────────────────────────────────────────────

  function startOnMyWay(item: UserStoreItem) {
    // Started with the card rather than after it, so the card can say how far
    // away the user is. The token drops a result that lands after the user
    // has backed out or moved on to another store.
    const token = ++estimateToken.current;
    setOnMyWayStore(item);
    setEstimate(null);
    setEstimateUnavailable(false);
    setIsEstimating(true);
    onMyWayService
      .estimateTravelTime(item.store.name)
      .then(result => {
        if (estimateToken.current === token) {
          setEstimate(result);
        }
      })
      .catch(() => {
        if (estimateToken.current === token) {
          setEstimateUnavailable(true);
        }
      })
      .finally(() => {
        if (estimateToken.current === token) {
          setIsEstimating(false);
        }
      });
  }

  function cancelOnMyWay() {
    estimateToken.current++;
    setOnMyWayStore(null);
    setEstimate(null);
    setIsEstimating(false);
    setEstimateUnavailable(false);
  }

  async function sendOnMyWay() {
    const item = onMyWayStore;
    if (!item) {return;}
    if (!currentUser) {
      cancelOnMyWay();
      Alert.alert('Unable to Send', 'User data not available.');
      return;
    }
    // The number the card showed is the one that goes out, so the user and
    // their contacts are told the same thing.
    const shown = estimate?.storeName === item.store.name ? estimate : null;
    cancelOnMyWay();
    setIsSending(true);
    try {
      const travel =
        shown ?? (await onMyWayService.estimateTravelTime(item.store.name));
      await onMyWayService.sendNotification({
        item,
        estimate: travel,
        currentUserId: currentUser.userId,
        currentUserName: currentUser.name,
      });
      setIsSending(false);
      Alert.alert(
        'Notification Sent',
        `Your shared contacts have been notified that you're about ${formattedTravelTime(
          travel.travelTimeMinutes,
        )} from ${item.store.name}.`,
      );
    } catch (err: any) {
      setIsSending(false);
      Alert.alert('Unable to Send', err?.message ?? 'Something went wrong.');
    }
  }

  // ─── Rows ─────────────────────────────────────────────────────────────────

  // Swipe-left actions, mirroring the iOS store list: Share (owners and editors
  // only — a view-only recipient has nothing to pass on) then Delete/Remove.
  function renderRightActions(item: UserStoreItem, row: Swipeable | null) {
    const isRecipient = isRecipientStore(item);
    const canShare = item.permission !== 'view';

    function run(action: () => void) {
      row?.close();
      action();
    }

    return (
      <View style={styles.swipeActions}>
        {canShare && (
          <TouchableOpacity
            style={[styles.swipeAction, {backgroundColor: Colors.blue}]}
            onPress={() => run(() => setStoreToShare(item))}
            activeOpacity={0.8}>
            <Icon name="share-outline" size={22} color="#fff" />
            <Text style={styles.swipeActionText}>Share</Text>
          </TouchableOpacity>
        )}
        <TouchableOpacity
          style={[styles.swipeAction, {backgroundColor: Colors.red}]}
          onPress={() => run(() => handleDeleteStore(item))}
          activeOpacity={0.8}>
          <Icon
            name={isRecipient ? 'close-circle-outline' : 'trash-outline'}
            size={22}
            color="#fff"
          />
          <Text style={styles.swipeActionText}>
            {isRecipient ? 'Remove' : 'Delete'}
          </Text>
        </TouchableOpacity>
      </View>
    );
  }

  // Swipe-right action, shared stores only: tell everyone else on the store
  // that you're heading there.
  function renderLeftActions(item: UserStoreItem, row: Swipeable | null) {
    return (
      <View style={styles.swipeActions}>
        <TouchableOpacity
          style={[
            styles.swipeAction,
            styles.swipeActionLeading,
            {backgroundColor: Colors.green},
          ]}
          onPress={() => {
            row?.close();
            startOnMyWay(item);
          }}
          activeOpacity={0.8}>
          <Icon name="car" size={22} color="#fff" />
          <Text style={styles.swipeActionText}>On My Way</Text>
        </TouchableOpacity>
      </View>
    );
  }

  function renderStoreItem({item, index}: {item: UserStoreItem; index: number}) {
    let row: Swipeable | null = null;

    // Where this row sits while another one is being dragged past it.
    let shift = 0;
    if (dragIndex !== null && hoverIndex !== null && index !== dragIndex) {
      if (index > dragIndex && index <= hoverIndex) {
        shift = -rowHeight.current;
      } else if (index < dragIndex && index >= hoverIndex) {
        shift = rowHeight.current;
      }
    }

    return (
      <ReorderableRow
        isDragged={dragIndex === index}
        dragActive={dragIndex !== null}
        shift={shift}
        dragY={dragY}
        onLayout={h => {
          if (index === 0) {
            rowHeight.current = h;
          }
        }}>
        <Swipeable
          ref={ref => {
            row = ref;
          }}
          enabled={!isReordering}
          renderRightActions={() => renderRightActions(item, row)}
          renderLeftActions={
            item.isShared ? () => renderLeftActions(item, row) : undefined
          }
          overshootRight={false}
          overshootLeft={false}
          rightThreshold={40}
          leftThreshold={40}
          onSwipeableWillOpen={() => {
            if (openRow.current && openRow.current !== row) {
              openRow.current.close();
            }
            openRow.current = row;
          }}>
          <TouchableOpacity
            style={[styles.storeCard, cardStyle(scheme)]}
            onPress={() => !isReordering && openStore(item)}
            onLongPress={startReordering}
            delayLongPress={500}
            disabled={isReordering}
            activeOpacity={0.75}>
            <StoreRowContent
              item={item}
              scheme={scheme}
              dragHandle={
                isReordering ? (
                  <DragHandle
                    index={index}
                    onStart={beginDrag}
                    onMove={moveDrag}
                    onEnd={endDrag}
                    color={textSecondary(scheme)}
                  />
                ) : null
              }
            />
          </TouchableOpacity>
        </Swipeable>
      </ReorderableRow>
    );
  }

  function renderEmpty() {
    return (
      <View style={styles.emptyContainer}>
        <View style={[styles.emptyIconBg, {backgroundColor: Colors.blue + '26'}]}>
          <Icon name="cart-outline" size={52} color={Colors.blue} />
        </View>
        <Text style={[styles.emptyTitle, {color: textPrimary(scheme)}]}>
          No stores yet
        </Text>
        <Text style={[styles.emptySubtitle, {color: textSecondary(scheme)}]}>
          Add the stores you shop at and Allim will remind you what you need
          when you get there.
        </Text>
        <View style={styles.steps}>
          {[
            'Tap the + button below',
            'Choose "Add Store" and search nearby',
            'Set reminders for items you need',
          ].map((step, i) => (
            <View key={i} style={styles.stepRow}>
              <View style={styles.stepBadge}>
                <Text style={styles.stepNum}>{i + 1}</Text>
              </View>
              <Text style={[styles.stepText, {color: textSecondary(scheme)}]}>
                {step}
              </Text>
            </View>
          ))}
        </View>
      </View>
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  const showingDone =
    (isReordering && viewMode === 'list') ||
    (isFloatEditMode && viewMode === 'float');

  function renderHeader() {
    return (
      <View style={styles.header}>
        {/* The tab bar already says Stores, so the title is a greeting. */}
        <View style={styles.greeting}>
          <Text style={[styles.greetingHi, {color: textSecondary(scheme)}]}>
            Hi,
          </Text>
          <Text
            style={[styles.greetingName, {color: textPrimary(scheme)}]}
            numberOfLines={1}
            adjustsFontSizeToFit
            minimumFontScale={0.6}>
            {currentUser?.name ?? 'there'}
          </Text>
        </View>

        <View {...profileTarget}>
          <TouchableOpacity
            onPress={() => navigation.navigate('Profile')}
            accessibilityLabel="Profile">
            <ProfileAvatar
              url={currentUser?.profilePictureURL}
              name={currentUser?.name}
              size={44}
            />
          </TouchableOpacity>
        </View>

        {showingDone ? (
          <TouchableOpacity
            style={styles.doneButton}
            onPress={() => {
              setIsReordering(false);
              setIsFloatEditMode(false);
            }}
            activeOpacity={0.85}>
            <Text style={styles.doneText}>Done</Text>
          </TouchableOpacity>
        ) : stores.length > 0 ? (
          <View {...toolbarTarget} style={styles.headerToolbar}>
            <HeaderButton
              icon="swap-vertical"
              onPress={handleSortByReminderCount}
              label="Sort by reminder count"
            />
            <HeaderButton
              icon={viewMode === 'list' ? 'grid-outline' : 'list'}
              onPress={toggleViewMode}
              label={
                viewMode === 'list' ? 'Switch to grid view' : 'Switch to list view'
              }
            />
          </View>
        ) : null}
      </View>
    );
  }

  // ─── Layout ───────────────────────────────────────────────────────────────

  const fabScale = fabShrink.interpolate({
    inputRange: [0, 1],
    outputRange: [1, FAB_SHRUNK_SIZE / FAB_SIZE],
  });
  // Shrinks toward its bottom-right corner rather than its centre.
  const fabOffset = fabShrink.interpolate({
    inputRange: [0, 1],
    outputRange: [0, (FAB_SIZE - FAB_SHRUNK_SIZE) / 2],
  });
  const fabIconOpacity = fabShrink.interpolate({
    inputRange: [0, 0.5],
    outputRange: [1, 0],
    extrapolate: 'clamp',
  });

  return (
    <View style={{flex: 1}}>
      {/* The app gradient, or whatever the user picked under Colors. */}
      <SurfaceBackground surface="stores" />
      {/* No bottom edge: the tab bar below already clears the system navigation
          bar. Insetting here too leaves an empty strip that clips the list. */}
      <SafeAreaView style={{flex: 1}} edges={['top', 'left', 'right']}>
        {loading ? (
          // The greeting needs a name and the list needs stores, so until both
          // are in, the whole screen is the loading screen.
          <View style={styles.center}>
            <ActivityIndicator size="large" color={Colors.blue} />
          </View>
        ) : (
          <>
            {renderHeader()}

            {stores.length === 0 ? (
              renderEmpty()
            ) : viewMode === 'list' ? (
              <FlatList
                data={stores}
                renderItem={renderStoreItem}
                keyExtractor={item => item.id}
                contentContainerStyle={styles.list}
                scrollEnabled={dragIndex === null}
                extraData={[dragIndex, hoverIndex, isReordering]}
                onScroll={handleListScroll}
                scrollEventThrottle={32}
                onScrollBeginDrag={() => {
                  isUserScrolling.current = true;
                }}
                onScrollEndDrag={() => {
                  isUserScrolling.current = false;
                }}
              />
            ) : (
              <StoreFloatView
                stores={stores}
                onStoreTap={openStore}
                onStoreDelete={handleDeleteStore}
                onReorder={applyOrder}
                isEditMode={isFloatEditMode}
                setEditMode={setIsFloatEditMode}
                bottomInset={FAB_SIZE + Spacing.lg}
              />
            )}
          </>
        )}

        {/* Tap outside to close menu */}
        {menuOpen && (
          <TouchableOpacity
            style={StyleSheet.absoluteFill}
            onPress={() => setMenuOpen(false)}
            activeOpacity={1}
          />
        )}

        {/* FAB — held back while the stores load, when there is nothing to
            add to yet. */}
        {!loading && (
          <View style={styles.fabContainer} pointerEvents="box-none">
            {menuOpen && (
              <View style={styles.fabMenu}>
                {fabMenuItems.map(item => (
                  <TouchableOpacity
                    key={item.title}
                    style={[
                      styles.fabMenuItem,
                      {backgroundColor: cardBackground(scheme)},
                    ]}
                    onPress={() => {
                      setMenuOpen(false);
                      item.open();
                    }}>
                    <Icon name={item.icon} size={20} color={Colors.blue} />
                    <Text style={[styles.fabMenuText, {color: textPrimary(scheme)}]}>
                      {item.title}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
            )}

            <Animated.View
              {...fabTarget}
              style={{
                transform: [
                  {translateX: fabOffset},
                  {translateY: fabOffset},
                  {scale: fabScale},
                ],
              }}>
              <TouchableOpacity
                style={styles.fab}
                onPress={handleFabPress}
                activeOpacity={0.85}
                accessibilityLabel={menuOpen ? 'Close menu' : 'Add'}>
                <Animated.View style={{opacity: fabIconOpacity}}>
                  <Icon
                    name={menuOpen ? 'close' : 'add'}
                    size={28}
                    color="#fff"
                  />
                </Animated.View>
              </TouchableOpacity>
            </Animated.View>
          </View>
        )}
      </SafeAreaView>

      {/* Add Store Sheet */}
      <AddStoreSheet
        visible={showAddSheet}
        onClose={() => setShowAddSheet(false)}
        onSelectStore={handleSelectStore}
        existingStores={stores}
      />

      <RecipesSheet visible={showRecipes} onClose={() => setShowRecipes(false)} />

      <BackgroundPickerSheet
        visible={showColors}
        surface="stores"
        title="Stores"
        onClose={() => setShowColors(false)}
      />

      {/* Share Store Sheet */}
      <ShareStoreSheet
        visible={!!storeToShare}
        item={storeToShare}
        onClose={() => setStoreToShare(null)}
      />

      <OnMyWayDialog
        storeName={onMyWayStore?.store.name ?? null}
        estimate={estimate}
        isCalculating={isEstimating}
        isUnavailable={estimateUnavailable}
        onSend={sendOnMyWay}
        onCancel={cancelOnMyWay}
      />

      {isSending && (
        <View style={styles.sendingOverlay}>
          <View
            style={[styles.sendingCard, {backgroundColor: sheetBackground(scheme)}]}>
            <ActivityIndicator size="large" color={Colors.blue} />
            <Text style={[styles.sendingText, {color: textSecondary(scheme)}]}>
              Sending…
            </Text>
          </View>
        </View>
      )}
    </View>
  );
}

// ─── Pieces ──────────────────────────────────────────────────────────────────

function HeaderButton({
  icon,
  onPress,
  label,
}: {
  icon: React.ComponentProps<typeof Icon>['name'];
  onPress: () => void;
  label: string;
}) {
  return (
    <TouchableOpacity
      style={styles.headerButton}
      onPress={onPress}
      accessibilityLabel={label}
      activeOpacity={0.75}>
      <Icon name={icon} size={20} color={Colors.blue} />
    </TouchableOpacity>
  );
}

// Logo, name, shared marker and reminder count — the iOS StoreItemView.
function StoreRowContent({
  item,
  scheme,
  dragHandle,
}: {
  item: UserStoreItem;
  scheme: ReturnType<typeof useColorScheme>;
  dragHandle: React.ReactNode;
}) {
  const count = item.store.reminderCount ?? 0;
  return (
    <View style={styles.storeRow}>
      <StoreLogo storeName={item.store.name} size={48} />

      <View style={styles.storeInfo}>
        <Text
          style={[styles.storeName, {color: textPrimary(scheme)}]}
          numberOfLines={1}>
          {item.store.name}
        </Text>
        {item.sharedFromName ? (
          <Text
            style={[styles.storeSubtitle, {color: textSecondary(scheme)}]}
            numberOfLines={1}>
            Shared by {item.sharedFromName}
          </Text>
        ) : null}
      </View>

      {/* Shared either way — given to someone, or given by someone. */}
      {item.isShared && (
        <View style={[styles.sharedBadge, {backgroundColor: Colors.green + '2E'}]}>
          <Icon name="people" size={14} color={Colors.green} />
        </View>
      )}

      {count > 0 && (
        <View style={styles.countBadge}>
          <Text style={styles.countText}>{count}</Text>
        </View>
      )}

      {dragHandle}
    </View>
  );
}

// The grip shown on each row while reordering. Dragging it moves the row;
// the rest of the list stays scrollable.
function DragHandle({
  index,
  onStart,
  onMove,
  onEnd,
  color,
}: {
  index: number;
  onStart: (index: number) => void;
  onMove: (dy: number) => void;
  onEnd: () => void;
  color: string;
}) {
  const latest = useRef({index, onStart, onMove, onEnd});
  latest.current = {index, onStart, onMove, onEnd};

  const pan = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: () => true,
      onPanResponderGrant: () => latest.current.onStart(latest.current.index),
      onPanResponderMove: (_, g) => latest.current.onMove(g.dy),
      onPanResponderRelease: () => latest.current.onEnd(),
      onPanResponderTerminate: () => latest.current.onEnd(),
      onPanResponderTerminationRequest: () => false,
    }),
  ).current;

  return (
    <View
      {...pan.panHandlers}
      style={styles.dragHandle}
      hitSlop={{top: 10, bottom: 10, left: 10, right: 10}}
      accessibilityLabel="Reorder">
      <Icon name="reorder-three-outline" size={26} color={color} />
    </View>
  );
}

// Moves a row out of the way of the one being dragged, or under the finger if
// it is the one being dragged.
function ReorderableRow({
  isDragged,
  dragActive,
  shift,
  dragY,
  onLayout,
  children,
}: {
  isDragged: boolean;
  dragActive: boolean;
  shift: number;
  dragY: Animated.Value;
  onLayout: (height: number) => void;
  children: React.ReactNode;
}) {
  const offset = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (dragActive) {
      Animated.spring(offset, {
        toValue: shift,
        friction: 8,
        tension: 80,
        useNativeDriver: true,
      }).start();
    } else {
      // The drop re-renders the rows in their new order, so any leftover
      // offset would put a row in the wrong place — snap it home.
      offset.stopAnimation();
      offset.setValue(0);
    }
  }, [dragActive, shift, offset]);

  return (
    <Animated.View
      onLayout={e => onLayout(e.nativeEvent.layout.height)}
      style={[
        isDragged && styles.draggedRow,
        {transform: [{translateY: isDragged ? dragY : offset}]},
      ]}>
      {children}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: Spacing.lg - 4,
    paddingTop: Spacing.sm,
    paddingBottom: 14,
  },
  greeting: {
    flex: 1,
  },
  greetingHi: {
    fontSize: 15,
    fontWeight: '600',
  },
  greetingName: {
    fontSize: 34,
    fontWeight: '700',
  },
  headerToolbar: {
    flexDirection: 'row',
    gap: 10,
  },
  headerButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: Colors.blue + '1A',
    alignItems: 'center',
    justifyContent: 'center',
  },
  doneButton: {
    height: 44,
    paddingHorizontal: 22,
    borderRadius: 22,
    backgroundColor: Colors.blue,
    alignItems: 'center',
    justifyContent: 'center',
  },
  doneText: {
    color: Colors.white,
    fontSize: 16,
    fontWeight: '700',
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  list: {
    paddingHorizontal: Spacing.md,
    paddingBottom: 100,
  },
  storeCard: {
    paddingHorizontal: 14,
    paddingVertical: 12,
    marginBottom: 4,
  },
  storeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  storeInfo: {
    flex: 1,
    marginLeft: 4,
  },
  storeName: {
    fontSize: 17,
    fontWeight: '600',
  },
  storeSubtitle: {
    fontSize: 13,
    marginTop: 2,
  },
  sharedBadge: {
    width: 30,
    height: 30,
    borderRadius: 15,
    alignItems: 'center',
    justifyContent: 'center',
  },
  countBadge: {
    minWidth: 28,
    height: 28,
    borderRadius: 14,
    paddingHorizontal: 8,
    backgroundColor: Colors.blue,
    alignItems: 'center',
    justifyContent: 'center',
  },
  countText: {
    color: Colors.white,
    fontSize: 14,
    fontWeight: '700',
  },
  dragHandle: {
    paddingLeft: 6,
    paddingVertical: 4,
  },
  draggedRow: {
    zIndex: 10,
    elevation: 10,
    opacity: 0.95,
  },
  // The actions sit behind the card, so their vertical margins have to match
  // the card's (cardStyle's marginVertical plus storeCard's marginBottom).
  swipeActions: {
    flexDirection: 'row',
    marginTop: 4,
    marginBottom: 8,
  },
  swipeAction: {
    width: 76,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
    borderRadius: Radius.lg,
    marginLeft: Spacing.sm,
  },
  swipeActionLeading: {
    width: 92,
    marginLeft: 0,
    marginRight: Spacing.sm,
  },
  swipeActionText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
  emptyContainer: {
    flex: 1,
    alignItems: 'center',
    paddingTop: 60,
    paddingHorizontal: Spacing.xl,
  },
  emptyIconBg: {
    width: 120,
    height: 120,
    borderRadius: 60,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: Spacing.lg,
  },
  emptyTitle: {
    fontSize: 22,
    fontWeight: '600',
    marginBottom: Spacing.sm,
  },
  emptySubtitle: {
    fontSize: 16,
    textAlign: 'center',
    lineHeight: 22,
    marginBottom: Spacing.xl,
  },
  steps: {
    width: '100%',
  },
  stepRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: Spacing.md,
  },
  stepBadge: {
    width: 30,
    height: 30,
    borderRadius: 15,
    backgroundColor: Colors.blue + '26',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 14,
  },
  stepNum: {
    color: Colors.blue,
    fontWeight: '600',
    fontSize: 14,
  },
  stepText: {
    fontSize: 15,
    flex: 1,
  },
  fabContainer: {
    position: 'absolute',
    bottom: 24,
    right: 24,
    alignItems: 'flex-end',
  },
  fabMenu: {
    marginBottom: Spacing.md,
  },
  fabMenuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    width: 210,
    height: 56,
    paddingHorizontal: 18,
    borderRadius: 20,
    marginBottom: Spacing.sm,
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 2},
    shadowOpacity: 0.15,
    shadowRadius: 4,
    elevation: 3,
  },
  fabMenuText: {
    marginLeft: 12,
    fontSize: 16,
    fontWeight: '600',
  },
  fab: {
    width: FAB_SIZE,
    height: FAB_SIZE,
    borderRadius: FAB_SIZE / 2,
    backgroundColor: Colors.blue,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 4},
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 6,
  },
  sendingOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.3)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  sendingCard: {
    padding: 24,
    borderRadius: Radius.xl,
    alignItems: 'center',
    gap: 12,
  },
  sendingText: {
    fontSize: 15,
  },
});
