import React, {useState} from 'react';
import {
  Alert,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  useColorScheme,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import auth from '@react-native-firebase/auth';

import GradientBackground from '../../components/GradientBackground';
import ThemedInput from '../../components/ThemedInput';
import PrimaryButton from '../../components/PrimaryButton';
import {
  Colors,
  Spacing,
  cardStyle,
  textPrimary,
  textSecondary,
} from '../../theme/AppTheme';
import {authService, USERNAME_REGEX} from '../../services/authService';
import {useSession} from '../../context/SessionContext';

/**
 * One-time profile setup after a first-time Google sign-in, mirroring the iOS
 * ProfileSetupView. Google gives us a verified email but no username, and the
 * `users` collection is keyed by username, so the user picks one here.
 *
 * The email is fixed — it comes from the provider and identifies the account
 * (Firestore lookups and the security rules both key off it) — so it is shown
 * read-only.
 */
export default function ProfileSetupScreen() {
  const scheme = useColorScheme();
  const {refreshUser} = useSession();

  const email = auth().currentUser?.email ?? '';
  // Nothing is suggested for the username on purpose: a prefilled ID reads as
  // already-decided. The name is prefilled from what Google told us, which is
  // the value people keep anyway.
  const [userId, setUserId] = useState('');
  const [name, setName] = useState(auth().currentUser?.displayName ?? '');
  const [loading, setLoading] = useState(false);

  async function handleContinue() {
    // Validated in the order the fields are shown, so the message points at the
    // first thing the user would look at.
    const normalizedUserId = userId.trim().toLowerCase();
    if (!normalizedUserId) {
      Alert.alert('Error', 'Please choose a user ID.');
      return;
    }
    if (!USERNAME_REGEX.test(normalizedUserId)) {
      Alert.alert(
        'Error',
        'Username must be 3-20 characters and contain only letters and numbers.',
      );
      return;
    }
    if (!name.trim()) {
      Alert.alert('Error', 'Please enter your name.');
      return;
    }

    setLoading(true);
    try {
      await authService.createSocialProfile(normalizedUserId, name);
      // Flips the session to 'ready', which swaps this screen for the app.
      await refreshUser();
    } catch (err: any) {
      Alert.alert('Error', err.message ?? 'Couldn\'t create your profile.');
    } finally {
      setLoading(false);
    }
  }

  function handleSignOut() {
    Alert.alert(
      'Sign Out',
      'Your account was created but has no profile yet. You can finish setting it up next time you sign in.',
      [
        {text: 'Cancel', style: 'cancel'},
        {
          text: 'Sign Out',
          style: 'destructive',
          onPress: () => authService.signOut(),
        },
      ],
    );
  }

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}}>
        <KeyboardAvoidingView
          style={{flex: 1}}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <ScrollView
            contentContainerStyle={styles.scroll}
            keyboardShouldPersistTaps="handled">

            <Text style={[styles.heading, {color: textPrimary(scheme)}]}>
              Finish Setting Up
            </Text>
            <Text style={[styles.subheading, {color: textSecondary(scheme)}]}>
              You're signed in with Google. Pick a user ID so friends can find
              you, and confirm the name they'll see.
            </Text>

            <View style={[styles.emailCard, cardStyle(scheme)]}>
              <Text style={[styles.emailLabel, {color: textSecondary(scheme)}]}>
                Email
              </Text>
              <Text style={[styles.emailValue, {color: textPrimary(scheme)}]}>
                {email}
              </Text>
            </View>

            <View style={styles.fields}>
              <ThemedInput
                placeholder="Username / User ID"
                value={userId}
                onChangeText={setUserId}
                autoCapitalize="none"
                autoCorrect={false}
              />
              <Text style={[styles.hint, {color: textSecondary(scheme)}]}>
                3-20 letters and numbers. This is how friends add you, and it
                can't be changed later.
              </Text>
              <ThemedInput
                placeholder="Display Name (shown to others)"
                value={name}
                onChangeText={setName}
                style={{marginTop: Spacing.md}}
              />
            </View>

            <PrimaryButton
              title="Continue"
              onPress={handleContinue}
              loading={loading}
              gradient
            />

            <TouchableOpacity
              onPress={handleSignOut}
              style={styles.linkContainer}
              disabled={loading}>
              <Text style={[styles.mutedText, {color: Colors.blue}]}>
                Sign out
              </Text>
            </TouchableOpacity>

          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  scroll: {
    flexGrow: 1,
    padding: Spacing.lg,
    paddingTop: 60,
  },
  heading: {
    fontSize: 28,
    fontWeight: '700',
    marginBottom: Spacing.sm,
  },
  subheading: {
    fontSize: 14,
    marginBottom: Spacing.lg,
  },
  emailCard: {
    padding: Spacing.md,
    marginBottom: Spacing.lg,
  },
  emailLabel: {
    fontSize: 12,
    marginBottom: 2,
  },
  emailValue: {
    fontSize: 16,
    fontWeight: '500',
  },
  fields: {
    marginBottom: Spacing.lg,
  },
  hint: {
    fontSize: 12,
    marginTop: Spacing.xs,
  },
  linkContainer: {
    marginTop: Spacing.lg,
    alignItems: 'center',
  },
  mutedText: {
    fontSize: 14,
    textDecorationLine: 'underline',
  },
});
