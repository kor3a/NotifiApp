import React, {useEffect, useState, useRef} from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  TouchableOpacity,
  TextInput,
  KeyboardAvoidingView,
  Platform,
  useColorScheme,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {useRoute, useNavigation, RouteProp} from '@react-navigation/native';
import Icon from '@expo/vector-icons/Ionicons';
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
import {Message} from '../../models';
import {MessagesStackParamList} from '../../navigation/AppNavigator';

type RouteType = RouteProp<MessagesStackParamList, 'Conversation'>;

export default function ConversationScreen() {
  const scheme = useColorScheme();
  const route = useRoute<RouteType>();
  const navigation = useNavigation();
  const {currentUser, firebaseUser} = useSession();

  const {conversationId, otherUserName} = route.params;

  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);
  const listRef = useRef<FlatList>(null);

  useEffect(() => {
    const unsub = messageService.subscribeToMessages(conversationId, msgs => {
      setMessages(msgs);
      setTimeout(() => listRef.current?.scrollToEnd({animated: true}), 100);
    });

    // Mark as read (conversations are keyed by username, not the auth uid).
    if (currentUser) {
      messageService.markAsRead(conversationId, currentUser.userId);
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

  function renderMessage({item}: {item: Message}) {
    const isMine = item.senderId === currentUser?.userId;
    const time = item.createdAt?.toDate
      ? format(item.createdAt.toDate(), 'h:mm a')
      : '';

    return (
      <View style={[styles.msgRow, isMine && styles.msgRowMine]}>
        <View
          style={[
            styles.bubble,
            isMine
              ? styles.bubbleMine
              : [styles.bubbleOther, {backgroundColor: cardBackground(scheme)}],
          ]}>
          {item.linkedStoreName && (
            <View style={styles.linkedBadge}>
              <Icon name="cart-outline" size={12} color={Colors.blue} />
              <Text style={styles.linkedText}>{item.linkedStoreName}</Text>
            </View>
          )}
          <Text style={[styles.bubbleText, {color: isMine ? '#fff' : textPrimary(scheme)}]}>
            {item.content}
          </Text>
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
  bubble: {
    maxWidth: '75%',
    padding: Spacing.md,
    borderRadius: Radius.lg,
  },
  bubbleMine: {
    backgroundColor: Colors.blue,
    borderBottomRightRadius: 4,
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
