import React, {useState} from 'react';
import {
  View,
  Text,
  ScrollView,
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
  navigation: NativeStackNavigationProp<AuthStackParamList, 'Signup'>;
};

export default function SignupScreen({navigation}: Props) {
  const scheme = useColorScheme();
  const [userId, setUserId] = useState('');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSignup() {
    if (!userId.trim() || !name.trim() || !email.trim() || !password) {
      Alert.alert('Error', 'Please fill in all fields.');
      return;
    }
    if (password !== confirmPassword) {
      Alert.alert('Error', 'Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      Alert.alert('Error', 'Password must be at least 6 characters.');
      return;
    }

    setLoading(true);
    try {
      await authService.signup(
        email.trim().toLowerCase(),
        password,
        name.trim(),
        userId.trim(),
      );
      Alert.alert(
        'Verify Your Email',
        `A confirmation email has been sent to ${email.trim()}. Please verify before logging in.`,
        [{text: 'OK', onPress: () => navigation.navigate('Login')}],
      );
    } catch (err: any) {
      const msg =
        err.code === 'auth/email-already-in-use'
          ? 'This email is already registered.'
          : err.code === 'auth/weak-password'
          ? 'Password is too weak.'
          : err.message ?? 'Signup failed. Please try again.';
      Alert.alert('Signup Failed', msg);
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
            contentContainerStyle={styles.scroll}
            keyboardShouldPersistTaps="handled">

            <TouchableOpacity
              onPress={() => navigation.goBack()}
              style={styles.backButton}>
              <Text style={{color: Colors.blue, fontSize: 16}}>← Back</Text>
            </TouchableOpacity>

            <Text style={[styles.heading, {color: textPrimary(scheme)}]}>
              Create Account
            </Text>

            <View style={styles.fields}>
              <ThemedInput
                placeholder="Display Name (shown to others)"
                value={name}
                onChangeText={setName}
              />
              <ThemedInput
                placeholder="Username / User ID"
                value={userId}
                onChangeText={setUserId}
                autoCapitalize="none"
                style={{marginTop: Spacing.md}}
              />
              <ThemedInput
                placeholder="Email"
                value={email}
                onChangeText={setEmail}
                keyboardType="email-address"
                autoCapitalize="none"
                style={{marginTop: Spacing.md}}
              />
              <ThemedInput
                placeholder="Password"
                value={password}
                onChangeText={setPassword}
                secureTextEntry
                style={{marginTop: Spacing.md}}
              />
              <ThemedInput
                placeholder="Confirm Password"
                value={confirmPassword}
                onChangeText={setConfirmPassword}
                secureTextEntry
                style={{marginTop: Spacing.md}}
              />
            </View>

            <PrimaryButton
              title="Sign Up"
              onPress={handleSignup}
              loading={loading}
              gradient
            />

            <TouchableOpacity
              onPress={() => navigation.navigate('Login')}
              style={styles.linkContainer}>
              <Text style={[styles.mutedText, {color: textSecondary(scheme)}]}>
                Already have an account?{' '}
                <Text style={{color: Colors.blue, textDecorationLine: 'underline'}}>
                  Login
                </Text>
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
    paddingTop: 40,
  },
  backButton: {
    marginBottom: Spacing.lg,
  },
  heading: {
    fontSize: 28,
    fontWeight: '700',
    marginBottom: Spacing.xl,
  },
  fields: {
    marginBottom: Spacing.lg,
  },
  linkContainer: {
    marginTop: Spacing.lg,
    alignItems: 'center',
  },
  mutedText: {
    fontSize: 12,
    textAlign: 'center',
  },
});
