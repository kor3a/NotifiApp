import React, {useState} from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  Alert,
  useColorScheme,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import functions from '@react-native-firebase/functions';
import Icon from '../../components/AppIcon';

import GradientBackground from '../../components/GradientBackground';
import {cardStyle, textPrimary, textSecondary} from '../../theme/AppTheme';
import {useSession} from '../../context/SessionContext';
import {appVersionLabel} from './AboutScreen';
import {
  ProfileHeader,
  SectionLabel,
  PillButton,
  profilePalette,
  profileStyles,
} from './profileUi';

// The labels are what the submitFeedback Cloud Function accepts, so they
// must stay in step with ALLOWED_FEEDBACK_CATEGORIES there and with iOS.
const CATEGORIES = [
  {label: 'General Feedback', icon: 'chatbubble'},
  {label: 'Report a Bug', icon: 'bug'},
  {label: 'Feature Request', icon: 'bulb'},
] as const;

type Category = (typeof CATEGORIES)[number]['label'];

// Port of iOS ReportFeedbackView. Sends to the same `submitFeedback` function,
// which archives it in Firestore and emails the team.
export default function ReportFeedbackScreen() {
  const scheme = useColorScheme();
  const p = profilePalette(scheme);
  const {currentUser} = useSession();

  const [category, setCategory] = useState<Category>('General Feedback');
  const [message, setMessage] = useState('');
  const [sending, setSending] = useState(false);

  const trimmed = message.trim();

  async function handleSubmit() {
    if (!trimmed || sending) {return;}
    setSending(true);
    try {
      await functions().httpsCallable('submitFeedback')({
        category,
        message: trimmed,
        appVersion: `Android ${appVersionLabel()}`,
        reporterName: currentUser?.name ?? '',
        reporterUserId: currentUser?.userId ?? '',
      });
      setMessage('');
      Alert.alert(
        'Thank you!',
        'Your feedback has been submitted. We appreciate you helping improve Allim!',
      );
    } catch (_) {
      Alert.alert(
        "Couldn't Send Feedback",
        'Something went wrong while sending your feedback. Please check your connection and try again.',
      );
    } finally {
      setSending(false);
    }
  }

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}} edges={['top', 'left', 'right']}>
        <ProfileHeader scheme={scheme} title="Report & Feedback" />
        <KeyboardAvoidingView
          style={{flex: 1}}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <ScrollView
            contentContainerStyle={profileStyles.scroll}
            keyboardShouldPersistTaps="handled"
            keyboardDismissMode="on-drag">
            {/* Three cards rather than a picker: there are only three answers,
                and each glyph says what it is faster than the label does. */}
            <View style={profileStyles.section}>
              <SectionLabel scheme={scheme} title="What's this about?" />
              {CATEGORIES.map(c => {
                const selected = c.label === category;
                return (
                  <TouchableOpacity
                    key={c.label}
                    onPress={() => setCategory(c.label)}
                    disabled={sending}
                    activeOpacity={0.75}
                    accessibilityState={{selected}}
                    style={[cardStyle(scheme), styles.categoryRow]}>
                    <View
                      style={[
                        styles.categoryIcon,
                        {backgroundColor: selected ? p.accent : p.blush},
                      ]}>
                      <Icon name={c.icon} size={17} color={selected ? '#fff' : p.accent} />
                    </View>
                    <Text style={[styles.categoryText, {color: textPrimary(scheme)}]}>
                      {c.label}
                    </Text>
                    <Icon
                      name={selected ? 'checkmark-circle' : 'ellipse-outline'}
                      size={22}
                      color={selected ? p.accent : p.outline}
                    />
                  </TouchableOpacity>
                );
              })}
            </View>

            <View style={profileStyles.section}>
              <SectionLabel scheme={scheme} title="Message" />
              <Text style={[profileStyles.hint, {color: textSecondary(scheme)}]}>
                Describe your feedback or issue in as much detail as possible.
              </Text>
              <TextInput
                value={message}
                onChangeText={setMessage}
                placeholder="What happened?"
                placeholderTextColor={textSecondary(scheme)}
                multiline
                textAlignVertical="top"
                maxLength={5000}
                editable={!sending}
                style={[
                  styles.messageInput,
                  {backgroundColor: p.field, color: textPrimary(scheme)},
                ]}
              />
            </View>

            <PillButton
              title={sending ? 'Sending…' : 'Submit Feedback'}
              loading={sending}
              disabled={!trimmed}
              onPress={handleSubmit}
              style={{marginTop: 4}}
            />
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  categoryRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 22,
    marginVertical: 0,
  },
  categoryIcon: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: 'center',
    justifyContent: 'center',
  },
  categoryText: {
    flex: 1,
    fontSize: 16,
    fontWeight: '600',
  },
  messageInput: {
    minHeight: 180,
    borderRadius: 24,
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: 16,
    fontSize: 16,
  },
});
