import React, {useEffect, useState} from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  TouchableOpacity,
  useColorScheme,
  ActivityIndicator,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {useNavigation} from '@react-navigation/native';
import {NativeStackNavigationProp} from '@react-navigation/native-stack';
import Icon from 'react-native-vector-icons/Ionicons';
import {format} from 'date-fns';

import GradientBackground from '../../components/GradientBackground';
import ProfileAvatar from '../../components/ProfileAvatar';
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
import {Conversation} from '../../models';
import {MessagesStackParamList} from '../../navigation/AppNavigator';

type Nav = NativeStackNavigationProp<MessagesStackParamList, 'MessagesList'>;

export default function MessagesScreen() {
  const scheme = useColorScheme();
  const navigation = useNavigation<Nav>();
  const {currentUser, firebaseUser} = useSession();

  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!firebaseUser) {return;}
    const unsub = messageService.subscribeToConversations(
      firebaseUser.uid,
      convos => {
        setConversations(convos);
        setLoading(false);
      },
    );
    return unsub;
  }, [firebaseUser]);

  function getOtherUser(convo: Conversation) {
    if (!firebaseUser) {return {id: '', name: 'Unknown', photo: undefined};}
    const otherId = convo.participantIds.find(id => id !== firebaseUser.uid) ?? '';
    return {
      id: otherId,
      name: convo.participantNames?.[otherId] ?? 'Unknown',
      photo: convo.participantPhotos?.[otherId],
    };
  }

  function renderConvo({item}: {item: Conversation}) {
    const other = getOtherUser(item);
    const unread = (item.unreadCount?.[firebaseUser?.uid ?? ''] ?? 0) as number;
    const timeStr = item.lastMessageAt?.toDate
      ? format(item.lastMessageAt.toDate(), 'MMM d')
      : '';

    return (
      <TouchableOpacity
        style={[styles.convoCard, cardStyle(scheme)]}
        onPress={() =>
          navigation.navigate('Conversation', {
            conversationId: item.id,
            otherUserId: other.id,
            otherUserName: other.name,
          })
        }
        activeOpacity={0.75}>
        <ProfileAvatar url={other.photo} name={other.name} size={46} />
        <View style={styles.convoContent}>
          <View style={styles.convoTop}>
            <Text style={[styles.convoName, {color: textPrimary(scheme)}]}>
              {other.name}
            </Text>
            <Text style={[styles.convoTime, {color: textSecondary(scheme)}]}>
              {timeStr}
            </Text>
          </View>
          <View style={styles.convoBottom}>
            <Text
              style={[styles.lastMsg, {color: textSecondary(scheme)}]}
              numberOfLines={1}>
              {item.lastMessage || 'No messages yet'}
            </Text>
            {unread > 0 && (
              <View style={styles.badge}>
                <Text style={styles.badgeText}>{unread > 99 ? '99+' : unread}</Text>
              </View>
            )}
          </View>
        </View>
      </TouchableOpacity>
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
        </View>

        {loading ? (
          <View style={styles.center}>
            <ActivityIndicator size="large" color={Colors.blue} />
          </View>
        ) : conversations.length === 0 ? (
          <View style={styles.center}>
            <Icon name="chatbubbles-outline" size={60} color={textSecondary(scheme)} />
            <Text style={[styles.emptyText, {color: textSecondary(scheme)}]}>
              No conversations yet.{'\n'}Add a friend and start chatting!
            </Text>
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
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
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
  },
  convoCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.md,
  },
  convoContent: {
    flex: 1,
    marginLeft: Spacing.md,
  },
  convoTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  convoName: {
    fontSize: 16,
    fontWeight: '600',
  },
  convoTime: {
    fontSize: 12,
  },
  convoBottom: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  lastMsg: {
    fontSize: 14,
    flex: 1,
    marginRight: Spacing.sm,
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
});
