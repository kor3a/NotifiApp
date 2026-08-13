import React, {useEffect, useState} from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  TouchableOpacity,
  Modal,
  TextInput,
  Alert,
  useColorScheme,
  ActivityIndicator,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import Icon from '@expo/vector-icons/Ionicons';

import GradientBackground from '../../components/GradientBackground';
import ProfileAvatar from '../../components/ProfileAvatar';
import {
  Colors,
  Spacing,
  Radius,
  cardStyle,
  cardBackground,
  textPrimary,
  textSecondary,
} from '../../theme/AppTheme';
import {useSession} from '../../context/SessionContext';
import {friendService} from '../../services/friendService';
import {messageService} from '../../services/messageService';
import {Friendship} from '../../models';
import {useNavigation} from '@react-navigation/native';

export default function FriendsScreen() {
  const scheme = useColorScheme();
  const navigation = useNavigation<any>();
  const {currentUser, firebaseUser} = useSession();

  const [friends, setFriends] = useState<Friendship[]>([]);
  const [pendingRequests, setPendingRequests] = useState<Friendship[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [searchEmail, setSearchEmail] = useState('');
  const [searching, setSearching] = useState(false);

  useEffect(() => {
    // Friendships are keyed by username (userId), not the Firebase Auth uid.
    if (!currentUser) {return;}

    const unsubFriends = friendService.subscribeToFriends(currentUser.userId, f => {
      setFriends(f);
      setLoading(false);
    });

    const unsubRequests = friendService.subscribeToPendingRequests(
      currentUser.userId,
      r => setPendingRequests(r),
    );

    return () => {
      unsubFriends();
      unsubRequests();
    };
  }, [currentUser]);

  async function handleAddFriend() {
    if (!searchEmail.trim() || !currentUser || !firebaseUser) {return;}
    setSearching(true);
    try {
      const found = await friendService.searchByEmail(searchEmail.trim().toLowerCase());
      if (!found) {
        Alert.alert('Not Found', 'No user found with that email.');
        return;
      }
      if (found.userId === currentUser.userId) {
        Alert.alert('Error', "You can't add yourself.");
        return;
      }
      await friendService.sendFriendRequest(currentUser, found);
      Alert.alert('Request Sent', `Friend request sent to ${found.name}.`);
      setShowAddModal(false);
      setSearchEmail('');
    } catch (err: any) {
      Alert.alert('Error', err.message ?? 'Failed to send request.');
    } finally {
      setSearching(false);
    }
  }

  async function handleAccept(friendship: Friendship) {
    try {
      await friendService.acceptRequest(friendship.id);
    } catch (err: any) {
      Alert.alert('Error', err.message);
    }
  }

  async function handleDecline(friendship: Friendship) {
    try {
      await friendService.rejectRequest(friendship.id);
    } catch (err: any) {
      Alert.alert('Error', err.message);
    }
  }

  async function handleRemoveFriend(friendship: Friendship) {
    Alert.alert('Remove Friend', 'Are you sure you want to remove this friend?', [
      {text: 'Cancel', style: 'cancel'},
      {
        text: 'Remove',
        style: 'destructive',
        onPress: () => friendService.removeFriend(friendship.id),
      },
    ]);
  }

  async function handleMessage(friendship: Friendship) {
    if (!currentUser) {return;}
    const otherId =
      friendship.requesterId === currentUser.userId
        ? friendship.receiverId
        : friendship.requesterId;
    const otherName =
      friendship.requesterId === currentUser.userId
        ? friendship.receiverName ?? 'Friend'
        : friendship.requesterName ?? 'Friend';
    const otherPhoto =
      friendship.requesterId === currentUser.userId
        ? friendship.receiverPhoto
        : friendship.requesterPhoto;

    const convoId = await messageService.getOrCreateConversation(
      currentUser.userId,
      otherId,
      currentUser.name,
      otherName,
      currentUser.profilePictureURL,
      otherPhoto,
    );

    navigation.navigate('Messages', {
      screen: 'Conversation',
      params: {
        conversationId: convoId,
        otherUserId: otherId,
        otherUserName: otherName,
      },
    });
  }

  function getFriendInfo(f: Friendship) {
    if (!currentUser) {return {name: 'Friend', photo: undefined};}
    const isMeRequester = f.requesterId === currentUser.userId;
    return {
      name: isMeRequester ? f.receiverName ?? 'Friend' : f.requesterName ?? 'Friend',
      photo: isMeRequester ? f.receiverPhoto : f.requesterPhoto,
    };
  }

  function renderPendingRequest({item}: {item: Friendship}) {
    const info = getFriendInfo(item);
    return (
      <View style={[styles.requestCard, cardStyle(scheme)]}>
        <ProfileAvatar url={info.photo} name={info.name} size={40} />
        <View style={styles.friendInfo}>
          <Text style={[styles.friendName, {color: textPrimary(scheme)}]}>
            {info.name}
          </Text>
          <Text style={[styles.friendEmail, {color: textSecondary(scheme)}]}>
            Sent a friend request
          </Text>
        </View>
        <View style={styles.requestActions}>
          <TouchableOpacity
            style={[styles.actionIconBtn, {backgroundColor: Colors.green}]}
            onPress={() => handleAccept(item)}>
            <Icon name="checkmark" size={18} color="#fff" />
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.actionIconBtn, {backgroundColor: Colors.red, marginLeft: 8}]}
            onPress={() => handleDecline(item)}>
            <Icon name="close" size={18} color="#fff" />
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  function renderFriend({item}: {item: Friendship}) {
    const info = getFriendInfo(item);
    return (
      <View style={[styles.friendCard, cardStyle(scheme)]}>
        <ProfileAvatar url={info.photo} name={info.name} size={44} />
        <View style={styles.friendInfo}>
          <Text style={[styles.friendName, {color: textPrimary(scheme)}]}>
            {info.name}
          </Text>
        </View>
        <View style={styles.friendActions}>
          <TouchableOpacity
            style={styles.friendActionBtn}
            onPress={() => handleMessage(item)}>
            <Icon name="chatbubble-outline" size={20} color={Colors.blue} />
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.friendActionBtn}
            onPress={() => handleRemoveFriend(item)}>
            <Icon name="person-remove-outline" size={20} color={Colors.red} />
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}}>
        <View style={styles.header}>
          <Text style={[styles.headerTitle, {color: textPrimary(scheme)}]}>
            Friends
          </Text>
          <TouchableOpacity
            onPress={() => setShowAddModal(true)}
            style={styles.addBtn}>
            <Icon name="person-add-outline" size={22} color={Colors.blue} />
          </TouchableOpacity>
        </View>

        {loading ? (
          <View style={styles.center}>
            <ActivityIndicator size="large" color={Colors.blue} />
          </View>
        ) : (
          <FlatList
            data={[
              ...pendingRequests.map(r => ({...r, _type: 'request'})),
              ...friends.map(f => ({...f, _type: 'friend'})),
            ]}
            keyExtractor={item => item.id}
            contentContainerStyle={styles.list}
            ListHeaderComponent={
              pendingRequests.length > 0 ? (
                <Text style={[styles.sectionHeader, {color: textSecondary(scheme)}]}>
                  PENDING REQUESTS
                </Text>
              ) : null
            }
            renderItem={({item}: any) =>
              item._type === 'request'
                ? renderPendingRequest({item})
                : renderFriend({item})
            }
            ListEmptyComponent={
              <View style={styles.center}>
                <Icon name="people-outline" size={60} color={textSecondary(scheme)} />
                <Text style={[styles.emptyText, {color: textSecondary(scheme)}]}>
                  No friends yet.{'\n'}Add someone to get started!
                </Text>
              </View>
            }
          />
        )}
      </SafeAreaView>

      {/* Add Friend Modal */}
      <Modal
        visible={showAddModal}
        transparent
        animationType="slide"
        onRequestClose={() => setShowAddModal(false)}>
        <View style={styles.modalOverlay}>
          <View style={[styles.modalCard, {backgroundColor: cardBackground(scheme)}]}>
            <Text style={[styles.modalTitle, {color: textPrimary(scheme)}]}>
              Add Friend
            </Text>
            <Text style={[styles.modalSubtitle, {color: textSecondary(scheme)}]}>
              Search by their email address
            </Text>
            <TextInput
              placeholder="friend@example.com"
              placeholderTextColor={textSecondary(scheme)}
              value={searchEmail}
              onChangeText={setSearchEmail}
              keyboardType="email-address"
              autoCapitalize="none"
              style={[styles.modalInput, {color: textPrimary(scheme), borderColor: Colors.blue + '44'}]}
              autoFocus
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
                onPress={handleAddFriend}
                disabled={searching}>
                {searching ? (
                  <ActivityIndicator color="#fff" />
                ) : (
                  <Text style={{color: '#fff', fontSize: 16, fontWeight: '600'}}>
                    Search
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
  addBtn: {
    padding: Spacing.xs,
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
    paddingBottom: 20,
    flexGrow: 1,
  },
  sectionHeader: {
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 0.5,
    marginTop: Spacing.md,
    marginBottom: Spacing.sm,
    paddingHorizontal: Spacing.sm,
  },
  requestCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.md,
  },
  friendCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.md,
  },
  friendInfo: {
    flex: 1,
    marginLeft: Spacing.md,
  },
  friendName: {
    fontSize: 16,
    fontWeight: '600',
  },
  friendEmail: {
    fontSize: 13,
    marginTop: 2,
  },
  requestActions: {
    flexDirection: 'row',
  },
  actionIconBtn: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  friendActions: {
    flexDirection: 'row',
  },
  friendActionBtn: {
    padding: Spacing.sm,
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
    marginBottom: Spacing.xs,
    textAlign: 'center',
  },
  modalSubtitle: {
    fontSize: 14,
    textAlign: 'center',
    marginBottom: Spacing.lg,
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
