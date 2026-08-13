import React, {useEffect, useState, useRef} from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  TouchableOpacity,
  TextInput,
  KeyboardAvoidingView,
  ActivityIndicator,
  Alert,
  Platform,
  useColorScheme,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {useRoute, useNavigation, RouteProp} from '@react-navigation/native';
import Icon from '../../components/AppIcon';
import {format} from 'date-fns';

import GradientBackground from '../../components/GradientBackground';
import {
  Colors,
  Spacing,
  Radius,
  textPrimary,
  textSecondary,
  cardBackground,
} from '../../theme/AppTheme';
import {useSession} from '../../context/SessionContext';
import {messageService} from '../../services/messageService';
import {storeShareService} from '../../services/storeShareService';
import {Message, timestampMillis} from '../../models';
import {MessagesStackParamList} from '../../navigation/AppNavigator';

type RouteType = RouteProp<MessagesStackParamList, 'Conversation'>;

export default function ConversationScreen() {
  const scheme = useColorScheme();
  const route = useRoute<RouteType>();
  const navigation = useNavigation();
  const {currentUser, firebaseUser} = useSession();

  const {conversationId, otherUserName, isGroup} = route.params;

  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);
  const [respondingTo, setRespondingTo] = useState<string | null>(null);
  const listRef = useRef<FlatList>(null);

  useEffect(() => {
    const unsub = messageService.subscribeToMessages(conversationId, msgs => {
      setMessages(msgs);
      setTimeout(() => listRef.current?.scrollToEnd({animated: true}), 100);
    });

    // Mark as read (conversations are keyed by username, not the auth uid).
    // Best effort: a failure here only leaves the badge up until next time, and
    // must not surface as an unhandled rejection.
    if (currentUser) {
      messageService.markAsRead(conversationId, currentUser.userId).catch(() => {});
    }

    return unsub;
  }, [conversationId, currentUser]);

  async function handleSend() {
    if (!input.trim() || !currentUser) {return;}
    const text = input.trim();
    setInput('');
    setSending(true);
    try {
      await messageService.sendMessage(
        conversationId,
        currentUser.userId,
        currentUser.name,
        text,
      );
    } finally {
      setSending(false);
    }
  }

  async function handleAcceptStore(message: Message) {
    if (!currentUser || respondingTo) {return;}
    setRespondingTo(message.id);
    try {
      await storeShareService.acceptSharedStore(message, currentUser);
      Alert.alert(
        'Store Added',
        `${message.linkedStore?.storeName} is now in your stores.`,
      );
    } catch (err: any) {
      Alert.alert('Error', err?.message ?? 'Failed to accept this store.');
    } finally {
      setRespondingTo(null);
    }
  }

  async function handleDeclineStore(message: Message) {
    if (respondingTo) {return;}
    setRespondingTo(message.id);
    try {
      await storeShareService.rejectSharedStore(message.id);
    } catch (err: any) {
      Alert.alert('Error', err?.message ?? 'Failed to decline this store.');
    } finally {
      setRespondingTo(null);
    }
  }

  // A store share request. The recipient decides here; the sender just sees
  // where the request stands.
  function renderSharedStore(item: Message, isMine: boolean) {
    const linked = item.linkedStore!;
    const status = linked.status ?? 'pending';
    const busy = respondingTo === item.id;
    const textColor = isMine ? '#fff' : textPrimary(scheme);
    const mutedColor = isMine ? 'rgba(255,255,255,0.7)' : textSecondary(scheme);

    return (
      <View
        style={[
          styles.storeCard,
          {borderColor: isMine ? 'rgba(255,255,255,0.35)' : Colors.blue + '55'},
        ]}>
        <View style={styles.storeCardHeader}>
          <Icon name="storefront" size={18} color={isMine ? '#fff' : Colors.blue} />
          <Text style={[styles.storeCardName, {color: textColor}]}>
            {linked.storeName}
          </Text>
        </View>
        <Text style={[styles.storeCardMeta, {color: mutedColor}]}>
          {linked.permission === 'edit' ? 'Can Edit' : 'View Only'}
          {' · '}
          {linked.reminderTitles?.length ?? 0} reminder
          {(linked.reminderTitles?.length ?? 0) === 1 ? '' : 's'}
        </Text>

        {status === 'pending' && !isMine && (
          <View style={styles.storeCardActions}>
            <TouchableOpacity
              style={[styles.storeCardBtn, {backgroundColor: Colors.green}]}
              onPress={() => handleAcceptStore(item)}
              disabled={busy}
              activeOpacity={0.8}>
              {busy ? (
                <ActivityIndicator size="small" color="#fff" />
              ) : (
                <Text style={styles.storeCardBtnText}>Accept</Text>
              )}
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.storeCardBtn, {backgroundColor: Colors.red}]}
              onPress={() => handleDeclineStore(item)}
              disabled={busy}
              activeOpacity={0.8}>
              <Text style={styles.storeCardBtnText}>Decline</Text>
            </TouchableOpacity>
          </View>
        )}

        {status === 'pending' && isMine && (
          <Text style={[styles.storeCardStatus, {color: mutedColor}]}>
            Waiting for a response…
          </Text>
        )}
        {status !== 'pending' && (
          <Text
            style={[
              styles.storeCardStatus,
              {color: status === 'accepted' ? Colors.green : mutedColor},
            ]}>
            {status === 'accepted' ? 'Accepted' : 'Declined'}
          </Text>
        )}
      </View>
    );
  }

  function renderMessage({item}: {item: Message}) {
    const isMine = item.senderId === currentUser?.userId;
    const millis = timestampMillis(item.createdAt);
    const time = millis ? format(new Date(millis), 'h:mm a') : '';

    return (
      <View style={[styles.msgRow, isMine && styles.msgRowMine]}>
        {/* Who sent it, on incoming messages in a group only — the same label
            iOS puts above a group bubble. */}
        {isGroup && !isMine && !!item.senderName && (
          <Text style={[styles.senderName, {color: textSecondary(scheme)}]}>
            {item.senderName}
          </Text>
        )}
        <View
          style={[
            styles.bubble,
            item.linkedStore && styles.bubbleWide,
            isMine
              ? styles.bubbleMine
              : [styles.bubbleOther, {backgroundColor: cardBackground(scheme)}],
          ]}>
          {!item.linkedStore && item.linkedStoreName && (
            <View style={styles.linkedBadge}>
              <Icon name="cart-outline" size={12} color={Colors.blue} />
              <Text style={styles.linkedText}>{item.linkedStoreName}</Text>
            </View>
          )}
          <Text style={[styles.bubbleText, {color: isMine ? '#fff' : textPrimary(scheme)}]}>
            {item.content}
          </Text>
          {item.linkedStore && renderSharedStore(item, isMine)}
          <Text style={[styles.bubbleTime, {color: isMine ? 'rgba(255,255,255,0.7)' : textSecondary(scheme)}]}>
            {time}
          </Text>
        </View>
      </View>
    );
  }

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}}>
        <KeyboardAvoidingView
          style={{flex: 1}}
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          keyboardVerticalOffset={0}>

          {/* Header */}
          <View style={styles.header}>
            <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backBtn}>
              <Icon name="chevron-back" size={24} color={Colors.blue} />
            </TouchableOpacity>
            <Text style={[styles.headerTitle, {color: textPrimary(scheme)}]}>
              {otherUserName}
            </Text>
          </View>

          {/* Messages */}
          <FlatList
            ref={listRef}
            data={messages}
            renderItem={renderMessage}
            keyExtractor={item => item.id}
            contentContainerStyle={styles.messageList}
          />

          {/* Input */}
          <View style={[styles.inputRow, {backgroundColor: cardBackground(scheme)}]}>
            <TextInput
              placeholder="Message..."
              placeholderTextColor={textSecondary(scheme)}
              value={input}
              onChangeText={setInput}
              style={[styles.msgInput, {color: textPrimary(scheme)}]}
              multiline
              maxLength={1000}
            />
            <TouchableOpacity
              onPress={handleSend}
              disabled={!input.trim() || sending}
              style={[
                styles.sendBtn,
                {opacity: input.trim() && !sending ? 1 : 0.4},
              ]}>
              <Icon name="send" size={20} color="#fff" />
            </TouchableOpacity>
          </View>

        </KeyboardAvoidingView>
      </SafeAreaView>
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
  headerTitle: {
    fontSize: 18,
    fontWeight: '700',
    flex: 1,
  },
  messageList: {
    padding: Spacing.md,
    paddingBottom: Spacing.sm,
  },
  msgRow: {
    marginBottom: Spacing.sm,
    alignItems: 'flex-start',
  },
  msgRowMine: {
    alignItems: 'flex-end',
  },
  senderName: {
    fontSize: 12,
    fontWeight: '600',
    marginBottom: 2,
    marginLeft: Spacing.xs,
  },
  bubble: {
    maxWidth: '75%',
    padding: Spacing.md,
    borderRadius: Radius.lg,
  },
  bubbleWide: {
    maxWidth: '90%',
  },
  bubbleMine: {
    backgroundColor: Colors.blue,
    borderBottomRightRadius: 4,
  },
  storeCard: {
    marginTop: Spacing.sm,
    padding: Spacing.sm + 2,
    borderRadius: Radius.md,
    borderWidth: 1,
    gap: 4,
  },
  storeCardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  storeCardName: {
    fontSize: 15,
    fontWeight: '700',
    flexShrink: 1,
  },
  storeCardMeta: {
    fontSize: 12,
  },
  storeCardActions: {
    flexDirection: 'row',
    gap: Spacing.sm,
    marginTop: Spacing.sm,
  },
  storeCardBtn: {
    flex: 1,
    paddingVertical: Spacing.sm,
    borderRadius: Radius.sm,
    alignItems: 'center',
    justifyContent: 'center',
  },
  storeCardBtnText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  storeCardStatus: {
    fontSize: 12,
    fontWeight: '600',
    marginTop: 2,
  },
  bubbleOther: {
    borderBottomLeftRadius: 4,
  },
  linkedBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.blue + '22',
    borderRadius: Radius.sm,
    paddingHorizontal: Spacing.sm,
    paddingVertical: 2,
    marginBottom: Spacing.xs,
    gap: 4,
  },
  linkedText: {
    fontSize: 11,
    color: Colors.blue,
    fontWeight: '600',
  },
  bubbleText: {
    fontSize: 16,
    lineHeight: 22,
  },
  bubbleTime: {
    fontSize: 11,
    marginTop: 4,
    textAlign: 'right',
  },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    padding: Spacing.sm,
    paddingBottom: Spacing.md,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: 'rgba(128,128,128,0.3)',
  },
  msgInput: {
    flex: 1,
    fontSize: 16,
    maxHeight: 100,
    paddingHorizontal: Spacing.md,
    paddingTop: Spacing.sm,
    paddingBottom: Spacing.sm,
  },
  sendBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: Colors.blue,
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: Spacing.sm,
  },
});
