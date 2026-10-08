import React, {useEffect, useRef, useState} from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TextInput,
  useColorScheme,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import auth from '@react-native-firebase/auth';
import Icon from '../../components/AppIcon';

import GradientBackground from '../../components/GradientBackground';
import {textPrimary, textSecondary} from '../../theme/AppTheme';
import {useSession} from '../../context/SessionContext';
import {userService} from '../../services/userService';
import {googleAuthService} from '../../services/googleAuthService';
import {
  ProfileHeader,
  SectionLabel,
  PillButton,
  fieldStyle,
  profilePalette,
  profileStyles,
} from './profileUi';

type Status = {kind: 'success' | 'error'; message: string} | null;

// Port of iOS AccountSecurityView: display name, and a new password for
// accounts that have one.
export default function AccountSecurityScreen() {
  const scheme = useColorScheme();
  const p = profilePalette(scheme);
  const {currentUser, firebaseUser, refreshUser} = useSession();

  // Accounts created with Google have no password to change.
  const canChangePassword = googleAuthService.hasPasswordProvider(firebaseUser);

  const [name, setName] = useState(currentUser?.name ?? '');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [saving, setSaving] = useState(false);
  const [status, setStatus] = useState<Status>(null);
  const clearTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => () => {
    if (clearTimer.current) {clearTimeout(clearTimer.current);}
  }, []);

  function showStatus(next: Status) {
    if (clearTimer.current) {clearTimeout(clearTimer.current);}
    setStatus(next);
    // Success clears itself after a few seconds, as on iOS; an error stays
    // until the next attempt.
    if (next?.kind === 'success') {
      clearTimer.current = setTimeout(() => setStatus(null), 3000);
    }
  }

  async function handleSave() {
    if (!currentUser) {return;}
    const trimmed = name.trim();
    if (!trimmed) {
      showStatus({kind: 'error', message: 'Name cannot be empty'});
      return;
    }
    const changingPassword = newPassword.length > 0 || confirmPassword.length > 0;
    if (changingPassword) {
      if (newPassword !== confirmPassword) {
        showStatus({kind: 'error', message: 'Passwords do not match'});
        return;
      }
      if (newPassword.length < 6) {
        showStatus({kind: 'error', message: 'Password must be at least 6 characters'});
        return;
      }
    }

    setSaving(true);
    showStatus(null);
    try {
      // The users doc is keyed by username (userId), not the Firebase Auth uid.
      if (trimmed !== currentUser.name) {
        await userService.updateProfile(currentUser.userId, {name: trimmed});
        await refreshUser();
      }
      if (changingPassword) {
        const user = auth().currentUser;
        if (!user) {throw new Error('No authenticated user found');}
        try {
          await user.updatePassword(newPassword);
        } catch (err: any) {
          throw new Error(
            err?.code === 'auth/requires-recent-login'
              ? 'Failed to update password: please sign out and back in, then try again.'
              : `Failed to update password: ${err?.message ?? 'unknown error'}`,
          );
        }
        setNewPassword('');
        setConfirmPassword('');
      }
      showStatus({kind: 'success', message: 'Profile updated successfully!'});
    } catch (err: any) {
      showStatus({kind: 'error', message: err?.message ?? 'Failed to update profile'});
    } finally {
      setSaving(false);
    }
  }

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}} edges={['top', 'left', 'right']}>
        <ProfileHeader scheme={scheme} title="Account Security" />
        <KeyboardAvoidingView
          style={{flex: 1}}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <ScrollView
            contentContainerStyle={profileStyles.scroll}
            keyboardShouldPersistTaps="handled"
            keyboardDismissMode="on-drag">
            {/* Success in sage, failure in rust, as on iOS. */}
            {status && (
              <View
                style={[
                  styles.statusCard,
                  {backgroundColor: status.kind === 'success' ? p.sage : p.rustWash},
                ]}>
                <Icon
                  name={status.kind === 'success' ? 'checkmark-circle' : 'alert-circle'}
                  size={20}
                  color={status.kind === 'success' ? p.sageInk : p.rust}
                />
                <Text style={[styles.statusText, {color: textPrimary(scheme)}]}>
                  {status.message}
                </Text>
              </View>
            )}

            <View style={profileStyles.section}>
              <SectionLabel scheme={scheme} title="Display name" />
              <Text style={[profileStyles.hint, {color: textSecondary(scheme)}]}>
                What friends see when you share a store or a list with them.
              </Text>
              <TextInput
                value={name}
                onChangeText={setName}
                placeholder="Enter your name"
                placeholderTextColor={textSecondary(scheme)}
                autoCapitalize="words"
                autoCorrect={false}
                editable={!saving}
                style={fieldStyle(scheme)}
              />
            </View>

            {canChangePassword && (
              <View style={profileStyles.section}>
                <SectionLabel scheme={scheme} title="Change password" />
                <Text style={[profileStyles.hint, {color: textSecondary(scheme)}]}>
                  Leave both fields blank to keep your current password.
                </Text>
                <TextInput
                  value={newPassword}
                  onChangeText={setNewPassword}
                  placeholder="New password"
                  placeholderTextColor={textSecondary(scheme)}
                  secureTextEntry
                  autoCapitalize="none"
                  editable={!saving}
                  style={fieldStyle(scheme)}
                />
                <TextInput
                  value={confirmPassword}
                  onChangeText={setConfirmPassword}
                  placeholder="Confirm new password"
                  placeholderTextColor={textSecondary(scheme)}
                  secureTextEntry
                  autoCapitalize="none"
                  editable={!saving}
                  style={fieldStyle(scheme)}
                />
              </View>
            )}

            <PillButton
              title="Save Changes"
              loading={saving}
              onPress={handleSave}
              style={{marginTop: 4}}
            />
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  statusCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    padding: 16,
    borderRadius: 22,
  },
  statusText: {
    flex: 1,
    fontSize: 15,
  },
});
