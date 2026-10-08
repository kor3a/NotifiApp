import React, {useEffect, useMemo, useRef, useState} from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  TouchableOpacity,
  Modal,
  TextInput,
  Alert,
  Share,
  ToastAndroid,
  useColorScheme,
  ActivityIndicator,
  ColorSchemeName,
  KeyboardAvoidingView,
  Platform,
  Pressable,
} from 'react-native';
import {SafeAreaView, useSafeAreaInsets} from 'react-native-safe-area-context';
import {Swipeable} from 'react-native-gesture-handler';
import Icon from '../../components/AppIcon';

import GradientBackground from '../../components/GradientBackground';
import ProfileAvatar from '../../components/ProfileAvatar';
import {
  Colors,
  Spacing,
  cardStyle,
  cardBackground,
  sheetBackground,
  sheetFill,
  textPrimary,
  textSecondary,
} from '../../theme/AppTheme';
import {useSession} from '../../context/SessionContext';
import {friendService, FriendInfo} from '../../services/friendService';
import {messageService} from '../../services/messageService';
import {Friendship, User} from '../../models';
import {useNavigation} from '@react-navigation/native';

// The iOS screen's accent (terracotta) and Family (sage) roles, in the Android
// app's blue/green palette.
function palette(scheme: ColorSchemeName) {
  const dark = scheme === 'dark';
  return {
    accent: Colors.blue,
    accentTint: dark ? 'rgba(0,122,255,0.22)' : 'rgba(0,122,255,0.10)',
    family: dark ? '#1F3A28' : '#DDF3E3',
    familyInk: dark ? '#5FD982' : '#1E7A35',
    outline: dark ? 'rgba(255,255,255,0.18)' : 'rgba(0,0,0,0.12)',
  };
}

const APP_STORE_LINK =
  'https://apps.apple.com/us/app/allim-smart-shopping-list/id6758680783';
const PLAY_STORE_LINK =
  'https://play.google.com/store/apps/details?id=com.allimandroid';

function toast(message: string) {
  ToastAndroid.show(message, ToastAndroid.SHORT);
}

// createdAt is epoch seconds on current documents; older ones may carry a
// Firestore Timestamp.
function createdAtMillis(f: Friendship): number {
  const c = f.createdAt;
  if (typeof c === 'number') {return c * 1000;}
  if (c && typeof c.toMillis === 'function') {return c.toMillis();}
  return 0;
}

// Case- and accent-insensitive, like the iOS search.
function fold(s: string): string {
  return s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
}

type Row =
  | {kind: 'label'; key: string; title: string; count: number; highlighted?: boolean}
  | {kind: 'request'; key: string; friendship: Friendship}
  | {kind: 'sent'; key: string; friendship: Friendship}
  | {kind: 'friend'; key: string; friendship: Friendship; isFamily: boolean}
  | {kind: 'noResults'; key: string}
  | {kind: 'empty'; key: string};

export default function FriendsScreen() {
  const scheme = useColorScheme();
  const p = palette(scheme);
  const navigation = useNavigation<any>();
  const {currentUser} = useSession();
  const myId = currentUser?.userId ?? '';

  const [friendships, setFriendships] = useState<Friendship[]>([]);
  const [familyIds, setFamilyIds] = useState<string[]>(
    currentUser?.familyMemberIds ?? [],
  );
  const [pictures, setPictures] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [searchText, setSearchText] = useState('');
  // While on, family members show a control to take them back out. Adding is
  // always one tap; removing sits behind Manage so it can't happen by
  // accident on a list the user is only scrolling through.
  const [isManagingFamily, setIsManagingFamily] = useState(false);
  const [showAddFriend, setShowAddFriend] = useState(false);
  const openRow = useRef<Swipeable | null>(null);

  useEffect(() => {
    // Friendships are keyed by username (userId), not the Firebase Auth uid.
    if (!myId) {return;}
    const unsubFriendships = friendService.subscribeToFriendships(myId, f => {
      setFriendships(f);
      setLoading(false);
    });
    const unsubFamily = friendService.subscribeToFamilyIds(myId, setFamilyIds);
    return () => {
      unsubFriendships();
      unsubFamily();
    };
  }, [myId]);

  // Pull everyone's current photo; the copies on the friendship documents
  // are only what keeps avatars from flashing while this is in flight.
  const friendIdsKey = useMemo(
    () =>
      friendships
        .map(f => friendService.friendOf(f, myId).userId)
        .sort()
        .join(','),
    [friendships, myId],
  );
  useEffect(() => {
    if (!friendIdsKey) {return;}
    let cancelled = false;
    friendService
      .fetchProfilePictures(friendIdsKey.split(','))
      .then(fresh => {
        if (!cancelled) {setPictures(prev => ({...prev, ...fresh}));}
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [friendIdsKey]);

  // ─── Split and sort, as the iOS view model does ─────────────────────────────

  const sections = useMemo(() => {
    const family: Friendship[] = [];
    const others: Friendship[] = [];
    const received: Friendship[] = [];
    const sent: Friendship[] = [];
    for (const f of friendships) {
      if (f.status === 'accepted') {
        const id = friendService.friendOf(f, myId).userId;
        (familyIds.includes(id) ? family : others).push(f);
      } else if (f.status === 'pending') {
        (f.receiverId === myId ? received : sent).push(f);
      }
    }
    // Friends and family read alphabetically; requests stay newest-first so
    // the most recent one is the first thing to answer.
    const byName = (a: Friendship, b: Friendship) => {
      const fa = friendService.friendOf(a, myId);
      const fb = friendService.friendOf(b, myId);
      return (
        fa.name.localeCompare(fb.name, undefined, {sensitivity: 'base'}) ||
        (fa.userId < fb.userId ? -1 : fa.userId > fb.userId ? 1 : 0)
      );
    };
    const newest = (a: Friendship, b: Friendship) =>
      createdAtMillis(b) - createdAtMillis(a);
    return {
      family: family.sort(byName),
      friends: others.sort(byName),
      received: received.sort(newest),
      sent: sent.sort(newest),
    };
  }, [friendships, familyIds, myId]);

  // Manage lives on the Family card; once the last member is removed that
  // card goes away and nothing could switch it back off.
  useEffect(() => {
    if (sections.family.length === 0) {setIsManagingFamily(false);}
  }, [sections.family.length]);

  const query = fold(searchText.trim());
  const isFiltering = query.length > 0;
  const matches = (f: Friendship) => {
    if (!isFiltering) {return true;}
    const info = friendService.friendOf(f, myId);
    return [info.name, info.email, info.userId].some(field =>
      fold(field).includes(query),
    );
  };

  const filtered = {
    family: sections.family.filter(matches),
    friends: sections.friends.filter(matches),
    received: sections.received.filter(matches),
    sent: sections.sent.filter(matches),
  };

  const hasNoConnections =
    sections.family.length === 0 &&
    sections.friends.length === 0 &&
    sections.received.length === 0 &&
    sections.sent.length === 0;

  const rows: Row[] = [];
  // Received requests sit above everything else — they're the only rows on
  // the screen waiting on the user to do something.
  if (filtered.received.length > 0) {
    rows.push({kind: 'label', key: 'l-req', title: 'Requests', count: filtered.received.length, highlighted: true});
    filtered.received.forEach(f => rows.push({kind: 'request', key: f.id, friendship: f}));
  }
  if (filtered.sent.length > 0) {
    rows.push({kind: 'label', key: 'l-sent', title: 'Waiting on them', count: filtered.sent.length});
    filtered.sent.forEach(f => rows.push({kind: 'sent', key: f.id, friendship: f}));
  }
  // Family and friends share one list. Family members keep their own badge
  // rather than a separate section, so the list reads as the whole address
  // book instead of the same names split across two places.
  const allCount = filtered.family.length + filtered.friends.length;
  if (allCount > 0) {
    rows.push({kind: 'label', key: 'l-all', title: 'All friends', count: allCount});
    filtered.family.forEach(f => rows.push({kind: 'friend', key: f.id, friendship: f, isFamily: true}));
    filtered.friends.forEach(f => rows.push({kind: 'friend', key: f.id, friendship: f, isFamily: false}));
  }
  if (isFiltering && rows.length === 0) {
    rows.push({kind: 'noResults', key: 'no-results'});
  }
  if (hasNoConnections && !isFiltering) {
    rows.push({kind: 'empty', key: 'empty'});
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  function friendOf(f: Friendship): FriendInfo {
    const info = friendService.friendOf(f, myId);
    return {...info, photo: pictures[info.userId] ?? info.photo};
  }

  async function handleAccept(f: Friendship) {
    try {
      await friendService.acceptRequest(f.id);
      toast(`You are now friends with ${friendOf(f).name}`);
    } catch (err: any) {
      Alert.alert('Error', err.message);
    }
  }

  async function handleDecline(f: Friendship) {
    try {
      await friendService.rejectRequest(f.id);
      toast('Friend request declined');
    } catch (err: any) {
      Alert.alert('Error', err.message);
    }
  }

  function confirmCancel(f: Friendship) {
    Alert.alert('Cancel Request', `Cancel your friend request to ${friendOf(f).name}?`, [
      {text: 'No', style: 'cancel'},
      {
        text: 'Yes, Cancel',
        style: 'destructive',
        onPress: async () => {
          try {
            await friendService.removeFriend(f.id);
            toast('Friend request cancelled');
          } catch (err: any) {
            Alert.alert('Error', err.message);
          }
        },
      },
    ]);
  }

  function confirmRemove(f: Friendship) {
    const name = friendOf(f).name;
    Alert.alert('Remove Friend', `Are you sure you want to remove ${name} from your friends?`, [
      {text: 'Cancel', style: 'cancel'},
      {
        text: 'Remove',
        style: 'destructive',
        onPress: async () => {
          try {
            await friendService.removeFriend(f.id);
            toast(`${name} removed from friends`);
          } catch (err: any) {
            Alert.alert('Error', err.message);
          }
        },
      },
    ]);
  }

  async function toggleFamily(f: Friendship, isFamily: boolean) {
    const {userId, name} = friendOf(f);
    try {
      if (isFamily) {
        await friendService.removeFromFamily(myId, userId);
        toast(`${name} removed from Family`);
      } else {
        await friendService.addToFamily(myId, userId);
        toast(`${name} added to Family`);
      }
    } catch (err: any) {
      Alert.alert(
        'Error',
        err.message ?? (isFamily ? 'Failed to remove from family' : 'Failed to add to family'),
      );
    }
  }

  async function handleMessage(f: Friendship) {
    if (!currentUser) {return;}
    const other = friendOf(f);
    const convoId = await messageService.getOrCreateConversation(
      currentUser.userId,
      other.userId,
      currentUser.name,
      other.name,
      currentUser.profilePictureURL,
      other.photo,
    );
    navigation.navigate('Messages', {
      screen: 'Conversation',
      params: {
        conversationId: convoId,
        otherUserId: other.userId,
        otherUserName: other.name,
      },
    });
  }

  function inviteFriends() {
    Share.share({
      message: `I'm using Allim for my shopping lists. Get it here:\nAndroid: ${PLAY_STORE_LINK}\niPhone: ${APP_STORE_LINK}`,
    }).catch(() => {});
  }

  // ─── Rows ───────────────────────────────────────────────────────────────────

  function renderSwipeAction(label: string, icon: any, onPress: () => void, row: () => Swipeable | null) {
    return (
      <TouchableOpacity
        style={styles.swipeAction}
        activeOpacity={0.8}
        onPress={() => {
          row()?.close();
          onPress();
        }}>
        <Icon name={icon} size={22} color="#fff" />
        <Text style={styles.swipeActionText}>{label}</Text>
      </TouchableOpacity>
    );
  }

  function swipeable(
    key: string,
    action: {label: string; icon: any; onPress: () => void},
    child: React.ReactNode,
  ) {
    let row: Swipeable | null = null;
    return (
      <Swipeable
        key={key}
        ref={ref => {
          row = ref;
        }}
        renderRightActions={() =>
          renderSwipeAction(action.label, action.icon, action.onPress, () => row)
        }
        overshootRight={false}
        rightThreshold={40}
        onSwipeableWillOpen={() => {
          if (openRow.current && openRow.current !== row) {
            openRow.current.close();
          }
          openRow.current = row;
        }}>
        {child}
      </Swipeable>
    );
  }

  function renderSectionLabel(title: string, count: number, highlighted?: boolean) {
    return (
      <View style={styles.sectionLabel}>
        <Text style={[styles.sectionTitle, {color: textPrimary(scheme)}]}>{title}</Text>
        {highlighted ? (
          <View style={[styles.countPill, {backgroundColor: p.accent}]}>
            <Text style={styles.countPillText}>{count}</Text>
          </View>
        ) : (
          <Text style={[styles.countText, {color: textSecondary(scheme)}]}>{count}</Text>
        )}
      </View>
    );
  }

  // An incoming request sits on the accent tint rather than the plain card so
  // the rows that need an answer stand out, and leads with a full Accept pill
  // because that's the likely answer.
  function renderRequest(f: Friendship) {
    const info = friendOf(f);
    return (
      <View style={[cardStyle(scheme), styles.card, {backgroundColor: scheme === 'dark' ? '#23324A' : '#E3EEFC'}]}>
        <ProfileAvatar url={info.photo} name={info.name} size={52} />
        <View style={styles.rowText}>
          <Text style={[styles.requestName, {color: textPrimary(scheme)}]} numberOfLines={1}>
            {info.name}
          </Text>
          <Text style={[styles.subtitle, {color: textSecondary(scheme)}]} numberOfLines={2}>
            wants to share lists
          </Text>
        </View>
        <View style={styles.controls}>
          <TouchableOpacity
            style={[styles.acceptPill, {backgroundColor: p.accent}]}
            onPress={() => handleAccept(f)}
            accessibilityLabel={`Accept request from ${info.name}`}>
            <Text style={styles.acceptText}>Accept</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.outlineCircle, {borderColor: p.outline}]}
            onPress={() => handleDecline(f)}
            accessibilityLabel={`Decline request from ${info.name}`}>
            <Icon name="close" size={18} color={textSecondary(scheme)} />
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  // A request the user sent that hasn't been answered. Nothing to act on, so
  // it stays quiet: no card fill, just an outline and the cancel affordance.
  function renderSent(f: Friendship) {
    const info = friendOf(f);
    return swipeable(
      f.id,
      {label: 'Cancel', icon: 'close', onPress: () => confirmCancel(f)},
      <View style={[styles.card, styles.sentCard, {borderColor: p.outline}]}>
        <View style={{opacity: 0.6}}>
          <ProfileAvatar url={info.photo} name={info.name} size={46} />
        </View>
        <View style={styles.rowText}>
          <Text style={[styles.name, {color: textPrimary(scheme), opacity: 0.8}]} numberOfLines={1}>
            {info.name}
          </Text>
          <Text style={[styles.subtitle, {color: textSecondary(scheme)}]} numberOfLines={1}>
            Request sent
          </Text>
        </View>
        <TouchableOpacity
          style={[styles.outlineCircle, {borderColor: p.outline}]}
          onPress={() => confirmCancel(f)}
          accessibilityLabel={`Cancel request to ${info.name}`}>
          <Icon name="close" size={17} color={textSecondary(scheme)} />
        </TouchableOpacity>
      </View>,
    );
  }

  function renderFriend(f: Friendship, isFamily: boolean) {
    const info = friendOf(f);
    return swipeable(
      f.id,
      {label: 'Remove', icon: 'person-remove', onPress: () => confirmRemove(f)},
      <Pressable
        style={[cardStyle(scheme), styles.card]}
        // Messaging and Family both have their own button on the row, so the
        // long press is left with the one action that doesn't.
        onLongPress={() => confirmRemove(f)}>
        <ProfileAvatar url={info.photo} name={info.name} size={48} />
        <View style={styles.rowText}>
          <View style={styles.nameLine}>
            <Text style={[styles.name, styles.nameShrink, {color: textPrimary(scheme)}]} numberOfLines={1}>
              {info.name}
            </Text>
            {isFamily && (
              <View style={[styles.familyBadge, {backgroundColor: p.family}]}>
                <Text style={[styles.familyBadgeText, {color: p.familyInk}]}>FAMILY</Text>
              </View>
            )}
          </View>
          <Text style={[styles.subtitle, {color: textSecondary(scheme)}]} numberOfLines={1}>
            @{info.userId}
          </Text>
        </View>
        <View style={styles.controls}>
          {/* An outlined house on anyone who isn't in Family yet, and — only
              while Family is being managed — a crossed-out one on those who
              are. Otherwise the FAMILY badge already says they're in. */}
          {!isFamily ? (
            <TouchableOpacity
              style={[styles.roundBtn, {backgroundColor: p.family}]}
              onPress={() => toggleFamily(f, false)}
              accessibilityLabel={`Add ${info.name} to Family`}>
              <Icon name="home-outline" size={18} color={p.familyInk} />
            </TouchableOpacity>
          ) : isManagingFamily ? (
            <TouchableOpacity
              style={[styles.roundBtn, {backgroundColor: p.familyInk}]}
              onPress={() => toggleFamily(f, true)}
              accessibilityLabel={`Remove ${info.name} from Family`}>
              <Icon name="home" size={17} color={scheme === 'dark' ? '#10261A' : '#fff'} />
              <View style={[styles.slash, {backgroundColor: scheme === 'dark' ? '#10261A' : '#fff', borderColor: p.familyInk}]} />
            </TouchableOpacity>
          ) : null}
          <TouchableOpacity
            style={[styles.roundBtn, {backgroundColor: p.accentTint}]}
            onPress={() => handleMessage(f)}
            accessibilityLabel={`Message ${info.name}`}>
            <Icon name="chatbubble" size={17} color={p.accent} />
          </TouchableOpacity>
        </View>
      </Pressable>,
    );
  }

  function renderEmpty() {
    return (
      <View style={styles.empty}>
        <View style={[styles.emptyIcon, {backgroundColor: p.accentTint}]}>
          <Icon name="people-outline" size={44} color={p.accent} />
        </View>
        <Text style={[styles.emptyTitle, {color: textPrimary(scheme)}]}>No friends yet</Text>
        <Text style={[styles.emptyBody, {color: textSecondary(scheme)}]}>
          Add friends to share stores and reminders with the people you shop for.
        </Text>
        <TouchableOpacity
          style={[styles.primaryPill, {backgroundColor: p.accent}]}
          onPress={() => setShowAddFriend(true)}>
          <Text style={styles.primaryPillText}>Add a friend</Text>
        </TouchableOpacity>
        <TouchableOpacity onPress={inviteFriends}>
          <Text style={[styles.inviteText, {color: p.accent}]}>Invite friends to Allim</Text>
        </TouchableOpacity>
      </View>
    );
  }

  function renderNoResults() {
    return (
      <View style={[styles.empty, {paddingTop: 40}]}>
        <View style={[styles.noResultsIcon, {backgroundColor: p.accentTint}]}>
          <Icon name="search" size={30} color={p.accent} />
        </View>
        <Text style={[styles.noResultsTitle, {color: textPrimary(scheme)}]}>No matches</Text>
        <Text style={[styles.emptyBody, {color: textSecondary(scheme)}]}>
          Nobody matches {'“'}{searchText.trim()}{'”'}
        </Text>
      </View>
    );
  }

  function renderRow({item}: {item: Row}) {
    switch (item.kind) {
      case 'label':
        return renderSectionLabel(item.title, item.count, item.highlighted);
      case 'request':
        return renderRequest(item.friendship);
      case 'sent':
        return renderSent(item.friendship);
      case 'friend':
        return renderFriend(item.friendship, item.isFamily);
      case 'noResults':
        return renderNoResults();
      case 'empty':
        return renderEmpty();
    }
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  // Overlapping avatars for the Family card. Four circles wide at most,
  // counting the "+n" disc, so a large family takes no more room than a small
  // one and the caption beside it keeps its width.
  function renderAvatarStack(members: Friendship[]) {
    const shown = members.slice(0, members.length > 4 ? 3 : 4);
    const overflow = members.length - shown.length;
    return (
      <View
        style={styles.avatarStack}
        accessible
        accessibilityLabel={`${members.length} family members`}>
        {shown.map((f, i) => {
          const info = friendOf(f);
          return (
            <View
              key={f.id}
              style={[styles.stackRing, {borderColor: p.family, marginLeft: i === 0 ? 0 : -16}]}>
              <ProfileAvatar url={info.photo} name={info.name} size={40} />
            </View>
          );
        })}
        {overflow > 0 && (
          <View
            style={[
              styles.stackRing,
              styles.overflowDisc,
              {borderColor: p.family, backgroundColor: p.familyInk + '2E'},
            ]}>
            <Text style={[styles.overflowText, {color: p.familyInk}]}>+{overflow}</Text>
          </View>
        )}
      </View>
    );
  }

  // The Family summary card. Family otherwise only shows up as a sort order
  // inside the share sheets, so this states what the group is for.
  function renderFamilyCard() {
    const count = sections.family.length;
    return (
      <View style={[styles.familyCard, {backgroundColor: p.family}]}>
        <View style={styles.familyTop}>
          <View style={{flex: 1}}>
            <Text style={[styles.familyTitle, {color: p.familyInk}]}>Family</Text>
            <Text style={[styles.familySubtitle, {color: p.familyInk}]}>
              {count === 1 ? '1 person you share with first' : `${count} people you share with first`}
            </Text>
          </View>
          <TouchableOpacity
            onPress={() => setIsManagingFamily(m => !m)}
            style={[
              styles.managePill,
              {
                borderColor: p.familyInk + '59',
                backgroundColor: isManagingFamily ? p.familyInk + '26' : 'transparent',
              },
            ]}
            accessibilityLabel={isManagingFamily ? 'Finish managing Family' : 'Manage Family'}>
            <Text style={[styles.manageText, {color: p.familyInk}]}>
              {isManagingFamily ? 'Done' : 'Manage'}
            </Text>
          </TouchableOpacity>
        </View>
        <View style={styles.familyBottom}>
          {renderAvatarStack(sections.family)}
          <Text style={[styles.familyCaption, {color: p.familyInk}]}>
            {isManagingFamily
              ? 'Tap the house on a member to take them out.'
              : 'Shared stores and reminders reach them first.'}
          </Text>
        </View>
      </View>
    );
  }

  const header = (
    <View style={styles.header}>
      <View style={styles.titleRow}>
        {/* Pushed from Profile now that Friends has no tab of its own. */}
        {navigation.canGoBack() && (
          <TouchableOpacity
            onPress={() => navigation.goBack()}
            style={styles.backBtn}
            accessibilityLabel="Back">
            <Icon name="chevron-back" size={28} color={p.accent} />
          </TouchableOpacity>
        )}
        <Text style={[styles.headerTitle, {color: textPrimary(scheme)}]}>Friends</Text>
        <TouchableOpacity
          onPress={() => setShowAddFriend(true)}
          style={[styles.addBtn, {backgroundColor: p.accent}]}
          accessibilityLabel="Add friend">
          <Icon name="person-add" size={22} color="#fff" />
        </TouchableOpacity>
      </View>

      <View style={[styles.searchField, {backgroundColor: cardBackground(scheme)}]}>
        <Icon name="search" size={18} color={textSecondary(scheme)} />
        <TextInput
          value={searchText}
          onChangeText={setSearchText}
          placeholder="Search friends"
          placeholderTextColor={textSecondary(scheme)}
          autoCapitalize="none"
          autoCorrect={false}
          returnKeyType="search"
          style={[styles.searchInput, {color: textPrimary(scheme)}]}
        />
        {searchText.length > 0 && (
          <TouchableOpacity onPress={() => setSearchText('')} accessibilityLabel="Clear search">
            <Icon name="close-circle" size={18} color={textSecondary(scheme)} />
          </TouchableOpacity>
        )}
      </View>

      {sections.family.length > 0 && !isFiltering && renderFamilyCard()}
    </View>
  );

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}} edges={['top', 'left', 'right']}>
        {loading && friendships.length === 0 ? (
          <>
            {header}
            <View style={styles.center}>
              <ActivityIndicator size="large" color={p.accent} />
            </View>
          </>
        ) : (
          <FlatList
            data={rows}
            keyExtractor={item => item.key}
            renderItem={renderRow}
            ListHeaderComponent={header}
            contentContainerStyle={styles.list}
            keyboardShouldPersistTaps="handled"
            keyboardDismissMode="on-drag"
          />
        )}
      </SafeAreaView>

      <AddFriendSheet
        visible={showAddFriend}
        onClose={() => setShowAddFriend(false)}
        currentUser={currentUser}
        friendships={friendships}
      />
    </View>
  );
}

// ─── Add Friend Sheet ─────────────────────────────────────────────────────────

function AddFriendSheet({
  visible,
  onClose,
  currentUser,
  friendships,
}: {
  visible: boolean;
  onClose: () => void;
  currentUser: User | null;
  friendships: Friendship[];
}) {
  const scheme = useColorScheme();
  const p = palette(scheme);
  const insets = useSafeAreaInsets();
  const [query, setQuery] = useState('');
  const [searching, setSearching] = useState(false);
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState<User | null>(null);
  const [searched, setSearched] = useState(false);

  function close() {
    setQuery('');
    setResult(null);
    setSearched(false);
    onClose();
  }

  async function runSearch() {
    const q = query.trim();
    if (!q || !currentUser) {return;}
    setSearching(true);
    setResult(null);
    try {
      const found = q.includes('@') && !q.startsWith('@')
        ? await friendService.searchByEmail(q)
        : await friendService.searchByUsername(q);
      setResult(found && found.userId !== currentUser.userId ? found : null);
    } catch (err: any) {
      Alert.alert('Error', err.message ?? 'Search failed.');
    } finally {
      setSearched(true);
      setSearching(false);
    }
  }

  async function sendRequest(user: User) {
    if (!currentUser) {return;}
    setSending(true);
    try {
      await friendService.sendFriendRequest(currentUser, user);
      toast(`Friend request sent to ${user.name}`);
      close();
    } catch (err: any) {
      Alert.alert('Error', err.message ?? 'Failed to send request.');
    } finally {
      setSending(false);
    }
  }

  function statusFor(user: User) {
    const existing = friendships.find(
      f =>
        f.status !== 'rejected' &&
        (f.requesterId === user.userId || f.receiverId === user.userId),
    );
    if (!existing) {return null;}
    if (existing.status === 'accepted') {
      return {title: 'Friends', tint: p.familyInk, fill: p.family};
    }
    return existing.requesterId === currentUser?.userId
      ? {title: 'Pending', tint: textSecondary(scheme), fill: sheetFill(scheme)}
      : {title: 'Respond', tint: p.accent, fill: p.accentTint};
  }

  const status = result ? statusFor(result) : null;

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={close}>
      <KeyboardAvoidingView
        style={{flex: 1}}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <Pressable style={styles.modalOverlay} onPress={close}>
          <Pressable
            style={[
              styles.sheet,
              {backgroundColor: sheetBackground(scheme), paddingBottom: insets.bottom + 32},
            ]}
            onPress={() => {}}>
            <View style={styles.sheetTopBar}>
              <TouchableOpacity onPress={close}>
                <Text style={[styles.sheetCancel, {color: p.accent}]}>Cancel</Text>
              </TouchableOpacity>
            </View>
            <Text style={[styles.sheetTitle, {color: textPrimary(scheme)}]}>Add a friend</Text>
            <Text style={[styles.sheetSubtitle, {color: textSecondary(scheme)}]}>
              Search by email address or username to send them a request.
            </Text>

            <View style={[styles.queryField, {backgroundColor: sheetFill(scheme)}]}>
              <Icon name="search" size={18} color={textSecondary(scheme)} />
              <TextInput
                value={query}
                onChangeText={text => {
                  setQuery(text);
                  setSearched(false);
                }}
                placeholder="Email or username"
                placeholderTextColor={textSecondary(scheme)}
                autoCapitalize="none"
                autoCorrect={false}
                keyboardType="email-address"
                returnKeyType="search"
                onSubmitEditing={runSearch}
                autoFocus
                style={[styles.searchInput, {color: textPrimary(scheme)}]}
              />
              {searching ? (
                <ActivityIndicator color={p.accent} style={{marginRight: 8}} />
              ) : (
                <TouchableOpacity
                  onPress={runSearch}
                  disabled={!query.trim()}
                  style={[
                    styles.searchBtn,
                    {backgroundColor: p.accent, opacity: query.trim() ? 1 : 0.4},
                  ]}>
                  <Text style={styles.searchBtnText}>Search</Text>
                </TouchableOpacity>
              )}
            </View>

            {result ? (
              <View style={[styles.card, styles.resultCard, {backgroundColor: cardBackground(scheme), borderColor: p.outline}]}>
                <ProfileAvatar url={result.profilePictureURL} name={result.name} size={52} />
                <View style={styles.rowText}>
                  <Text style={[styles.requestName, {color: textPrimary(scheme)}]} numberOfLines={1}>
                    {result.name}
                  </Text>
                  <Text style={[styles.subtitle, {color: textSecondary(scheme)}]} numberOfLines={1}>
                    @{result.userId}
                  </Text>
                  <Text style={[styles.subtitle, {color: textSecondary(scheme)}]} numberOfLines={1}>
                    {result.email}
                  </Text>
                </View>
                {status ? (
                  <View style={[styles.statusPill, {backgroundColor: status.fill}]}>
                    <Text style={[styles.statusText, {color: status.tint}]}>{status.title}</Text>
                  </View>
                ) : (
                  <TouchableOpacity
                    style={[styles.statusPill, {backgroundColor: p.accent, paddingHorizontal: 20}]}
                    onPress={() => sendRequest(result)}
                    disabled={sending}>
                    {sending ? (
                      <ActivityIndicator color="#fff" />
                    ) : (
                      <Text style={[styles.statusText, {color: '#fff'}]}>Add</Text>
                    )}
                  </TouchableOpacity>
                )}
              </View>
            ) : searched && !searching ? (
              <Text style={[styles.noUser, {color: textSecondary(scheme)}]}>No user found</Text>
            ) : null}
          </Pressable>
        </Pressable>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  header: {
    paddingTop: Spacing.sm,
    paddingBottom: Spacing.xs,
    gap: 18,
  },
  titleRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  headerTitle: {
    flex: 1,
    fontSize: 38,
    fontWeight: '800',
    letterSpacing: -0.5,
  },
  backBtn: {
    marginLeft: -Spacing.sm,
    marginRight: Spacing.xs,
    padding: Spacing.xs,
  },
  addBtn: {
    width: 54,
    height: 54,
    borderRadius: 27,
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 6,
    shadowColor: Colors.blue,
  },
  searchField: {
    flexDirection: 'row',
    alignItems: 'center',
    height: 54,
    borderRadius: 27,
    paddingHorizontal: 18,
    gap: 10,
  },
  searchInput: {
    flex: 1,
    fontSize: 17,
    paddingVertical: 0,
  },
  familyCard: {
    borderRadius: 28,
    padding: 22,
    gap: 16,
  },
  familyTop: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 12,
  },
  familyTitle: {
    fontSize: 26,
    fontWeight: '800',
  },
  familySubtitle: {
    fontSize: 15,
    marginTop: 4,
    opacity: 0.75,
  },
  managePill: {
    borderWidth: 1.5,
    borderRadius: 999,
    paddingHorizontal: 18,
    paddingVertical: 9,
  },
  manageText: {
    fontSize: 15,
    fontWeight: '700',
  },
  familyBottom: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
  },
  familyCaption: {
    flex: 1,
    fontSize: 15,
    opacity: 0.8,
  },
  avatarStack: {
    flexDirection: 'row',
  },
  stackRing: {
    width: 46,
    height: 46,
    borderRadius: 23,
    borderWidth: 3,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  overflowDisc: {
    marginLeft: -16,
  },
  overflowText: {
    fontSize: 15,
    fontWeight: '700',
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  list: {
    paddingHorizontal: 20,
    paddingBottom: 32,
    flexGrow: 1,
  },
  sectionLabel: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginTop: 22,
    marginBottom: 8,
  },
  sectionTitle: {
    fontSize: 22,
    fontWeight: '800',
  },
  countPill: {
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 2,
  },
  countPillText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '700',
  },
  countText: {
    fontSize: 16,
    fontWeight: '500',
  },
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 14,
    paddingVertical: 12,
    borderRadius: 24,
    gap: 12,
  },
  sentCard: {
    borderWidth: 1.5,
    marginVertical: 4,
  },
  resultCard: {
    borderWidth: 1.5,
    marginTop: Spacing.lg,
  },
  rowText: {
    flex: 1,
    gap: 3,
  },
  nameLine: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  name: {
    fontSize: 17,
    fontWeight: '600',
  },
  nameShrink: {
    flexShrink: 1,
  },
  requestName: {
    fontSize: 18,
    fontWeight: '600',
  },
  subtitle: {
    fontSize: 14,
  },
  familyBadge: {
    borderRadius: 999,
    paddingHorizontal: 8,
    paddingVertical: 2,
  },
  familyBadgeText: {
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 0.6,
  },
  controls: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  roundBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  // Ionicons has no crossed-out house, so the "take out of Family" button
  // draws the slash over a filled one.
  slash: {
    position: 'absolute',
    width: 24,
    height: 3,
    borderRadius: 1.5,
    borderWidth: 0.75,
    transform: [{rotate: '-45deg'}],
  },
  acceptPill: {
    height: 42,
    borderRadius: 21,
    paddingHorizontal: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  acceptText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '700',
  },
  outlineCircle: {
    width: 40,
    height: 40,
    borderRadius: 20,
    borderWidth: 1.5,
    alignItems: 'center',
    justifyContent: 'center',
  },
  swipeAction: {
    backgroundColor: Colors.red,
    justifyContent: 'center',
    alignItems: 'center',
    width: 84,
    marginVertical: 4,
    marginLeft: 8,
    borderRadius: 24,
  },
  swipeActionText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
    marginTop: 2,
  },
  empty: {
    alignItems: 'center',
    paddingTop: 32,
    gap: 14,
  },
  emptyIcon: {
    width: 96,
    height: 96,
    borderRadius: 48,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyTitle: {
    fontSize: 26,
    fontWeight: '800',
  },
  emptyBody: {
    fontSize: 16,
    textAlign: 'center',
    paddingHorizontal: 24,
    lineHeight: 22,
  },
  primaryPill: {
    height: 52,
    borderRadius: 26,
    paddingHorizontal: 32,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 4,
  },
  primaryPillText: {
    color: '#fff',
    fontSize: 17,
    fontWeight: '700',
  },
  inviteText: {
    fontSize: 15,
    fontWeight: '600',
  },
  noResultsIcon: {
    width: 72,
    height: 72,
    borderRadius: 36,
    alignItems: 'center',
    justifyContent: 'center',
  },
  noResultsTitle: {
    fontSize: 22,
    fontWeight: '800',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'flex-end',
  },
  sheet: {
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    paddingHorizontal: 20,
    paddingTop: 12,
    minHeight: '60%',
  },
  sheetTopBar: {
    flexDirection: 'row',
    paddingVertical: Spacing.sm,
  },
  sheetCancel: {
    fontSize: 17,
    fontWeight: '500',
  },
  sheetTitle: {
    fontSize: 32,
    fontWeight: '800',
    marginTop: 8,
  },
  sheetSubtitle: {
    fontSize: 16,
    marginTop: 12,
    marginBottom: 20,
    lineHeight: 22,
  },
  queryField: {
    flexDirection: 'row',
    alignItems: 'center',
    height: 56,
    borderRadius: 28,
    paddingLeft: 18,
    paddingRight: 8,
    gap: 10,
  },
  searchBtn: {
    height: 38,
    borderRadius: 19,
    paddingHorizontal: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  searchBtnText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '700',
  },
  statusPill: {
    height: 38,
    borderRadius: 19,
    paddingHorizontal: 14,
    alignItems: 'center',
    justifyContent: 'center',
    minWidth: 64,
  },
  statusText: {
    fontSize: 14,
    fontWeight: '700',
  },
  noUser: {
    fontSize: 15,
    textAlign: 'center',
    paddingVertical: 24,
  },
});
