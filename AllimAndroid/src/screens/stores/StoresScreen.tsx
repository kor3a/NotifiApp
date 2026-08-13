import React, {useEffect, useState, useRef} from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Animated,
  useColorScheme,
  ActivityIndicator,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {useNavigation} from '@react-navigation/native';
import {NativeStackNavigationProp} from '@react-navigation/native-stack';
import {Swipeable} from 'react-native-gesture-handler';
import Icon from '../../components/AppIcon';
import LinearGradient from 'react-native-linear-gradient';

import GradientBackground from '../../components/GradientBackground';
import ProfileAvatar from '../../components/ProfileAvatar';
import AddStoreSheet from './AddStoreSheet';
import ShareStoreSheet from './ShareStoreSheet';
import {
  Colors,
  Spacing,
  Radius,
  cardStyle,
  textPrimary,
  textSecondary,
  cardBackground,
} from '../../theme/AppTheme';
import {useSession} from '../../context/SessionContext';
import {storeService} from '../../services/storeService';
import {
  UserStoreItem,
  isRecipientStore,
  reminderStoreIdFor,
} from '../../models';
import {StoresStackParamList} from '../../navigation/AppNavigator';

type Nav = NativeStackNavigationProp<StoresStackParamList, 'StoresList'>;

export default function StoresScreen() {
  const scheme = useColorScheme();
  const navigation = useNavigation<Nav>();
  const {currentUser, firebaseUser} = useSession();

  const [stores, setStores] = useState<UserStoreItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddSheet, setShowAddSheet] = useState(false);
  const [storeToShare, setStoreToShare] = useState<UserStoreItem | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);

  const fabScale = useRef(new Animated.Value(1)).current;
  // Only one row stays open at a time, the way a list row behaves on iOS.
  const openRow = useRef<Swipeable | null>(null);

  useEffect(() => {
    if (!firebaseUser || !currentUser) {return;}
    const unsub = storeService.subscribeToUserStores(
      currentUser.userId,
      currentUser.email,
      items => {
        setStores(items);
        setLoading(false);
      },
    );
    return unsub;
  }, [firebaseUser, currentUser]);

  function handleAddStore() {
    setMenuOpen(false);
    setShowAddSheet(true);
  }

  async function handleSelectStore(storeName: string) {
    if (!firebaseUser || !currentUser) {return;}
    await storeService.addStore(
      currentUser.userId,
      currentUser.email,
      storeName,
    );
  }

  async function handleDeleteStore(item: UserStoreItem) {
    if (!firebaseUser || !currentUser) {return;}
    // A store the user was given is only removed from their own account;
    // deleting the reminders too is the owner's action alone. An owner who is
    // sharing the store deletes it for their recipients as well, so the prompt
    // says so.
    const isRecipient = isRecipientStore(item);
    const sharedWithOthers = !isRecipient && (item.sharedWith?.length ?? 0) > 0;
    Alert.alert(
      isRecipient ? `Remove ${item.store.name}?` : `Delete ${item.store.name}?`,
      isRecipient
        ? 'This will remove the store from your account only.'
        : sharedWithOthers
        ? 'All reminders will also be deleted, and the store will be removed from everyone you shared it with.'
        : 'All reminders will also be deleted.',
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

  function renderStoreItem({item}: {item: UserStoreItem}) {
    const reminderCount = item.store.reminderCount ?? 0;
    let row: Swipeable | null = null;
    return (
      <Swipeable
        ref={ref => {
          row = ref;
        }}
        renderRightActions={() => renderRightActions(item, row)}
        overshootRight={false}
        rightThreshold={40}
        onSwipeableWillOpen={() => {
          if (openRow.current && openRow.current !== row) {
            openRow.current.close();
          }
          openRow.current = row;
        }}>
        <TouchableOpacity
          style={[styles.storeCard, cardStyle(scheme)]}
          onPress={() =>
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
            })
          }
          onLongPress={() => handleDeleteStore(item)}
          activeOpacity={0.75}>
          <View style={styles.storeRow}>
            {/* Store icon */}
            <LinearGradient
              colors={[Colors.blue + '33', Colors.purple + '33']}
              style={styles.storeIconBg}>
              <Icon name="cart" size={22} color={Colors.blue} />
            </LinearGradient>

            <View style={styles.storeInfo}>
              <Text style={[styles.storeName, {color: textPrimary(scheme)}]}>
                {item.store.name}
              </Text>
              <Text style={[styles.storeSubtitle, {color: textSecondary(scheme)}]}>
                {reminderCount === 0
                  ? 'No reminders'
                  : `${reminderCount} reminder${reminderCount !== 1 ? 's' : ''}`}
                {item.sharedFromName ? ` · Shared by ${item.sharedFromName}` : ''}
              </Text>
            </View>

            <View style={styles.storeRight}>
              {/* Shared either way — this user gave the store to someone, or
                  someone gave it to them. Matches the iOS row's person icon. */}
              {item.isShared && (
                <Icon
                  name="people"
                  size={17}
                  color={Colors.blue}
                  style={{marginRight: 6}}
                />
              )}
              {item.permission === 'view' && (
                <Icon name="eye-outline" size={16} color={textSecondary(scheme)} style={{marginRight: 4}} />
              )}
              {item.permission === 'edit' && (
                <Icon name="pencil-outline" size={16} color={Colors.blue} style={{marginRight: 4}} />
              )}
              <Icon name="chevron-forward" size={18} color={textSecondary(scheme)} />
            </View>
          </View>
        </TouchableOpacity>
      </Swipeable>
    );
  }

  function renderEmpty() {
    return (
      <View style={styles.emptyContainer}>
        <LinearGradient
          colors={[Colors.blue + '26', Colors.purple + '26']}
          style={styles.emptyIconBg}>
          {/* iOS uses cart.badge.plus here; Ionicons' nearest cart-with-a-plus
              is bag-add-outline. */}
          <Icon name="bag-add-outline" size={52} color={Colors.blue} />
        </LinearGradient>
        <Text style={[styles.emptyTitle, {color: textPrimary(scheme)}]}>
          No Stores Yet
        </Text>
        <Text style={[styles.emptySubtitle, {color: textSecondary(scheme)}]}>
          Add your favourite grocery stores{'\n'}to start managing your shopping reminders.
        </Text>
        <View style={styles.steps}>
          {[
            'Tap the + button below',
            'Choose "Add Store" and search',
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

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={[styles.headerTitle, {color: textPrimary(scheme)}]}>
            My Stores
          </Text>
          <TouchableOpacity onPress={() => navigation.navigate('Profile')}>
            <ProfileAvatar
              url={currentUser?.profilePictureURL}
              name={currentUser?.name}
              size={34}
            />
          </TouchableOpacity>
        </View>

        {/* Content */}
        {loading ? (
          <View style={styles.center}>
            <ActivityIndicator size="large" color={Colors.blue} />
          </View>
        ) : (
          <FlatList
            data={stores}
            renderItem={renderStoreItem}
            keyExtractor={item => item.id}
            contentContainerStyle={styles.list}
            ListEmptyComponent={renderEmpty}
          />
        )}

{/* Tap outside to close menu */}
        {menuOpen && (
          <TouchableOpacity
            style={StyleSheet.absoluteFill}
            onPress={() => setMenuOpen(false)}
            activeOpacity={1}
          />
        )}
        
        {/* FAB */}
        <View style={styles.fabContainer}>
          {menuOpen && (
            <View style={styles.fabMenu}>
              <TouchableOpacity
                style={[styles.fabMenuItem, {backgroundColor: cardBackground(scheme)}]}
                onPress={handleAddStore}>
                <Icon name="bag-add-outline" size={20} color={textPrimary(scheme)} />
                <Text style={[styles.fabMenuText, {color: textPrimary(scheme)}]}>
                  Add Store
                </Text>
              </TouchableOpacity>
            </View>
          )}

          <TouchableOpacity
            style={styles.fab}
            onPress={() => setMenuOpen(v => !v)}
            activeOpacity={0.85}>
            <Icon
              name={menuOpen ? 'close' : 'add'}
              size={28}
              color="#fff"
            />
          </TouchableOpacity>
        </View>

        
      </SafeAreaView>

      {/* Add Store Sheet */}
      <AddStoreSheet
        visible={showAddSheet}
        onClose={() => setShowAddSheet(false)}
        onSelectStore={handleSelectStore}
        existingStores={stores}
      />

      {/* Share Store Sheet */}
      <ShareStoreSheet
        visible={!!storeToShare}
        item={storeToShare}
        onClose={() => setStoreToShare(null)}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
  },
  headerTitle: {
    fontSize: 28,
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
    padding: Spacing.md,
    marginBottom: 4,
  },
  storeRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  storeIconBg: {
    width: 44,
    height: 44,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: Spacing.md,
  },
  storeInfo: {
    flex: 1,
  },
  storeName: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 2,
  },
  storeSubtitle: {
    fontSize: 13,
  },
  storeRight: {
    flexDirection: 'row',
    alignItems: 'center',
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
  swipeActionText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
  emptyContainer: {
    flex: 1,
    alignItems: 'center',
    paddingTop: 80,
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
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: Colors.blue + '26',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: Spacing.md,
  },
  stepNum: {
    color: Colors.blue,
    fontWeight: '600',
    fontSize: 13,
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
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm + 4,
    borderRadius: Radius.lg,
    marginBottom: Spacing.sm,
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 2},
    shadowOpacity: 0.15,
    shadowRadius: 4,
    elevation: 3,
  },
  fabMenuText: {
    marginLeft: Spacing.sm,
    fontSize: 17,
    fontWeight: '500',
  },
  fab: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: Colors.blue,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 4},
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 6,
  },
});
