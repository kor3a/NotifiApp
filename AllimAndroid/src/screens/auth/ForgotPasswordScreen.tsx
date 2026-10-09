import React, {useState} from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  useColorScheme,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {NativeStackScreenProps} from '@react-navigation/native-stack';
import {AuthStackParamList} from '../../navigation/AppNavigator';
import Icon from '../../components/AppIcon';

import GradientBackground from '../../components/GradientBackground';
import {cardStyle, textPrimary, textSecondary} from '../../theme/AppTheme';
import {PillButton, ProfileHeader, profilePalette} from '../profile/profileUi';
import {AuthField, QuietLink, authStyles} from './authUi';
import {authService} from '../../services/authService';

type Props = NativeStackScreenProps<AuthStackParamList, 'ForgotPassword'>;

const EMAIL_REGEX = /^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;

type Status = {kind: 'success' | 'error'; message: string} | null;

// Port of iOS ForgotPasswordView.
export default function ForgotPasswordScreen({navigation}: Props) {
  const scheme = useColorScheme();
  const p = profilePalette(scheme);
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState<Status>(null);

  async function handleReset() {
    const trimmed = email.trim();
    if (!trimmed) {
      setStatus({kind: 'error', message: 'Please enter your email address.'});
      return;
    }
    if (!EMAIL_REGEX.test(trimmed)) {
      setStatus({
        kind: 'error',
        message: 'Please enter a valid email address in the format: example@email.com',
      });
      return;
    }
    setLoading(true);
    setStatus(null);
    try {
      await authService.sendPasswordReset(trimmed.toLowerCase());
      setStatus({
        kind: 'success',
        message:
          'Password reset email sent! Please check your inbox and follow the instructions to reset your password.',
      });
    } catch (err: any) {
      setStatus({
        kind: 'error',
        message: err.message ?? 'Failed to send reset email.',
      });
    } finally {
      setLoading(false);
    }
  }

  // Success in sage, failure on a blush card with the destructive tint — the
  // same two answers the rest of the app gives.
  function renderStatusCard() {
    if (!status) {
      return null;
    }
    const isSuccess = status.kind === 'success';
    return (
      <View
        style={[
          cardStyle(scheme),
          styles.statusCard,
          {backgroundColor: isSuccess ? p.sage : p.rustWash},
        ]}>
        <Icon
          name={isSuccess ? 'checkmark-circle' : 'alert-circle'}
          size={20}
          color={isSuccess ? p.sageInk : p.rust}
        />
        <Text style={[styles.statusText, {color: textPrimary(scheme)}]}>
          {status.message}
        </Text>
      </View>
    );
  }

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}}>
        <ProfileHeader scheme={scheme} title="" />
        <KeyboardAvoidingView
          style={{flex: 1}}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <ScrollView
            contentContainerStyle={[authStyles.scroll, {paddingTop: 28}]}
            keyboardShouldPersistTaps="handled"
            keyboardDismissMode="interactive">
            <View style={styles.heading}>
              <Text style={[authStyles.display, {color: textPrimary(scheme)}]}>
                Forgot Password
              </Text>
              <Text style={[authStyles.subtitle, {color: textSecondary(scheme)}]}>
                Enter your email address and we'll send you instructions to reset
                your password.
              </Text>
            </View>

            {renderStatusCard()}

            <AuthField
              scheme={scheme}
              placeholder="Email"
              value={email}
              onChangeText={setEmail}
              keyboardType="email-address"
              autoCapitalize="none"
              autoCorrect={false}
              autoComplete="email"
              returnKeyType="send"
              onSubmitEditing={handleReset}
            />

            <PillButton
              title="Send Reset Email"
              onPress={handleReset}
              loading={loading}
              color={p.accent}
              style={{marginTop: 4}}
            />

            <QuietLink
              scheme={scheme}
              title="Back to Login"
              onPress={() => navigation.goBack()}
              style={{marginTop: 6, alignSelf: 'center'}}
            />
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  heading: {
    gap: 10,
    paddingHorizontal: 4,
    marginBottom: 4,
  },
  statusCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    padding: 16,
    borderRadius: 24,
    marginVertical: 0,
  },
  statusText: {
    flex: 1,
    fontSize: 15,
    lineHeight: 21,
  },
});
