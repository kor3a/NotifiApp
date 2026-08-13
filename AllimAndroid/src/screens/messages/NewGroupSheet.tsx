import React, {useEffect, useState} from 'react';
import {
  View,
  Text,
  Modal,
  TextInput,
  StyleSheet,
  TouchableOpacity,
  Pressable,
  ScrollView,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  useColorScheme,
  Alert,
} from 'react-native';
import {useSafeAreaInsets} from 'react-native-safe-area-context';
import Icon from '../../components/AppIcon';

import ProfileAvatar from '../../components/ProfileAvatar';
import PrimaryButton from '../../components/PrimaryButton';
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
  // Called with the new group's conversation once it has been created.
  onGroupCreated: (conversationId: string, groupName: string) => void;
}

export default function NewGroupSheet({
  visible,
  onClose,
  onGroupCreated,
}: Props) {
  const scheme = useColorScheme();
  const insets = useSafeAreaInsets();
  const {currentUser} = useSession();

  const [groupName, setGroupName] = useState('');
  const [query, setQuery] = useState('');
  const [searching, setSearching] = useState(false);
  const [searched, setSearched] = useState<Contact | null>(null);
  const [searchedQuery, setSearchedQuery] = useState('');
  const [members, setMembers] = useState<Contact[]>([]);
  const [recents, setRecents] = useState<Contact[]>([]);
  const [creating, setCreating] = useState(false);

  useEffect(() => {
    if (!visible) {
      return;
    }
    setGroupName('');
    setQuery('');
    setSearched(null);
    setSearchedQuery('');
    setMembers([]);
    setCreating(false);
    if (currentUser) {
      messageService
        .getRecentContacts(currentUser.userId)
        .then(setRecents)
        .catch(() => setRecents([]));
    }
  }, [visible, currentUser]);

  const isSelected = (contact: Contact) =>
    members.some(m => m.id === contact.id);

  function toggleMember(contact: Contact) {
    setMembers(prev =>
      prev.some(m => m.id === contact.id)
        ? prev.filter(m => m.id !== contact.id)
        : [...prev, contact],
    );
  }

  async function search() {
    const cleaned = query.trim();
    if (!cleaned || !currentUser) {
      return;
    }
    setSearching(true);
    setSearched(null);
    try {
      const contact = await messageService.searchContact(cleaned);
      // The creator is always a member, so they are never offered as one.
      setSearched(contact && contact.id !== currentUser.userId ? contact : null);
    } catch (err: any) {
      Alert.alert('Error', err?.message ?? 'Search failed.');
    } finally {
      setSearchedQuery(cleaned);
      setSearching(false);
    }
  }

  async function createGroup() {
    const name = groupName.trim();
    if (!name || members.length === 0 || !currentUser || creating) {
      return;
    }
    setCreating(true);
    try {
      const conversationId = await messageService.createGroupConversation({
        groupName: name,
        creatorId: currentUser.userId,
        creatorName: currentUser.name,
        members,
      });
      onGroupCreated(conversationId, name);
    } catch (err: any) {
      Alert.alert('Error', err?.message ?? 'Failed to create this group.');
    } finally {
      setCreating(false);
    }
  }

  function renderContact(contact: Contact) {
    const selected = isSelected(contact);
    return (
      <TouchableOpacity
        key={contact.id}
        style={[styles.contactRow, {backgroundColor: sheetFill(scheme)}]}
        onPress={() => toggleMember(contact)}
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
        <Icon
          name={selected ? 'checkmark-circle' : 'add-circle-outline'}
          size={24}
          color={selected ? Colors.blue : textSecondary(scheme)}
        />
      </TouchableOpacity>
    );
  }

  const canCreate = !!groupName.trim() && members.length > 0;

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
                  New Group
                </Text>
                <Text style={[styles.subtitle, {color: textSecondary(scheme)}]}>
                  Name the group and add people to it
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

            <ScrollView
              style={styles.body}
              contentContainerStyle={styles.bodyContent}
              keyboardShouldPersistTaps="handled"
              showsVerticalScrollIndicator={false}>
              {/* Group name */}
              <Text style={[styles.sectionLabel, {color: textSecondary(scheme)}]}>
                Group Name
              </Text>
              <View style={[styles.inputRow, {backgroundColor: sheetFill(scheme)}]}>
                <Icon name="people" size={18} color={textSecondary(scheme)} />
                <TextInput
                  placeholder="Family, Friends, Team…"
                  placeholderTextColor={textSecondary(scheme)}
                  value={groupName}
                  onChangeText={setGroupName}
                  style={[styles.input, {color: textPrimary(scheme)}]}
                  autoCorrect={false}
                  maxLength={60}
                />
              </View>

              {/* Add members */}
              <Text style={[styles.sectionLabel, {color: textSecondary(scheme)}]}>
                Add Members
              </Text>
              <View style={[styles.inputRow, {backgroundColor: sheetFill(scheme)}]}>
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
                  style={[styles.input, {color: textPrimary(scheme)}]}
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

              {searched && (
                <View style={styles.result}>{renderContact(searched)}</View>
              )}
              {!searched && !searching && !!searchedQuery && (
                <Text style={[styles.noResult, {color: textSecondary(scheme)}]}>
                  No user found
                </Text>
              )}

              {/* Selected members */}
              {members.length > 0 && (
                <>
                  <Text
                    style={[styles.sectionLabel, {color: textSecondary(scheme)}]}>
                    Members ({members.length})
                  </Text>
                  <View style={styles.rows}>
                    {members.map(member => (
                      <View
                        key={member.id}
                        style={[
                          styles.contactRow,
                          {backgroundColor: sheetFill(scheme)},
                        ]}>
                        <ProfileAvatar
                          url={member.profilePictureURL}
                          name={member.name}
                          size={38}
                        />
                        <View style={styles.contactText}>
                          <Text
                            style={[
                              styles.contactName,
                              {color: textPrimary(scheme)},
                            ]}
                            numberOfLines={1}>
                            {member.name}
                          </Text>
                          <Text
                            style={[
                              styles.contactMeta,
                              {color: textSecondary(scheme)},
                            ]}
                            numberOfLines={1}>
                            {member.email || `@${member.id}`}
                          </Text>
                        </View>
                        <TouchableOpacity
                          onPress={() => toggleMember(member)}
                          hitSlop={8}
                          activeOpacity={0.7}>
                          <Icon
                            name="remove-circle"
                            size={22}
                            color={Colors.red}
                          />
                        </TouchableOpacity>
                      </View>
                    ))}
                  </View>
                </>
              )}

              {/* Recent contacts */}
              {recents.length > 0 && (
                <>
                  <Text
                    style={[styles.sectionLabel, {color: textSecondary(scheme)}]}>
                    Recent Contacts
                  </Text>
                  <View style={styles.rows}>
                    {/* Someone already picked appears in the Members list above,
                        so they are not offered twice. */}
                    {recents.filter(c => !isSelected(c)).map(renderContact)}
                  </View>
                </>
              )}
            </ScrollView>

            <PrimaryButton
              title="Create Group"
              onPress={createGroup}
              loading={creating}
              disabled={!canCreate}
              style={styles.createBtn}
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
    minHeight: '60%',
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
    marginBottom: Spacing.md,
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
  body: {
    flexGrow: 0,
    flexShrink: 1,
  },
  bodyContent: {
    paddingBottom: Spacing.md,
  },
  sectionLabel: {
    fontSize: 13,
    fontWeight: '600',
    marginTop: Spacing.lg,
    marginBottom: Spacing.sm,
  },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    paddingLeft: Spacing.md,
    paddingRight: 5,
    paddingVertical: 5,
    borderRadius: Radius.full,
    minHeight: 48,
  },
  input: {
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
  rows: {
    gap: Spacing.sm,
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
  createBtn: {
    marginTop: Spacing.md,
  },
});
