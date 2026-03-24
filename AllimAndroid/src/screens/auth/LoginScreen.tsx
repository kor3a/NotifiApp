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
import LinearGradient from 'react-native-linear-gradient';
import {NativeStackNavigationProp} from '@react-navigation/native-stack';
import {AuthStackParamList} from '../../navigation/AppNavigator';

import GradientBackground from '../../components/GradientBackground';
import ThemedInput from '../../components/ThemedInput';
import PrimaryButton from '../../components/PrimaryButton';
import {Colors, Spacing, Radius, cardStyle, cardBorder, textPrimary, textSecondary} from '../../theme/AppTheme';
import {authService} from '../../services/authService';

type Props = {
  navigation: NativeStackNavigationProp<AuthStackParamList, 'Login'>;
};

export default function LoginScreen({navigation}: Props) {
  const scheme = useColorScheme();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [showEmailNotVerified, setShowEmailNotVerified] = useState(false);
  const [resending, setResending] = useState(false);
  const [signupEmail, setSignupEmail] = useState('');
  const [showConfirmation, setShowConfirmation] = useState(false);

  async function handleLogin() {
    if (!email.trim() || !password) {
      Alert.alert('Error', 'Please enter your email and password.');
      return;
    }
    setLoading(true);
    setShowEmailNotVerified(false);
    try {
      await authService.login(email.trim(), password);
    } catch (err: any) {
      if (err.message === 'EMAIL_NOT_VERIFIED') {
        setShowEmailNotVerified(true);
        Alert.alert(
          'Email Not Verified',
          'Please verify your email before logging in.',
        );
      } else {
        const msg =
          err.code === 'auth/invalid-credential' ||
          err.code === 'auth/wrong-password' ||
          err.code === 'auth/user-not-found'
            ? 'Incorrect email or password.'
            : err.message ?? 'Login failed. Please try again.';
        Alert.alert('Login Failed', msg);
      }
    } finally {
      setLoading(false);
    }
  }

  async function handleResendVerification() {
    setResending(true);
    try {
      await authService.resendVerificationEmail();
      Alert.alert('Email Sent', 'Verification email resent. Check your inbox.');
    } catch (err: any) {
      Alert.alert('Error', err.message ?? 'Failed to resend email.');
    } finally {
      setResending(false);
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

            {/* App name */}
            <LinearGradient
              colors={[Colors.blue, Colors.purple]}
              start={{x: 0, y: 0}}
              end={{x: 1, y: 0}}
              style={styles.titleGradient}>
              <Text style={styles.title}>Allim</Text>
            </LinearGradient>

            {/* Signup confirmation banner */}
            {showConfirmation && (
              <View style={[styles.confirmationCard, cardStyle(scheme)]}>
                <Text style={[styles.confirmText, {color: textPrimary(scheme)}]}>
                  A confirmation email has been sent to {signupEmail}. Please
                  click the link to complete sign up.
                </Text>
                <Text style={[styles.confirmSubText, {color: textSecondary(scheme)}]}>
                  Can't find it? Check your spam or junk folder.
                </Text>
              </View>
            )}

            {/* Input fields */}
            <View style={styles.fields}>
              <ThemedInput
                placeholder="Email"
                value={email}
                onChangeText={setEmail}
                keyboardType="email-address"
                autoCapitalize="none"
                autoCorrect={false}
              />
              <ThemedInput
                placeholder="Password"
                value={password}
                onChangeText={setPassword}
                secureTextEntry
                style={{marginTop: Spacing.md}}
              />
            </View>

            {/* Login button */}
            <PrimaryButton
              title="Login"
              onPress={handleLogin}
              loading={loading}
              gradient
              style={styles.loginBtn}
            />

            {/* Resend verification */}
            {showEmailNotVerified && (
              <TouchableOpacity onPress={handleResendVerification} disabled={resending}>
                <Text style={styles.linkText}>
                  {resending ? 'Sending...' : 'Resend Verification Email'}
                </Text>
              </TouchableOpacity>
            )}

            {/* Sign up link */}
            <TouchableOpacity
              onPress={() => navigation.navigate('Signup')}
              style={styles.linkContainer}>
              <Text style={[styles.mutedText, {color: textSecondary(scheme)}]}>
                Don't have an account?{' '}
                <Text style={{color: Colors.blue, textDecorationLine: 'underline'}}>
                  Sign up here.
                </Text>
              </Text>
            </TouchableOpacity>

            {/* Forgot password */}
            <TouchableOpacity
              onPress={() => navigation.navigate('ForgotPassword')}
              style={styles.linkContainer}>
              <Text style={[styles.mutedText, {color: textSecondary(scheme)}]}>
                Forgot password?{' '}
                <Text style={{color: Colors.blue, textDecorationLine: 'underline'}}>
                  Click here
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
    paddingTop: 60,
  },
  titleGradient: {
    alignSelf: 'center',
    marginBottom: Spacing.xl,
    // mask the text with gradient on Android using a workaround
    borderRadius: 4,
    paddingHorizontal: 4,
    backgroundColor: 'transparent',
  },
  title: {
    fontSize: 40,
    fontWeight: '700',
    color: '#fff',
    // On Android gradient text isn't native, so we use white on gradient bg
    letterSpacing: -1,
  },
  confirmationCard: {
    padding: Spacing.md,
    marginBottom: Spacing.lg,
  },
  confirmText: {
    fontSize: 14,
    textAlign: 'center',
    marginBottom: Spacing.xs,
  },
  confirmSubText: {
    fontSize: 12,
    textAlign: 'center',
  },
  fields: {
    marginBottom: Spacing.lg,
  },
  loginBtn: {
    marginBottom: Spacing.md,
  },
  linkContainer: {
    marginTop: Spacing.md,
    alignItems: 'center',
  },
  linkText: {
    color: Colors.blue,
    fontSize: 14,
    textDecorationLine: 'underline',
    textAlign: 'center',
    marginTop: Spacing.md,
  },
  mutedText: {
    fontSize: 12,
    textAlign: 'center',
  },
});
