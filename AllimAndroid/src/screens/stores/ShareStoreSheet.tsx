import React, {useEffect, useState} from 'react';
import {
  View,
  Text,
  Modal,
  TextInput,
  StyleSheet,
  TouchableOpacity,
  FlatList,
  ActivityIndicator,
  useColorScheme,
  Alert,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import Icon from '../../components/AppIcon';

import ProfileAvatar from '../../components/ProfileAvatar';
import {
  Colors,
  Spacing,
  Radius,
  textPrimary,
  textSecondary,
  cardBackground,
  cardBorder,
} from '../../theme/AppTheme';
import {useSession} from '../../context/SessionContext';
import {friendService} from '../../services/friendService';
import {storeShareService} from '../../services/storeShareService';
import {Friendship, User, UserStoreItem} from '../../models';

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

export default function ShareStoreSheet({visible, item, onClose}: Props) {
  const scheme = useColorScheme();
  const {currentUser} = useSession();

  const [friends, setFriends] = useState<User[]>([]);
  const [permission, setPermission] = useState<'edit' | 'view'>('edit');
  const [email, setEmail] = useState('');
  const [sharingWith, setSharingWith] = useState<string | null>(null);

  useEffect(() => {
    if (!visible) {
      return;
    }
    setPermission('edit');
    setEmail('');
    setSharingWith(null);
  }, [visible]);

  useEffect(() => {
    if (!currentUser) {
      return;
    }
    return friendService.subscribeToFriends(currentUser.userId, items =>
      setFriends(items.map(f => contactFrom(f, currentUser.userId))),
    );
  }, [currentUser]);

  const alreadyShared = new Set(item?.sharedWith ?? []);

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

  function renderFriend({friend}: {friend: User}) {
    const shared = alreadyShared.has(friend.name);
    const busy = sharingWith === friend.userId;
    return (
      <TouchableOpacity
        style={[styles.friendRow, {borderBottomColor: cardBorder(scheme)}]}
        onPress={() => share(friend)}
        disabled={!!sharingWith}
        activeOpacity={0.7}>
        <ProfileAvatar
          url={friend.profilePictureURL}
          name={friend.name}
          size={40}
        />
        <View style={styles.friendText}>
          <Text style={[styles.friendName, {color: textPrimary(scheme)}]}>
            {friend.name}
          </Text>
          <Text style={[styles.friendEmail, {color: textSecondary(scheme)}]}>
            {shared ? 'Already shared' : friend.email}
          </Text>
        </View>
        {busy ? (
          <ActivityIndicator color={Colors.blue} />
        ) : (
          <Icon
            name={shared ? 'refresh-circle-outline' : 'share-outline'}
            size={22}
            color={Colors.blue}
          />
        )}
      </TouchableOpacity>
    );
  }

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}>
      <SafeAreaView
        style={[
          styles.container,
          {
            backgroundColor:
              scheme === 'dark'
                ? Colors.backgroundTopDark
                : Colors.backgroundTopLight,
          },
        ]}>
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity onPress={onClose}>
            <Text style={[styles.cancel, {color: Colors.blue}]}>Cancel</Text>
          </TouchableOpacity>
          <Text style={[styles.title, {color: textPrimary(scheme)}]}>
            Share Store
          </Text>
          <View style={{width: 60}} />
        </View>

        <Text style={[styles.storeName, {color: textPrimary(scheme)}]}>
          {item?.store.name ?? ''}
        </Text>

        {/* Permission */}
        <View style={styles.section}>
          <Text style={[styles.sectionLabel, {color: textSecondary(scheme)}]}>
            PERMISSION
          </Text>
          <View
            style={[
              styles.segment,
              {
                backgroundColor: cardBackground(scheme),
                borderColor: cardBorder(scheme),
              },
            ]}>
            {(['edit', 'view'] as const).map(value => {
              const selected = permission === value;
              return (
                <TouchableOpacity
                  key={value}
                  style={[
                    styles.segmentItem,
                    selected && {backgroundColor: Colors.blue},
                  ]}
                  onPress={() => setPermission(value)}
                  activeOpacity={0.8}>
                  <Icon
                    name={value === 'edit' ? 'pencil-outline' : 'eye-outline'}
                    size={16}
                    color={selected ? '#fff' : textSecondary(scheme)}
                  />
                  <Text
                    style={[
                      styles.segmentText,
                      {color: selected ? '#fff' : textPrimary(scheme)},
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
        </View>

        {/* Friends */}
        <View style={[styles.section, {flex: 1}]}>
          <Text style={[styles.sectionLabel, {color: textSecondary(scheme)}]}>
            FRIENDS
          </Text>
          <FlatList
            data={friends}
            renderItem={({item: friend}) => renderFriend({friend})}
            keyExtractor={friend => friend.userId}
            keyboardShouldPersistTaps="handled"
            ListEmptyComponent={
              <Text style={[styles.empty, {color: textSecondary(scheme)}]}>
                No friends yet. Add friends from the Friends tab, or share by
                email below.
              </Text>
            }
          />
        </View>

        {/* Email fallback */}
        <View style={styles.section}>
          <Text style={[styles.sectionLabel, {color: textSecondary(scheme)}]}>
            SHARE BY EMAIL
          </Text>
          <View
            style={[
              styles.emailRow,
              {
                backgroundColor: cardBackground(scheme),
                borderColor: cardBorder(scheme),
              },
            ]}>
            <TextInput
              placeholder="name@example.com"
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
              ]}>
              {sharingWith === email.trim().toLowerCase() ? (
                <ActivityIndicator color="#fff" size="small" />
              ) : (
                <Icon name="send" size={18} color="#fff" />
              )}
            </TouchableOpacity>
          </View>
        </View>
      </SafeAreaView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
  },
  cancel: {
    fontSize: 17,
    width: 60,
  },
  title: {
    fontSize: 17,
    fontWeight: '600',
  },
  storeName: {
    fontSize: 22,
    fontWeight: '700',
    paddingHorizontal: Spacing.md,
    paddingBottom: Spacing.sm,
  },
  section: {
    paddingHorizontal: Spacing.md,
    paddingBottom: Spacing.md,
  },
  sectionLabel: {
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0.5,
    marginBottom: Spacing.sm,
  },
  segment: {
    flexDirection: 'row',
    borderRadius: Radius.md,
    borderWidth: 1,
    overflow: 'hidden',
  },
  segmentItem: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.sm,
    paddingVertical: Spacing.sm + 4,
  },
  segmentText: {
    fontSize: 15,
    fontWeight: '600',
  },
  hint: {
    fontSize: 13,
    marginTop: Spacing.sm,
    lineHeight: 18,
  },
  friendRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
    paddingVertical: Spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
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
  empty: {
    fontSize: 14,
    lineHeight: 20,
    paddingVertical: Spacing.md,
  },
  emailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: Radius.md,
    borderWidth: 1,
  },
  emailInput: {
    flex: 1,
    fontSize: 16,
    padding: 0,
  },
  sendBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: Colors.blue,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
