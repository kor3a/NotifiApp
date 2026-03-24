import React, {useState} from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  useColorScheme,
  Alert,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {NativeStackNavigationProp} from '@react-navigation/native-stack';
import {AuthStackParamList} from '../../navigation/AppNavigator';

import GradientBackground from '../../components/GradientBackground';
import ThemedInput from '../../components/ThemedInput';
import PrimaryButton from '../../components/PrimaryButton';
import {Colors, Spacing, textPrimary, textSecondary} from '../../theme/AppTheme';
import {authService} from '../../services/authService';

type Props = {
  navigation: NativeStackNavigationProp<AuthStackParamList, 'ForgotPassword'>;
};

export default function ForgotPasswordScreen({navigation}: Props) {
  const scheme = useColorScheme();
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);

  async function handleReset() {
    if (!email.trim()) {
      Alert.alert('Error', 'Please enter your email address.');
      return;
    }
    setLoading(true);
    try {
      await authService.sendPasswordReset(email.trim().toLowerCase());
      setSent(true);
    } catch (err: any) {
      Alert.alert('Error', err.message ?? 'Failed to send reset email.');
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
          <View style={styles.container}>
            <TouchableOpacity
              onPress={() => navigation.goBack()}
              style={styles.backButton}>
              <Text style={{color: Colors.blue, fontSize: 16}}>← Back</Text>
            </TouchableOpacity>

            <Text style={[styles.heading, {color: textPrimary(scheme)}]}>
              Reset Password
            </Text>
            <Text style={[styles.subtitle, {color: textSecondary(scheme)}]}>
              Enter your email and we'll send you a reset link.
            </Text>

            {sent ? (
              <View style={styles.sentContainer}>
                <Text style={[styles.sentText, {color: Colors.green}]}>
                  ✓ Password reset email sent! Check your inbox.
                </Text>
              </View>
            ) : (
              <>
                <ThemedInput
                  placeholder="Email"
                  value={email}
                  onChangeText={setEmail}
                  keyboardType="email-address"
                  autoCapitalize="none"
                  style={styles.input}
                />
                <PrimaryButton
                  title="Send Reset Email"
                  onPress={handleReset}
                  loading={loading}
                  gradient
                  style={styles.button}
                />
              </>
            )}
          </View>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: Spacing.lg,
    paddingTop: 40,
  },
  backButton: {
    marginBottom: Spacing.lg,
  },
  heading: {
    fontSize: 28,
    fontWeight: '700',
    marginBottom: Spacing.sm,
  },
  subtitle: {
    fontSize: 16,
    marginBottom: Spacing.xl,
    lineHeight: 22,
  },
  input: {
    marginBottom: Spacing.lg,
  },
  button: {},
  sentContainer: {
    padding: Spacing.lg,
    alignItems: 'center',
  },
  sentText: {
    fontSize: 16,
    textAlign: 'center',
    lineHeight: 24,
  },
});
