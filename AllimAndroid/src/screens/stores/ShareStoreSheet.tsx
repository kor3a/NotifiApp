import React, {useEffect, useState} from 'react';
import {
  View,
  Text,
  Modal,
  TextInput,
  StyleSheet,
  TouchableOpacity,
  Pressable,
  FlatList,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  useColorScheme,
  Alert,
} from 'react-native';
import {useSafeAreaInsets} from 'react-native-safe-area-context';
import Icon from '../../components/AppIcon';

import ProfileAvatar from '../../components/ProfileAvatar';
import {
  Colors,
  Spacing,
  Radius,
  textPrimary,
  textSecondary,
  sheetBackground,
  sheetFill,
} from '../../theme/AppTheme';
import {useSession} from '../../context/SessionContext';
import {friendService} from '../../services/friendService';
import {storeShareService} from '../../services/storeShareService';
import {
  Friendship,
  SharedStoreUser,
  StorePermission,
  User,
  UserStoreItem,
  reminderStoreIdFor,
} from '../../models';

interface Props {
  visible: boolean;
  item: UserStoreItem | null;
  onClose: () => void;
}

// The friends collection stores both sides of a friendship on one document, so
// the contact is whichever participant is not the signed-in user.
function contactFrom(friendship: Friendship, currentUserId: string): User {
  const isRequester = friendship.requesterId === currentUserId;
  return {
    userId: isRequester ? friendship.receiverId : friendship.requesterId,
    name:
      (isRequester ? friendship.receiverName : friendship.requesterName) ??
      (isRequester ? friendship.receiverId : friendship.requesterId),
    email: isRequester ? friendship.receiverEmail : friendship.requesterEmail,
    profilePictureURL: isRequester
      ? friendship.receiverPhoto
      : friendship.requesterPhoto,
  };
}

function permissionLabel(permission: StorePermission): string {
  if (permission === 'view') {
    return 'View Only';
  }
  if (permission === 'edit') {
    return 'Can Edit';
  }
  // They accepted the share onto a store they already owned, so the two lists
  // were merged and they keep their own copy.
  return 'Merged list';
}

function permissionTint(permission: StorePermission): string {
  if (permission === 'view') {
    return Colors.orange;
  }
  return permission === 'edit' ? Colors.green : Colors.blue;
}

export default function ShareStoreSheet({visible, item, onClose}: Props) {
  const scheme = useColorScheme();
  const insets = useSafeAreaInsets();
  const {currentUser} = useSession();

  const [friends, setFriends] = useState<User[]>([]);
  const [sharedUsers, setSharedUsers] = useState<SharedStoreUser[]>([]);
  const [permission, setPermission] = useState<'edit' | 'view'>('edit');
  const [email, setEmail] = useState('');
  const [sharingWith, setSharingWith] = useState<string | null>(null);
  const [unsharingWith, setUnsharingWith] = useState<string | null>(null);

  useEffect(() => {
    if (!visible) {
      return;
    }
    setPermission('edit');
    setEmail('');
    setSharingWith(null);
    setUnsharingWith(null);
  }, [visible]);

  useEffect(() => {
    if (!currentUser) {
      return;
    }
    return friendService.subscribeToFriends(currentUser.userId, items =>
      setFriends(items.map(f => contactFrom(f, currentUser.userId))),
    );
  }, [currentUser]);

  // Where this store's reminders live, which is also what every recipient's
  // user_store points at — so it identifies the share on both sides.
  const shareTargetId = item ? reminderStoreIdFor(item) : null;
  const currentUserId = currentUser?.userId;
  // Everyone listed under a store this user owns is there because this user
  // shared it with them, so their access is this user's to revoke. A recipient
  // opening the sheet sees the same list but cannot act on it.
  const canUnshare = item?.permission === 'owner';

  useEffect(() => {
    if (!visible || !shareTargetId || !currentUserId) {
      setSharedUsers([]);
      return;
    }
    return storeShareService.subscribeToSharedUsers(shareTargetId, users =>
      // A recipient opening this sheet matches the same query through their own
      // document; everyone else on it is who the store is shared with.
      setSharedUsers(users.filter(u => u.userId !== currentUserId)),
    );
  }, [visible, shareTargetId, currentUserId]);

  // Friends carry the only profile pictures we have — recipient user_store
  // documents store just a name and an email.
  const friendPhotos = new Map<string, string | undefined>();
  friends.forEach(friend => {
    friendPhotos.set(friend.userId, friend.profilePictureURL);
    if (friend.email) {
      friendPhotos.set(friend.email.toLowerCase(), friend.profilePictureURL);
    }
  });

  const sharedUserIds = new Set(sharedUsers.map(u => u.userId));
  const sharedEmails = new Set(
    sharedUsers.map(u => u.email.toLowerCase()).filter(Boolean),
  );
  // The owner's own document only records names, so it stays as a fallback for
  // shares that predate the recipient list (or whose accept has not landed yet).
  const sharedNames = new Set(item?.sharedWith ?? []);

  function isSharedWith(user: User): boolean {
    return (
      sharedUserIds.has(user.userId) ||
      (!!user.email && sharedEmails.has(user.email.toLowerCase())) ||
      sharedNames.has(user.name)
    );
  }

  async function share(recipient: User) {
    if (sharingWith) {
      return;
    }
    await performShare(recipient, recipient.userId);
  }

  // Split from share() so the email path can run it without tripping over its
  // own in-flight marker, which is still set while the lookup resolves.
  async function performShare(recipient: User, busyKey: string) {
    if (!item || !currentUser) {
      return;
    }
    setSharingWith(busyKey);
    try {
      await storeShareService.shareStore({
        item,
        recipient,
        permission,
        currentUser,
      });
      Alert.alert(
        'Share Sent',
        `${recipient.name} will see the request in their messages and can accept or decline it.`,
      );
      onClose();
    } catch (err: any) {
      Alert.alert('Error', err?.message ?? 'Failed to share this store.');
    } finally {
      setSharingWith(null);
    }
  }

  async function shareByEmail() {
    const cleaned = email.trim().toLowerCase();
    if (!cleaned || !currentUser) {
      return;
    }
    if (cleaned === currentUser.email.toLowerCase()) {
      Alert.alert('Error', 'You cannot share a store with yourself.');
      return;
    }
    setSharingWith(cleaned);
    let user: User | null = null;
    try {
      user = await friendService.searchByEmail(cleaned);
    } catch (err: any) {
      Alert.alert('Error', err?.message ?? 'Failed to look up that email.');
      setSharingWith(null);
      return;
    }
    if (!user) {
      Alert.alert(
        'Not Found',
        'No Allim account uses that email address. Ask them to sign up first.',
      );
      setSharingWith(null);
      return;
    }
    await performShare(user, cleaned);
  }

  // Revoke someone's access. A recipient who merged the store into one they
  // already owned keeps their store — only the link between the two is cut —
  // so the prompt says which of the two is about to happen.
  function confirmUnshare(user: SharedStoreUser) {
    if (!item || !currentUser || unsharingWith) {
      return;
    }
    const merged = user.permission === 'owner';
    Alert.alert(
      `Stop sharing with ${user.name}?`,
      merged
        ? `${item.store.name} stays on their list — they had it before you shared — but your items will be removed from it.`
        : `${item.store.name} will be removed from their account.`,
      [
        {text: 'Cancel', style: 'cancel'},
        {
          text: 'Stop Sharing',
          style: 'destructive',
          onPress: async () => {
            setUnsharingWith(user.id);
            try {
              await storeShareService.unshareWithUser({
                item,
                sharedUser: user,
                currentUser,
              });
            } catch (err: any) {
              Alert.alert(
                'Error',
                err?.message ?? 'Failed to remove access to this store.',
              );
            } finally {
              setUnsharingWith(null);
            }
          },
        },
      ],
    );
  }

  function renderSharedUser(user: SharedStoreUser) {
    const tint = permissionTint(user.permission);
    return (
      <View
        key={user.id}
        style={[styles.sharedRow, {backgroundColor: sheetFill(scheme)}]}>
        <ProfileAvatar
          url={
            friendPhotos.get(user.userId) ??
            friendPhotos.get(user.email.toLowerCase())
          }
          name={user.name}
          size={38}
        />
        <View style={styles.friendText}>
          <Text
            style={[styles.friendName, {color: textPrimary(scheme)}]}
            numberOfLines={1}>
            {user.name}
          </Text>
          <Text
            style={[styles.friendEmail, {color: textSecondary(scheme)}]}
            numberOfLines={1}>
            {user.email}
          </Text>
        </View>
        <View style={[styles.permissionPill, {backgroundColor: tint + '26'}]}>
          <Text style={[styles.permissionPillText, {color: tint}]}>
            {permissionLabel(user.permission)}
          </Text>
        </View>
        {/* Only the owner of the store can revoke access — an edit recipient
            seeing the other recipients here would just hit a rules denial. */}
        {!canUnshare ? null : unsharingWith === user.id ? (
          <ActivityIndicator color={Colors.red} style={styles.unshareBtn} />
        ) : (
          <TouchableOpacity
            style={styles.unshareBtn}
            onPress={() => confirmUnshare(user)}
            disabled={!!unsharingWith}
            hitSlop={8}
            activeOpacity={0.7}>
            <Icon name="close-circle" size={22} color={Colors.red} />
          </TouchableOpacity>
        )}
      </View>
    );
  }

  function renderFriend(friend: User) {
    const shared = isSharedWith(friend);
    const busy = sharingWith === friend.userId;
    return (
      <TouchableOpacity
        style={[styles.friendRow, {backgroundColor: sheetFill(scheme)}]}
        onPress={() => share(friend)}
        disabled={!!sharingWith}
        activeOpacity={0.7}>
        <ProfileAvatar
          url={friend.profilePictureURL}
          name={friend.name}
          size={42}
        />
        <View style={styles.friendText}>
          <Text
            style={[styles.friendName, {color: textPrimary(scheme)}]}
            numberOfLines={1}>
            {friend.name}
          </Text>
          <Text
            style={[styles.friendEmail, {color: textSecondary(scheme)}]}
            numberOfLines={1}>
            {friend.email}
          </Text>
        </View>
        {shared && (
          <View style={styles.sharedPill}>
            <Text style={styles.sharedPillText}>Shared</Text>
          </View>
        )}
        {busy ? (
          <ActivityIndicator color={Colors.blue} />
        ) : (
          <View style={styles.friendAction}>
            <Icon name="arrow-forward" size={18} color={Colors.blue} />
          </View>
        )}
      </TouchableOpacity>
    );
  }

  return (
    <Modal
      visible={visible}
      animationType="slide"
      transparent
      statusBarTranslucent
      onRequestClose={onClose}>
      <View style={styles.backdrop}>
        {/* Tapping the dimmed area behind the sheet closes it. */}
        <Pressable style={StyleSheet.absoluteFill} onPress={onClose} />

        {/* box-none so taps outside the sheet still reach the backdrop. */}
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
          pointerEvents="box-none"
          style={styles.sheetWrapper}>
          <View
            style={[
              styles.sheet,
              {
                backgroundColor: sheetBackground(scheme),
                paddingBottom: Math.max(insets.bottom, Spacing.md),
              },
            ]}>
            {/* Grab handle */}
            <View
              style={[
                styles.handle,
                {backgroundColor: scheme === 'dark' ? '#4A4A57' : '#D8DCE6'},
              ]}
            />

            {/* Header */}
            <View style={styles.header}>
              <View style={styles.headerText}>
                <Text style={[styles.title, {color: textPrimary(scheme)}]}>
                  Share Store
                </Text>
                <Text
                  style={[styles.subtitle, {color: textSecondary(scheme)}]}
                  numberOfLines={1}>
                  {item?.store.name ?? ''}
                </Text>
              </View>
              <TouchableOpacity
                style={[styles.closeBtn, {backgroundColor: sheetFill(scheme)}]}
                onPress={onClose}
                hitSlop={8}
                activeOpacity={0.7}>
                <Icon name="close" size={20} color={textSecondary(scheme)} />
              </TouchableOpacity>
            </View>

            {/* Who shared this store with the current user */}
            {!!item?.sharedFromName && (
              <>
                <Text
                  style={[styles.sectionLabel, {color: textSecondary(scheme)}]}>
                  Shared by
                </Text>
                <View
                  style={[
                    styles.sharedRow,
                    styles.sharedBySpacing,
                    {backgroundColor: sheetFill(scheme)},
                  ]}>
                  <ProfileAvatar name={item.sharedFromName} size={38} />
                  <View style={styles.friendText}>
                    <Text
                      style={[styles.friendName, {color: textPrimary(scheme)}]}
                      numberOfLines={1}>
                      {item.sharedFromName}
                    </Text>
                    <Text
                      style={[
                        styles.friendEmail,
                        {color: textSecondary(scheme)},
                      ]}
                      numberOfLines={1}>
                      Shared this store with you
                    </Text>
                  </View>
                  <View
                    style={[
                      styles.permissionPill,
                      {backgroundColor: permissionTint(item.permission) + '26'},
                    ]}>
                    <Text
                      style={[
                        styles.permissionPillText,
                        {color: permissionTint(item.permission)},
                      ]}>
                      {permissionLabel(item.permission)}
                    </Text>
                  </View>
                </View>
              </>
            )}

            {/* People this store is already shared with */}
            {sharedUsers.length > 0 && (
              <>
                <Text
                  style={[styles.sectionLabel, {color: textSecondary(scheme)}]}>
                  Shared with ({sharedUsers.length})
                </Text>
                {/* Capped and scrollable so a widely shared store still leaves
                    room for the friends list and the email row below. */}
                <ScrollView
                  style={styles.sharedList}
                  contentContainerStyle={styles.sharedListContent}
                  nestedScrollEnabled
                  keyboardShouldPersistTaps="handled"
                  showsVerticalScrollIndicator={false}>
                  {sharedUsers.map(renderSharedUser)}
                </ScrollView>
              </>
            )}

            {/* Permission */}
            <Text style={[styles.sectionLabel, {color: textSecondary(scheme)}]}>
              Permission
            </Text>
            <View style={[styles.segment, {backgroundColor: sheetFill(scheme)}]}>
              {(['edit', 'view'] as const).map(value => {
                const selected = permission === value;
                return (
                  <TouchableOpacity
                    key={value}
                    style={[
                      styles.segmentItem,
                      selected && styles.segmentItemSelected,
                    ]}
                    onPress={() => setPermission(value)}
                    activeOpacity={0.8}>
                    <Icon
                      name={value === 'edit' ? 'pencil' : 'eye'}
                      size={15}
                      color={selected ? '#fff' : textSecondary(scheme)}
                    />
                    <Text
                      style={[
                        styles.segmentText,
                        {color: selected ? '#fff' : textSecondary(scheme)},
                      ]}>
                      {value === 'edit' ? 'Can Edit' : 'View Only'}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </View>
            <Text style={[styles.hint, {color: textSecondary(scheme)}]}>
              {permission === 'edit'
                ? 'They can add, check off, and remove reminders in this store.'
                : 'They can see this store and its reminders, but not change them.'}
            </Text>

            {/* Friends */}
            <Text style={[styles.sectionLabel, {color: textSecondary(scheme)}]}>
              Send to
            </Text>
            <FlatList
              data={friends}
              renderItem={({item: friend}) => renderFriend(friend)}
              keyExtractor={friend => friend.userId}
              style={styles.friendList}
              contentContainerStyle={styles.friendListContent}
              keyboardShouldPersistTaps="handled"
              showsVerticalScrollIndicator={false}
              ListEmptyComponent={
                <View style={styles.empty}>
                  <View
                    style={[
                      styles.emptyIcon,
                      {backgroundColor: sheetFill(scheme)},
                    ]}>
                    <Icon
                      name="people-outline"
                      size={26}
                      color={textSecondary(scheme)}
                    />
                  </View>
                  <Text
                    style={[styles.emptyText, {color: textSecondary(scheme)}]}>
                    No friends yet — add them from the Friends tab, or share by
                    email below.
                  </Text>
                </View>
              }
            />

            {/* Email fallback */}
            <View
              style={[styles.emailRow, {backgroundColor: sheetFill(scheme)}]}>
              <Icon name="mail-outline" size={18} color={textSecondary(scheme)} />
              <TextInput
                placeholder="Share by email address"
                placeholderTextColor={textSecondary(scheme)}
                value={email}
                onChangeText={setEmail}
                style={[styles.emailInput, {color: textPrimary(scheme)}]}
                autoCapitalize="none"
                autoCorrect={false}
                keyboardType="email-address"
                returnKeyType="send"
                onSubmitEditing={shareByEmail}
              />
              <TouchableOpacity
                onPress={shareByEmail}
                disabled={!email.trim() || !!sharingWith}
                style={[
                  styles.sendBtn,
                  {opacity: email.trim() && !sharingWith ? 1 : 0.4},
                ]}
                activeOpacity={0.8}>
                {sharingWith === email.trim().toLowerCase() ? (
                  <ActivityIndicator color="#fff" size="small" />
                ) : (
                  <Icon name="arrow-up" size={18} color="#fff" />
                )}
              </TouchableOpacity>
            </View>
          </View>
        </KeyboardAvoidingView>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.45)',
    justifyContent: 'flex-end',
  },
  // Fills the screen so the sheet's percentage max height has something to
  // resolve against; the sheet itself is pinned to the bottom.
  sheetWrapper: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  sheet: {
    maxHeight: '88%',
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.sm,
  },
  handle: {
    alignSelf: 'center',
    width: 40,
    height: 4,
    borderRadius: 2,
    marginBottom: Spacing.md,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
    marginBottom: Spacing.lg,
  },
  headerText: {
    flex: 1,
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
  },
  subtitle: {
    fontSize: 14,
    marginTop: 2,
  },
  closeBtn: {
    width: 34,
    height: 34,
    borderRadius: 17,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sectionLabel: {
    fontSize: 13,
    fontWeight: '600',
    marginBottom: Spacing.sm,
  },
  // Tops out at roughly three rows, then scrolls on its own.
  sharedList: {
    flexGrow: 0,
    maxHeight: 186,
    marginBottom: Spacing.lg,
  },
  sharedListContent: {
    gap: Spacing.sm,
  },
  sharedRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
    padding: Spacing.sm + 2,
    borderRadius: Radius.lg,
  },
  sharedBySpacing: {
    marginBottom: Spacing.lg,
  },
  permissionPill: {
    paddingHorizontal: Spacing.sm,
    paddingVertical: 4,
    borderRadius: Radius.full,
  },
  permissionPillText: {
    fontSize: 11,
    fontWeight: '700',
  },
  unshareBtn: {
    width: 26,
    alignItems: 'center',
    justifyContent: 'center',
  },
  segment: {
    flexDirection: 'row',
    borderRadius: Radius.md,
    padding: 4,
    gap: 4,
  },
  segmentItem: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.sm,
    paddingVertical: Spacing.sm + 2,
    borderRadius: Radius.sm + 2,
  },
  segmentItemSelected: {
    backgroundColor: Colors.blue,
  },
  segmentText: {
    fontSize: 15,
    fontWeight: '600',
  },
  hint: {
    fontSize: 13,
    lineHeight: 18,
    marginTop: Spacing.sm,
    marginBottom: Spacing.lg,
  },
  // Grows with the list but yields once the sheet hits its max height, so a
  // long friends list scrolls instead of pushing the email row off-screen.
  friendList: {
    flexGrow: 0,
    flexShrink: 1,
  },
  friendListContent: {
    gap: Spacing.sm,
    paddingBottom: Spacing.md,
  },
  friendRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
    padding: Spacing.sm + 2,
    borderRadius: Radius.lg,
  },
  friendText: {
    flex: 1,
  },
  friendName: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 2,
  },
  friendEmail: {
    fontSize: 13,
  },
  sharedPill: {
    backgroundColor: Colors.green + '26',
    paddingHorizontal: Spacing.sm,
    paddingVertical: 3,
    borderRadius: Radius.full,
  },
  sharedPillText: {
    color: Colors.green,
    fontSize: 11,
    fontWeight: '700',
  },
  friendAction: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.blue + '1F',
  },
  empty: {
    alignItems: 'center',
    gap: Spacing.sm,
    paddingVertical: Spacing.lg,
  },
  emptyIcon: {
    width: 52,
    height: 52,
    borderRadius: 26,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyText: {
    fontSize: 14,
    lineHeight: 20,
    textAlign: 'center',
    paddingHorizontal: Spacing.md,
  },
  emailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    paddingLeft: Spacing.md,
    paddingRight: 5,
    paddingVertical: 5,
    borderRadius: Radius.full,
    marginTop: Spacing.sm,
  },
  emailInput: {
    flex: 1,
    fontSize: 15,
    padding: 0,
  },
  sendBtn: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: Colors.blue,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
