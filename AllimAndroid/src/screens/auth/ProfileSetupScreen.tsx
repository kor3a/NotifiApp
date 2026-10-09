import React, {useRef, useState} from 'react';
import {
  Alert,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
  useColorScheme,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import auth from '@react-native-firebase/auth';
import Icon from '../../components/AppIcon';

import GradientBackground from '../../components/GradientBackground';
import {textPrimary, textSecondary} from '../../theme/AppTheme';
import {PillButton, fieldStyle, profilePalette} from '../profile/profileUi';
import {AuthField, QuietLink, authStyles} from './authUi';
import {authService, USERNAME_REGEX} from '../../services/authService';
import {useSession} from '../../context/SessionContext';

/**
 * One-time profile setup after a first-time Google sign-in — port of the iOS
 * ProfileSetupView. Google gives us a verified email but no username, and the
 * `users` collection is keyed by username, so the user picks one here.
 *
 * The email is fixed — it comes from the provider and identifies the account
 * (Firestore lookups and the security rules both key off it) — so it is shown
 * read-only.
 */
export default function ProfileSetupScreen() {
  const scheme = useColorScheme();
  const p = profilePalette(scheme);
  const {refreshUser} = useSession();

  const email = auth().currentUser?.email ?? '';
  // Nothing is suggested for the username on purpose: a prefilled ID reads as
  // already-decided. The name is prefilled from what Google told us, which is
  // the value people keep anyway.
  const [userId, setUserId] = useState('');
  const [name, setName] = useState(auth().currentUser?.displayName ?? '');
  const [loading, setLoading] = useState(false);
  const nameRef = useRef<TextInput>(null);

  async function handleContinue() {
    // Validated in the order the fields are shown, so the message points at the
    // first thing the user would look at.
    const normalizedUserId = userId.trim().toLowerCase();
    if (!normalizedUserId) {
      Alert.alert('Note', 'Please choose a user ID.');
      return;
    }
    if (!USERNAME_REGEX.test(normalizedUserId)) {
      Alert.alert(
        'Note',
        'Username must be 3-20 characters and contain only letters and numbers.',
      );
      return;
    }
    if (!name.trim()) {
      Alert.alert('Note', 'Please enter your name.');
      return;
    }

    setLoading(true);
    try {
      await authService.createSocialProfile(normalizedUserId, name);
      // Flips the session to 'ready', which swaps this screen for the
      // permission primers and then the app.
      await refreshUser();
    } catch (err: any) {
      Alert.alert('Note', err.message ?? "Couldn't create your profile.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}}>
        <KeyboardAvoidingView
          style={{flex: 1}}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <ScrollView
            contentContainerStyle={[authStyles.scroll, {paddingTop: 32}]}
            keyboardShouldPersistTaps="handled"
            keyboardDismissMode="interactive">
            <View style={styles.heading}>
              <Text style={[authStyles.display, styles.title, {color: textPrimary(scheme)}]}>
                Almost there
              </Text>
              <Text style={[authStyles.subtitle, {color: textSecondary(scheme)}]}>
                Choose how you'll appear in Allim.
              </Text>
            </View>

            <View style={styles.fields}>
              <View style={styles.fieldGroup}>
                <AuthField
                  scheme={scheme}
                  placeholder="User ID"
                  value={userId}
                  onChangeText={setUserId}
                  autoCapitalize="none"
                  autoCorrect={false}
                  autoComplete="username-new"
                  returnKeyType="next"
                  onSubmitEditing={() => nameRef.current?.focus()}
                  blurOnSubmit={false}
                />
                <FieldNote scheme={scheme}>
                  3-20 letters and numbers. This is how friends find you.
                </FieldNote>
              </View>

              <AuthField
                ref={nameRef}
                scheme={scheme}
                placeholder="Name"
                value={name}
                onChangeText={setName}
                autoCapitalize="words"
                autoCorrect={false}
                autoComplete="name"
                returnKeyType="done"
                onSubmitEditing={handleContinue}
              />

              {/* Provider-supplied and fixed — shown so the user knows which
                  account they're setting up, but not editable. It keeps the
                  capsule so the three rows line up, and states in soft ink
                  that it is a fact, not a field. */}
              <View style={styles.fieldGroup}>
                <View style={[fieldStyle(scheme), styles.lockedField]}>
                  <Text
                    style={[styles.lockedText, {color: textSecondary(scheme)}]}
                    numberOfLines={1}
                    ellipsizeMode="middle">
                    {email}
                  </Text>
                  <Icon
                    name="lock-closed"
                    size={14}
                    color={textSecondary(scheme)}
                    style={{opacity: 0.7}}
                  />
                </View>
                <FieldNote scheme={scheme}>
                  From your Google account. This can't be changed.
                </FieldNote>
              </View>
            </View>

            <PillButton
              title="Continue"
              onPress={handleContinue}
              loading={loading}
              color={p.accent}
              style={{marginTop: 4}}
            />

            {/* The way back out of a half-finished account. Quiet ink, well
                clear of Continue — the escape hatch, not the choice this
                screen is asking anyone to make. */}
            <QuietLink
              scheme={scheme}
              title="Sign Out"
              underline={false}
              onPress={() => authService.signOut()}
              disabled={loading}
              style={{marginTop: 6, alignSelf: 'center'}}
            />
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </View>
  );
}

function FieldNote({
  scheme,
  children,
}: {
  scheme: ReturnType<typeof useColorScheme>;
  children: React.ReactNode;
}) {
  return (
    <Text style={[styles.note, {color: textSecondary(scheme)}]}>{children}</Text>
  );
}

const styles = StyleSheet.create({
  heading: {
    gap: 10,
    marginBottom: 4,
  },
  title: {
    fontSize: 34,
  },
  fields: {
    gap: 16,
  },
  fieldGroup: {
    gap: 8,
  },
  lockedField: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  lockedText: {
    flex: 1,
    fontSize: 17,
  },
  note: {
    fontSize: 13,
    lineHeight: 18,
    paddingHorizontal: 18,
  },
});
