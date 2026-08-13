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
import {messageService} from '../../services/messageService';
import {Contact} from '../../models';

interface Props {
  visible: boolean;
  onClose: () => void;
  // Called with the conversation to open once it has been found or created.
  onConversationReady: (conversationId: string, contact: Contact) => void;
}

export default function NewMessageSheet({
  visible,
  onClose,
  onConversationReady,
}: Props) {
  const scheme = useColorScheme();
  const insets = useSafeAreaInsets();
  const {currentUser} = useSession();

  const [query, setQuery] = useState('');
  const [searching, setSearching] = useState(false);
  const [searched, setSearched] = useState<Contact | null>(null);
  // Distinguishes "nothing searched yet" from "searched and found nobody".
  const [searchedQuery, setSearchedQuery] = useState('');
  const [recents, setRecents] = useState<Contact[]>([]);
  const [starting, setStarting] = useState<string | null>(null);

  useEffect(() => {
    if (!visible) {
      return;
    }
    setQuery('');
    setSearched(null);
    setSearchedQuery('');
    setStarting(null);
    if (currentUser) {
      messageService
        .getRecentContacts(currentUser.userId)
        .then(setRecents)
        .catch(() => setRecents([]));
    }
  }, [visible, currentUser]);

  async function search() {
    const cleaned = query.trim();
    if (!cleaned || !currentUser) {
      return;
    }
    setSearching(true);
    setSearched(null);
    try {
      const contact = await messageService.searchContact(cleaned);
      // Messaging yourself is not a conversation — iOS drops the current user
      // from search results too.
      setSearched(contact && contact.id !== currentUser.userId ? contact : null);
    } catch (err: any) {
      Alert.alert('Error', err?.message ?? 'Search failed.');
    } finally {
      setSearchedQuery(cleaned);
      setSearching(false);
    }
  }

  async function startConversation(contact: Contact) {
    if (!currentUser || starting) {
      return;
    }
    setStarting(contact.id);
    try {
      const conversationId = await messageService.getOrCreateConversation(
        currentUser.userId,
        contact.id,
        currentUser.name,
        contact.name,
        currentUser.profilePictureURL,
        contact.profilePictureURL,
      );
      onConversationReady(conversationId, contact);
    } catch (err: any) {
      Alert.alert('Error', err?.message ?? 'Failed to start this conversation.');
    } finally {
      setStarting(null);
    }
  }

  function renderContact(contact: Contact) {
    const busy = starting === contact.id;
    return (
      <TouchableOpacity
        style={[styles.contactRow, {backgroundColor: sheetFill(scheme)}]}
        onPress={() => startConversation(contact)}
        disabled={!!starting}
        activeOpacity={0.7}>
        <ProfileAvatar
          url={contact.profilePictureURL}
          name={contact.name}
          size={42}
        />
        <View style={styles.contactText}>
          <Text
            style={[styles.contactName, {color: textPrimary(scheme)}]}
            numberOfLines={1}>
            {contact.name}
          </Text>
          <Text
            style={[styles.contactMeta, {color: textSecondary(scheme)}]}
            numberOfLines={1}>
            {contact.email || `@${contact.id}`}
          </Text>
        </View>
        {busy ? (
          <ActivityIndicator color={Colors.blue} />
        ) : (
          <View style={styles.contactAction}>
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
        <Pressable style={StyleSheet.absoluteFill} onPress={onClose} />

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
            <View
              style={[
                styles.handle,
                {backgroundColor: scheme === 'dark' ? '#4A4A57' : '#D8DCE6'},
              ]}
            />

            <View style={styles.header}>
              <View style={styles.headerText}>
                <Text style={[styles.title, {color: textPrimary(scheme)}]}>
                  New Message
                </Text>
                <Text style={[styles.subtitle, {color: textSecondary(scheme)}]}>
                  Search by email address or username
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

            {/* Search */}
            <View style={[styles.searchRow, {backgroundColor: sheetFill(scheme)}]}>
              <Icon name="search" size={18} color={textSecondary(scheme)} />
              <TextInput
                placeholder="Enter email or username"
                placeholderTextColor={textSecondary(scheme)}
                value={query}
                onChangeText={text => {
                  setQuery(text);
                  if (!text.trim()) {
                    setSearched(null);
                    setSearchedQuery('');
                  }
                }}
                style={[styles.searchInput, {color: textPrimary(scheme)}]}
                autoCapitalize="none"
                autoCorrect={false}
                returnKeyType="search"
                onSubmitEditing={search}
              />
              <TouchableOpacity
                onPress={search}
                disabled={!query.trim() || searching}
                style={[
                  styles.searchBtn,
                  {opacity: query.trim() && !searching ? 1 : 0.4},
                ]}
                activeOpacity={0.8}>
                {searching ? (
                  <ActivityIndicator color="#fff" size="small" />
                ) : (
                  <Icon name="arrow-forward" size={18} color="#fff" />
                )}
              </TouchableOpacity>
            </View>

            {searched && <View style={styles.result}>{renderContact(searched)}</View>}
            {!searched && !searching && !!searchedQuery && (
              <Text style={[styles.noResult, {color: textSecondary(scheme)}]}>
                No user found
              </Text>
            )}

            {/* Recent contacts */}
            <Text style={[styles.sectionLabel, {color: textSecondary(scheme)}]}>
              Recent Contacts
            </Text>
            <FlatList
              data={recents}
              renderItem={({item}) => renderContact(item)}
              keyExtractor={item => item.id}
              style={styles.list}
              contentContainerStyle={styles.listContent}
              keyboardShouldPersistTaps="handled"
              showsVerticalScrollIndicator={false}
              ListEmptyComponent={
                <View style={styles.empty}>
                  <View
                    style={[styles.emptyIcon, {backgroundColor: sheetFill(scheme)}]}>
                    <Icon
                      name="chatbubbles-outline"
                      size={26}
                      color={textSecondary(scheme)}
                    />
                  </View>
                  <Text style={[styles.emptyText, {color: textSecondary(scheme)}]}>
                    No one yet — search for a friend by their email or username
                    to start a conversation.
                  </Text>
                </View>
              }
            />
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
  sheetWrapper: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  sheet: {
    maxHeight: '88%',
    minHeight: '55%',
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
  searchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    paddingLeft: Spacing.md,
    paddingRight: 5,
    paddingVertical: 5,
    borderRadius: Radius.full,
  },
  searchInput: {
    flex: 1,
    fontSize: 15,
    padding: 0,
  },
  searchBtn: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: Colors.blue,
    alignItems: 'center',
    justifyContent: 'center',
  },
  result: {
    marginTop: Spacing.md,
  },
  noResult: {
    fontSize: 14,
    marginTop: Spacing.md,
  },
  sectionLabel: {
    fontSize: 13,
    fontWeight: '600',
    marginTop: Spacing.lg,
    marginBottom: Spacing.sm,
  },
  list: {
    flexGrow: 0,
    flexShrink: 1,
  },
  listContent: {
    gap: Spacing.sm,
    paddingBottom: Spacing.md,
  },
  contactRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
    padding: Spacing.sm + 2,
    borderRadius: Radius.lg,
  },
  contactText: {
    flex: 1,
  },
  contactName: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 2,
  },
  contactMeta: {
    fontSize: 13,
  },
  contactAction: {
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
});
