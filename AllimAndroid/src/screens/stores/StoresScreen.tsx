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
import Icon from '../../components/AppIcon';
import LinearGradient from 'react-native-linear-gradient';

import GradientBackground from '../../components/GradientBackground';
import ProfileAvatar from '../../components/ProfileAvatar';
import AddStoreSheet from './AddStoreSheet';
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
import {UserStoreItem} from '../../models';
import {StoresStackParamList} from '../../navigation/AppNavigator';

type Nav = NativeStackNavigationProp<StoresStackParamList, 'StoresList'>;

export default function StoresScreen() {
  const scheme = useColorScheme();
  const navigation = useNavigation<Nav>();
  const {currentUser, firebaseUser} = useSession();

  const [stores, setStores] = useState<UserStoreItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddSheet, setShowAddSheet] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  const fabScale = useRef(new Animated.Value(1)).current;

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
    const isShared = item.isShared;
    Alert.alert(
      isShared ? `Remove ${item.store.name}?` : `Delete ${item.store.name}?`,
      isShared
        ? 'This will remove the store from your account only.'
        : 'All reminders will also be deleted.',
      [
        {text: 'Cancel', style: 'cancel'},
        {
          text: isShared ? 'Remove' : 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              if (isShared) {
                await storeService.removeSharedStore(item.id);
              } else {
                await storeService.deleteStore(
                  item.id,
                  currentUser.userId,
                  currentUser.email,
                );
              }
            } catch (err: any) {
              Alert.alert('Error', err.message);
            }
          },
        },
      ],
    );
  }

  function renderStoreItem({item}: {item: UserStoreItem}) {
    const reminderCount = item.store.reminderCount ?? 0;
    return (
      <TouchableOpacity
        style={[styles.storeCard, cardStyle(scheme)]}
        onPress={() =>
          navigation.navigate('Reminders', {
            userStoreId: item.id,
            storeName: item.store.name,
            storeId: item.store.id,
            permission: item.permission,
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
              {item.isShared ? ' · Shared' : ''}
            </Text>
          </View>

          <View style={styles.storeRight}>
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
