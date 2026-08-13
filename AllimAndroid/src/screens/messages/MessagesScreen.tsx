import React, {useCallback, useEffect, useRef, useState} from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  TouchableOpacity,
  useColorScheme,
  ActivityIndicator,
  Alert,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {useNavigation} from '@react-navigation/native';
import {NativeStackNavigationProp} from '@react-navigation/native-stack';
import {Swipeable} from 'react-native-gesture-handler';
import Icon from '../../components/AppIcon';
import {format, isToday, isYesterday} from 'date-fns';

import GradientBackground from '../../components/GradientBackground';
import ProfileAvatar from '../../components/ProfileAvatar';
import PrimaryButton from '../../components/PrimaryButton';
import NewMessageSheet from './NewMessageSheet';
import NewGroupSheet from './NewGroupSheet';
import {
  Colors,
  Spacing,
  Radius,
  cardStyle,
  textPrimary,
  textSecondary,
} from '../../theme/AppTheme';
import {useSession} from '../../context/SessionContext';
import {messageService} from '../../services/messageService';
import {
  Contact,
  Conversation,
  conversationDisplayName,
  isGroupConversation,
  memberNamesSubtitle,
  otherParticipantId,
  otherParticipantName,
  timestampMillis,
  unreadCountFor,
} from '../../models';
import {MessagesStackParamList} from '../../navigation/AppNavigator';

type Nav = NativeStackNavigationProp<MessagesStackParamList, 'MessagesList'>;

// Same relative stamp the iOS conversation row shows: the time for today,
// "Yesterday" for yesterday, and a numeric date beyond that.
function formatConversationTime(millis: number): string {
  if (!millis) {
    return '';
  }
  const date = new Date(millis);
  if (isToday(date)) {
    return format(date, 'h:mm a');
  }
  if (isYesterday(date)) {
    return 'Yesterday';
  }
  return format(date, 'MM/dd/yy');
}

export default function MessagesScreen() {
  const scheme = useColorScheme();
  const navigation = useNavigation<Nav>();
  const {currentUser} = useSession();

  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [loading, setLoading] = useState(true);
  const [showNewMessage, setShowNewMessage] = useState(false);
  const [showNewGroup, setShowNewGroup] = useState(false);
  // Avatars for participants whose conversation carries no participantPhotos:
  // that is every conversation started on iOS, which reads avatars off the user
  // document instead of copying them onto the conversation.
  const [participantPhotos, setParticipantPhotos] = useState<{
    [uid: string]: string;
  }>({});
  const fetchedParticipantIds = useRef(new Set<string>());
  // Only one row stays open at a time, the way a list row behaves on iOS.
  const openRow = useRef<Swipeable | null>(null);

  const loadMissingPhotos = useCallback(async (convos: Conversation[]) => {
    const needed = new Set<string>();
    for (const convo of convos) {
      for (const id of convo.participantIds) {
        // A photo already on the conversation document wins — it is what this
        // app writes when it creates one.
        if (convo.participantPhotos?.[id]) {continue;}
        if (fetchedParticipantIds.current.has(id)) {continue;}
        needed.add(id);
      }
    }
    if (needed.size === 0) {return;}

    const ids = [...needed];
    ids.forEach(id => fetchedParticipantIds.current.add(id));
    const photos = await messageService.fetchParticipantPhotos(ids);
    if (Object.keys(photos).length > 0) {
      setParticipantPhotos(prev => ({...prev, ...photos}));
    }
  }, []);

  useEffect(() => {
    // Conversations are keyed by username (userId), not the Firebase Auth uid.
    if (!currentUser) {return;}
    const unsub = messageService.subscribeToConversations(
      currentUser.userId,
      convos => {
        setConversations(convos);
        setLoading(false);
        loadMissingPhotos(convos);
      },
    );
    return unsub;
  }, [currentUser, loadMissingPhotos]);

  function avatarUrl(convo: Conversation, userId: string): string | undefined {
    return convo.participantPhotos?.[userId] || participantPhotos[userId];
  }

  function openConversation(convo: Conversation) {
    const isGroup = isGroupConversation(convo);
    navigation.navigate('Conversation', {
      conversationId: convo.id,
      otherUserId: otherParticipantId(convo, currentUser?.userId ?? '') ?? '',
      otherUserName: conversationDisplayName(convo, currentUser?.userId ?? ''),
      isGroup,
    });
  }

  // Both pickers hand back a conversation that already exists in Firestore, so
  // the sheet closes and the thread opens straight away — the list catches up
  // on its own when the snapshot arrives.
  function openNewConversation(conversationId: string, contact: Contact) {
    setShowNewMessage(false);
    navigation.navigate('Conversation', {
      conversationId,
      otherUserId: contact.id,
      otherUserName: contact.name,
      isGroup: false,
    });
  }

  function openNewGroup(conversationId: string, groupName: string) {
    setShowNewGroup(false);
    navigation.navigate('Conversation', {
      conversationId,
      otherUserId: '',
      otherUserName: groupName,
      isGroup: true,
    });
  }

  // Swiping a conversation away means different things depending on who owns
  // it, mirroring the iOS Messages list: a 1:1 chat and a group you created are
  // deleted for everyone, a group someone else created you simply leave.
  function handleSwipeDelete(convo: Conversation) {
    if (!currentUser) {return;}

    if (!isGroupConversation(convo)) {
      const name = otherParticipantName(convo, currentUser.userId);
      Alert.alert(
        'Delete Conversation?',
        `This will permanently delete your conversation with ${name} and all of its messages.`,
        [
          {text: 'Cancel', style: 'cancel'},
          {
            text: 'Delete',
            style: 'destructive',
            onPress: () => deleteConversation(convo),
          },
        ],
      );
      return;
    }

    if (convo.groupCreatorId === currentUser.userId) {
      Alert.alert(
        'Delete Group Chat?',
        'This will permanently delete the group chat and all its messages for every member.',
        [
          {text: 'Cancel', style: 'cancel'},
          {
            text: 'Delete for Everyone',
            style: 'destructive',
            onPress: () => deleteConversation(convo),
          },
        ],
      );
      return;
    }

    Alert.alert(
      'Leave Group?',
      `You will stop receiving messages from ${conversationDisplayName(
        convo,
        currentUser.userId,
      )} and it will be removed from your list.`,
      [
        {text: 'Cancel', style: 'cancel'},
        {
          text: 'Leave',
          style: 'destructive',
          onPress: () => leaveGroup(convo),
        },
      ],
    );
  }

  async function deleteConversation(convo: Conversation) {
    try {
      // The row disappears on its own — the conversations listener fires as
      // soon as the document is gone.
      await messageService.deleteConversation(convo.id);
    } catch (err: any) {
      Alert.alert('Error', err?.message ?? 'Failed to delete this conversation.');
    }
  }

  async function leaveGroup(convo: Conversation) {
    if (!currentUser) {return;}
    try {
      await messageService.removeGroupMember(convo.id, currentUser.userId);
    } catch (err: any) {
      Alert.alert('Error', err?.message ?? 'Failed to leave this group.');
    }
  }

  function renderRightActions(convo: Conversation, row: Swipeable | null) {
    // A group you did not create is left rather than deleted, so the action
    // says so — the same split the iOS swipe action makes.
    const isLeaving =
      isGroupConversation(convo) && convo.groupCreatorId !== currentUser?.userId;

    return (
      <View style={styles.swipeActions}>
        <TouchableOpacity
          style={[styles.swipeAction, {backgroundColor: Colors.red}]}
          onPress={() => {
            row?.close();
            handleSwipeDelete(convo);
          }}
          activeOpacity={0.8}>
          <Icon
            name={isLeaving ? 'exit-outline' : 'trash-outline'}
            size={22}
            color="#fff"
          />
          <Text style={styles.swipeActionText}>
            {isLeaving ? 'Leave' : 'Delete'}
          </Text>
        </TouchableOpacity>
      </View>
    );
  }

  function renderConvo({item}: {item: Conversation}) {
    const userId = currentUser?.userId ?? '';
    const isGroup = isGroupConversation(item);
    const otherId = otherParticipantId(item, userId);
    const title = conversationDisplayName(item, userId);
    const unread = unreadCountFor(item, userId);
    const timeStr = formatConversationTime(timestampMillis(item.lastMessageAt));
    const members = isGroup ? memberNamesSubtitle(item, userId) : '';
    // lastMessageContent is the field both platforms keep current — iOS never
    // writes lastMessage, so preferring that one left the preview stuck on the
    // last message this app sent.
    const preview = item.lastMessageContent || item.lastMessage || '';

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
          style={[styles.convoCard, cardStyle(scheme)]}
          onPress={() => openConversation(item)}
          onLongPress={() => handleSwipeDelete(item)}
          activeOpacity={0.75}>
          {isGroup ? (
            <View style={styles.groupAvatar}>
              <Icon name="people" size={22} color={Colors.purple} />
            </View>
          ) : (
            <ProfileAvatar
              url={otherId ? avatarUrl(item, otherId) : undefined}
              name={title}
              size={46}
            />
          )}
          <View style={styles.convoContent}>
            <View style={styles.convoTop}>
              <Text
                style={[styles.convoName, {color: textPrimary(scheme)}]}
                numberOfLines={1}>
                {title}
              </Text>
              {/* iOS shows the other person's username next to their name so
                  two contacts with the same display name stay distinct. */}
              {!isGroup && !!otherId && (
                <Text
                  style={[styles.convoHandle, {color: textSecondary(scheme)}]}
                  numberOfLines={1}>
                  @{otherId}
                </Text>
              )}
              <View style={{flex: 1}} />
              <Text style={[styles.convoTime, {color: textSecondary(scheme)}]}>
                {timeStr}
              </Text>
            </View>
            <View style={styles.convoBottom}>
              {isGroup && !!members && (
                <Text
                  style={[styles.members, {color: textSecondary(scheme)}]}
                  numberOfLines={1}>
                  {members}
                </Text>
              )}
              {preview ? (
                <Text
                  style={[styles.lastMsg, {color: textSecondary(scheme)}]}
                  numberOfLines={1}>
                  {preview}
                </Text>
              ) : (
                // A group row already carries its member list as a subtitle, so
                // iOS only falls back to this placeholder on 1:1 rows.
                !isGroup && (
                  <Text
                    style={[
                      styles.lastMsg,
                      styles.lastMsgEmpty,
                      {color: textSecondary(scheme)},
                    ]}
                    numberOfLines={1}>
                    No messages yet
                  </Text>
                )
              )}
              {unread > 0 && (
                <View style={styles.badge}>
                  <Text style={styles.badgeText}>
                    {unread > 99 ? '99+' : unread}
                  </Text>
                </View>
              )}
            </View>
          </View>
        </TouchableOpacity>
      </Swipeable>
    );
  }

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}}>
        <View style={styles.header}>
          <Text style={[styles.headerTitle, {color: textPrimary(scheme)}]}>
            Messages
          </Text>
          {/* The iOS toolbar's two actions: person.3 starts a group, and
              square.and.pencil starts a 1:1 message. */}
          <View style={styles.headerActions}>
            <TouchableOpacity
              style={[styles.headerBtn, {backgroundColor: Colors.blue + '1F'}]}
              onPress={() => setShowNewGroup(true)}
              hitSlop={6}
              activeOpacity={0.75}>
              <Icon name="people" size={20} color={Colors.blue} />
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.headerBtn, {backgroundColor: Colors.blue + '1F'}]}
              onPress={() => setShowNewMessage(true)}
              hitSlop={6}
              activeOpacity={0.75}>
              <Icon name="create-outline" size={20} color={Colors.blue} />
            </TouchableOpacity>
          </View>
        </View>

        {loading ? (
          <View style={styles.center}>
            <ActivityIndicator size="large" color={Colors.blue} />
          </View>
        ) : conversations.length === 0 ? (
          <View style={styles.center}>
            <Icon name="chatbubbles-outline" size={60} color={textSecondary(scheme)} />
            <Text style={[styles.emptyText, {color: textSecondary(scheme)}]}>
              No conversations yet.{'\n'}Start one to share stores and reminders.
            </Text>
            {/* iOS puts the same "New Message" call to action in its empty
                state, so the tab is never a dead end. */}
            <PrimaryButton
              title="New Message"
              onPress={() => setShowNewMessage(true)}
              style={styles.emptyBtn}
            />
          </View>
        ) : (
          <FlatList
            data={conversations}
            renderItem={renderConvo}
            keyExtractor={item => item.id}
            contentContainerStyle={styles.list}
          />
        )}
      </SafeAreaView>

      <NewMessageSheet
        visible={showNewMessage}
        onClose={() => setShowNewMessage(false)}
        onConversationReady={openNewConversation}
      />
      <NewGroupSheet
        visible={showNewGroup}
        onClose={() => setShowNewGroup(false)}
        onGroupCreated={openNewGroup}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: '700',
    flex: 1,
  },
  headerActions: {
    flexDirection: 'row',
    gap: Spacing.sm,
  },
  headerBtn: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: 'center',
    justifyContent: 'center',
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
  emptyBtn: {
    marginTop: Spacing.lg,
    width: 220,
  },
  list: {
    paddingHorizontal: Spacing.md,
    paddingBottom: 20,
  },
  convoCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.md,
  },
  groupAvatar: {
    width: 46,
    height: 46,
    borderRadius: 23,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.purple + '2E',
  },
  convoContent: {
    flex: 1,
    marginLeft: Spacing.md,
  },
  convoTop: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 4,
  },
  convoName: {
    fontSize: 16,
    fontWeight: '600',
    flexShrink: 1,
  },
  convoHandle: {
    fontSize: 12,
    marginLeft: 4,
    flexShrink: 1,
  },
  convoTime: {
    fontSize: 12,
    marginLeft: Spacing.sm,
  },
  convoBottom: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  members: {
    fontSize: 12,
    flexShrink: 1,
    marginRight: Spacing.sm,
  },
  lastMsg: {
    fontSize: 14,
    flex: 1,
    marginRight: Spacing.sm,
  },
  lastMsgEmpty: {
    fontStyle: 'italic',
  },
  badge: {
    backgroundColor: Colors.blue,
    borderRadius: 10,
    minWidth: 20,
    height: 20,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 4,
  },
  badgeText: {
    color: '#fff',
    fontSize: 11,
    fontWeight: '700',
  },
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
});
