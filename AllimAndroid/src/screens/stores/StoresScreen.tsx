import React, {useEffect, useState, useRef} from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Modal,
  TextInput,
  Animated,
  useColorScheme,
  ActivityIndicator,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {useNavigation} from '@react-navigation/native';
import {NativeStackNavigationProp} from '@react-navigation/native-stack';
import Icon from 'react-native-vector-icons/Ionicons';
import LinearGradient from 'react-native-linear-gradient';

import GradientBackground from '../../components/GradientBackground';
import ProfileAvatar from '../../components/ProfileAvatar';
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
import {UserStoreItem, reminderStoreIdFor} from '../../models';
import {StoresStackParamList} from '../../navigation/AppNavigator';

type Nav = NativeStackNavigationProp<StoresStackParamList, 'StoresList'>;

// Subtitle suffix describing the store's sharing status.
function sharingLabel(item: UserStoreItem): string {
  // Recipient: this store was shared to the current user.
  if (item.sharedFromName) {
    return ` · Shared by ${item.sharedFromName}`;
  }
  // Owner: this store is being shared with one or more people.
  const names = item.sharedWith ?? [];
  if (names.length === 1) {
    return ` · Shared with ${names[0]}`;
  }
  if (names.length > 1) {
    return ` · Shared with ${names.length} people`;
  }
  return '';
}

export default function StoresScreen() {
  const scheme = useColorScheme();
  const navigation = useNavigation<Nav>();
  const {currentUser, firebaseUser} = useSession();

  const [stores, setStores] = useState<UserStoreItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [newStoreName, setNewStoreName] = useState('');
  const [addLoading, setAddLoading] = useState(false);
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
    setNewStoreName('');
    setShowAddModal(true);
  }

  async function submitAddStore() {
    if (!newStoreName.trim()) {return;}
    if (!firebaseUser || !currentUser) {return;}
    setAddLoading(true);
    try {
      await storeService.addStore(
        currentUser.userId,
        currentUser.email,
        newStoreName.trim(),
      );
      setShowAddModal(false);
    } catch (err: any) {
      Alert.alert('Error', err.message ?? 'Failed to add store.');
    } finally {
      setAddLoading(false);
    }
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
              {sharingLabel(item)}
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
          <Icon name="cart-outline" size={52} color={Colors.blue} />
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

        {/* FAB */}
        <View style={styles.fabContainer}>
          {menuOpen && (
            <View style={styles.fabMenu}>
              <TouchableOpacity
                style={[styles.fabMenuItem, {backgroundColor: cardBackground(scheme)}]}
                onPress={handleAddStore}>
                <Icon name="cart-outline" size={20} color={textPrimary(scheme)} />
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

        {/* Tap outside to close menu */}
        {menuOpen && (
          <TouchableOpacity
            style={StyleSheet.absoluteFill}
            onPress={() => setMenuOpen(false)}
            activeOpacity={1}
          />
        )}
      </SafeAreaView>

      {/* Add Store Modal */}
      <Modal
        visible={showAddModal}
        transparent
        animationType="slide"
        onRequestClose={() => setShowAddModal(false)}>
        <View style={styles.modalOverlay}>
          <View style={[styles.modalCard, {backgroundColor: cardBackground(scheme)}]}>
            <Text style={[styles.modalTitle, {color: textPrimary(scheme)}]}>
              Add Store
            </Text>
            <TextInput
              placeholder="Store name (e.g. Walmart)"
              placeholderTextColor={textSecondary(scheme)}
              value={newStoreName}
              onChangeText={setNewStoreName}
              style={[styles.modalInput, {color: textPrimary(scheme), borderColor: Colors.blue + '44'}]}
              autoFocus
              onSubmitEditing={submitAddStore}
            />
            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={[styles.modalBtn, {backgroundColor: Colors.blue + '1A'}]}
                onPress={() => setShowAddModal(false)}>
                <Text style={{color: Colors.blue, fontSize: 16, fontWeight: '600'}}>
                  Cancel
                </Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalBtn, {backgroundColor: Colors.blue}]}
                onPress={submitAddStore}
                disabled={addLoading}>
                {addLoading ? (
                  <ActivityIndicator color="#fff" />
                ) : (
                  <Text style={{color: '#fff', fontSize: 16, fontWeight: '600'}}>
                    Add
                  </Text>
                )}
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
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
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'flex-end',
  },
  modalCard: {
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    padding: Spacing.lg,
    paddingBottom: 40,
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: '700',
    marginBottom: Spacing.lg,
    textAlign: 'center',
  },
  modalInput: {
    borderWidth: 1.5,
    borderRadius: Radius.md,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.md,
    fontSize: 17,
    marginBottom: Spacing.lg,
  },
  modalButtons: {
    flexDirection: 'row',
    gap: Spacing.md,
  },
  modalBtn: {
    flex: 1,
    height: 50,
    borderRadius: Radius.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
