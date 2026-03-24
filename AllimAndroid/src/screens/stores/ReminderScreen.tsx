import React, {useEffect, useState, useCallback} from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  TouchableOpacity,
  TextInput,
  Alert,
  useColorScheme,
  ActivityIndicator,
  Modal,
  ScrollView,
  Image,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {useRoute, useNavigation, RouteProp} from '@react-navigation/native';
import Icon from 'react-native-vector-icons/Ionicons';
import {launchImageLibrary} from 'react-native-image-picker';

import GradientBackground from '../../components/GradientBackground';
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
import {reminderService} from '../../services/reminderService';
import {Reminder} from '../../models';
import {StoresStackParamList} from '../../navigation/AppNavigator';

type RouteType = RouteProp<StoresStackParamList, 'Reminders'>;

const CATEGORIES = ['Produce', 'Dairy', 'Meat', 'Bakery', 'Frozen', 'Beverages', 'Snacks', 'Household', 'Personal Care', 'Other'];

export default function ReminderScreen() {
  const scheme = useColorScheme();
  const route = useRoute<RouteType>();
  const navigation = useNavigation();
  const {firebaseUser} = useSession();

  const {userStoreId, storeName, storeId, permission} = route.params;
  const canEdit = permission !== 'view';

  const [reminders, setReminders] = useState<Reminder[]>([]);
  const [loading, setLoading] = useState(true);
  const [newTitle, setNewTitle] = useState('');
  const [addingNew, setAddingNew] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editTitle, setEditTitle] = useState('');
  const [showCategoryModal, setShowCategoryModal] = useState(false);
  const [categoryReminder, setCategoryReminder] = useState<Reminder | null>(null);
  const [showPhotoModal, setShowPhotoModal] = useState<Reminder | null>(null);

  useEffect(() => {
    const unsub = reminderService.subscribeToReminders(userStoreId, items => {
      setReminders(items);
      setLoading(false);
    });
    return unsub;
  }, [userStoreId]);

  async function handleAdd() {
    if (!newTitle.trim()) {return;}
    setAddingNew(true);
    try {
      await reminderService.addReminder(userStoreId, storeId, newTitle.trim());
      setNewTitle('');
    } catch (err: any) {
      Alert.alert('Error', err.message);
    } finally {
      setAddingNew(false);
    }
  }

  async function handleToggle(reminder: Reminder) {
    try {
      await reminderService.toggleDone(reminder);
    } catch (_) {}
  }

  async function handleDelete(reminder: Reminder) {
    Alert.alert('Delete Reminder', `Delete "${reminder.title}"?`, [
      {text: 'Cancel', style: 'cancel'},
      {
        text: 'Delete',
        style: 'destructive',
        onPress: () => reminderService.deleteReminder(reminder.id, storeId),
      },
    ]);
  }

  async function handleSaveEdit(id: string) {
    if (!editTitle.trim()) {return;}
    await reminderService.updateTitle(id, editTitle.trim());
    setEditingId(null);
    setEditTitle('');
  }

  async function handleSetCategory(reminder: Reminder, category: string) {
    await reminderService.updateCategory(reminder.id, category);
    setShowCategoryModal(false);
    setCategoryReminder(null);
  }

  async function handlePickPhoto(reminder: Reminder) {
    if (!firebaseUser) {return;}
    const result = await launchImageLibrary({mediaType: 'photo', quality: 0.8});
    if (result.assets?.[0]?.uri) {
      try {
        await reminderService.uploadPhoto(
          reminder.id,
          result.assets[0].uri,
          firebaseUser.uid,
        );
      } catch (err: any) {
        Alert.alert('Error', err.message);
      }
    }
  }

  // Group reminders by category
  const grouped = reminders.reduce<{[cat: string]: Reminder[]}>((acc, r) => {
    const cat = r.category ?? 'Uncategorized';
    if (!acc[cat]) {acc[cat] = [];}
    acc[cat].push(r);
    return acc;
  }, {});

  const pendingCount = reminders.filter(r => !r.isDone).length;

  function renderReminder(reminder: Reminder) {
    const isEditing = editingId === reminder.id;

    return (
      <View
        key={reminder.id}
        style={[styles.reminderRow, cardStyle(scheme)]}>
        {/* Checkbox */}
        <TouchableOpacity
          onPress={() => canEdit && handleToggle(reminder)}
          style={[
            styles.checkbox,
            reminder.isDone && {backgroundColor: Colors.blue, borderColor: Colors.blue},
          ]}>
          {reminder.isDone && (
            <Icon name="checkmark" size={14} color="#fff" />
          )}
        </TouchableOpacity>

        {/* Title */}
        <View style={styles.reminderContent}>
          {isEditing ? (
            <TextInput
              value={editTitle}
              onChangeText={setEditTitle}
              onBlur={() => handleSaveEdit(reminder.id)}
              onSubmitEditing={() => handleSaveEdit(reminder.id)}
              autoFocus
              style={[styles.editInput, {color: textPrimary(scheme)}]}
            />
          ) : (
            <TouchableOpacity
              onLongPress={() => {
                if (canEdit) {
                  setEditingId(reminder.id);
                  setEditTitle(reminder.title);
                }
              }}>
              <Text
                style={[
                  styles.reminderTitle,
                  {color: textPrimary(scheme)},
                  reminder.isDone && styles.done,
                ]}>
                {reminder.title}
                {reminder.quantity != null && reminder.quantity > 0
                  ? ` ×${reminder.quantity}`
                  : ''}
              </Text>
              {reminder.category && (
                <Text style={[styles.category, {color: textSecondary(scheme)}]}>
                  {reminder.category}
                </Text>
              )}
            </TouchableOpacity>
          )}
        </View>

        {/* Actions */}
        {canEdit && (
          <View style={styles.reminderActions}>
            <TouchableOpacity
              onPress={() => {
                setCategoryReminder(reminder);
                setShowCategoryModal(true);
              }}
              style={styles.actionBtn}>
              <Icon name="pricetag-outline" size={18} color={Colors.blue} />
            </TouchableOpacity>
            <TouchableOpacity
              onPress={() => handlePickPhoto(reminder)}
              style={styles.actionBtn}>
              <Icon name="camera-outline" size={18} color={Colors.blue} />
            </TouchableOpacity>
            <TouchableOpacity
              onPress={() => handleDelete(reminder)}
              style={styles.actionBtn}>
              <Icon name="trash-outline" size={18} color={Colors.red} />
            </TouchableOpacity>
          </View>
        )}
      </View>
    );
  }

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}}>
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backBtn}>
            <Icon name="chevron-back" size={24} color={Colors.blue} />
          </TouchableOpacity>
          <View style={styles.headerCenter}>
            <Text style={[styles.storeName, {color: textPrimary(scheme)}]}>
              {storeName}
            </Text>
            <Text style={[styles.reminderCount, {color: textSecondary(scheme)}]}>
              {pendingCount} item{pendingCount !== 1 ? 's' : ''} remaining
            </Text>
          </View>
          {permission === 'view' && (
            <Icon name="eye-outline" size={18} color={textSecondary(scheme)} />
          )}
        </View>

        {/* Add reminder input */}
        {canEdit && (
          <View style={[styles.addRow, {backgroundColor: cardBackground(scheme)}]}>
            <TextInput
              placeholder="Add new item..."
              placeholderTextColor={textSecondary(scheme)}
              value={newTitle}
              onChangeText={setNewTitle}
              onSubmitEditing={handleAdd}
              style={[styles.addInput, {color: textPrimary(scheme)}]}
              returnKeyType="done"
            />
            <TouchableOpacity
              onPress={handleAdd}
              disabled={addingNew || !newTitle.trim()}
              style={[
                styles.addBtn,
                {opacity: newTitle.trim() ? 1 : 0.4},
              ]}>
              {addingNew ? (
                <ActivityIndicator size="small" color="#fff" />
              ) : (
                <Icon name="add" size={24} color="#fff" />
              )}
            </TouchableOpacity>
          </View>
        )}

        {/* Reminders list */}
        {loading ? (
          <View style={styles.center}>
            <ActivityIndicator size="large" color={Colors.blue} />
          </View>
        ) : reminders.length === 0 ? (
          <View style={styles.center}>
            <Icon name="checkmark-circle-outline" size={60} color={textSecondary(scheme)} />
            <Text style={[styles.emptyText, {color: textSecondary(scheme)}]}>
              No items yet.{canEdit ? '\nAdd your first item above!' : ''}
            </Text>
          </View>
        ) : (
          <ScrollView
            contentContainerStyle={styles.list}>
            {Object.entries(grouped).map(([cat, items]) => (
              <View key={cat}>
                <Text style={[styles.categoryHeader, {color: textSecondary(scheme)}]}>
                  {cat}
                </Text>
                {items.map(r => renderReminder(r))}
              </View>
            ))}
          </ScrollView>
        )}
      </SafeAreaView>

      {/* Category picker modal */}
      <Modal
        visible={showCategoryModal}
        transparent
        animationType="slide"
        onRequestClose={() => setShowCategoryModal(false)}>
        <View style={styles.modalOverlay}>
          <View style={[styles.modalCard, {backgroundColor: cardBackground(scheme)}]}>
            <Text style={[styles.modalTitle, {color: textPrimary(scheme)}]}>
              Set Category
            </Text>
            {CATEGORIES.map(cat => (
              <TouchableOpacity
                key={cat}
                style={styles.categoryOption}
                onPress={() =>
                  categoryReminder && handleSetCategory(categoryReminder, cat)
                }>
                <Text style={[styles.categoryOptionText, {color: textPrimary(scheme)}]}>
                  {cat}
                </Text>
                {categoryReminder?.category === cat && (
                  <Icon name="checkmark" size={18} color={Colors.blue} />
                )}
              </TouchableOpacity>
            ))}
            <TouchableOpacity
              style={[styles.cancelBtn, {backgroundColor: Colors.blue + '1A'}]}
              onPress={() => setShowCategoryModal(false)}>
              <Text style={{color: Colors.blue, fontWeight: '600', fontSize: 16}}>
                Cancel
              </Text>
            </TouchableOpacity>
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
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.md,
  },
  backBtn: {
    padding: Spacing.xs,
    marginRight: Spacing.sm,
  },
  headerCenter: {
    flex: 1,
  },
  storeName: {
    fontSize: 20,
    fontWeight: '700',
  },
  reminderCount: {
    fontSize: 13,
    marginTop: 2,
  },
  addRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: Spacing.md,
    marginBottom: Spacing.md,
    borderRadius: Radius.md,
    paddingLeft: Spacing.md,
    paddingRight: Spacing.xs,
    paddingVertical: Spacing.xs,
  },
  addInput: {
    flex: 1,
    fontSize: 16,
    paddingVertical: Spacing.sm,
  },
  addBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: Colors.blue,
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: Spacing.sm,
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: Spacing.xl,
  },
  emptyText: {
    fontSize: 16,
    textAlign: 'center',
    marginTop: Spacing.md,
    lineHeight: 22,
  },
  list: {
    paddingHorizontal: Spacing.md,
    paddingBottom: 40,
  },
  categoryHeader: {
    fontSize: 13,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginTop: Spacing.md,
    marginBottom: Spacing.sm,
    paddingHorizontal: Spacing.sm,
  },
  reminderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.md,
    marginBottom: 4,
  },
  checkbox: {
    width: 24,
    height: 24,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: Colors.blue,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: Spacing.md,
  },
  reminderContent: {
    flex: 1,
  },
  reminderTitle: {
    fontSize: 16,
    fontWeight: '500',
  },
  done: {
    textDecorationLine: 'line-through',
    opacity: 0.5,
  },
  category: {
    fontSize: 12,
    marginTop: 2,
  },
  editInput: {
    fontSize: 16,
    borderBottomWidth: 1.5,
    borderBottomColor: Colors.blue,
    paddingVertical: 2,
  },
  reminderActions: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  actionBtn: {
    padding: Spacing.xs,
    marginLeft: Spacing.xs,
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
  categoryOption: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: Spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: 'rgba(128,128,128,0.3)',
  },
  categoryOptionText: {
    fontSize: 17,
  },
  cancelBtn: {
    marginTop: Spacing.lg,
    height: 50,
    borderRadius: Radius.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
