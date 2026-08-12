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
import {FirebaseAuthTypes} from '@react-native-firebase/auth';
import {NativeStackNavigationProp} from '@react-navigation/native-stack';
import {AuthStackParamList} from '../../navigation/AppNavigator';

import GradientBackground from '../../components/GradientBackground';
import ThemedInput from '../../components/ThemedInput';
import PrimaryButton from '../../components/PrimaryButton';
import GoogleSignInButton, {OrDivider} from '../../components/GoogleSignInButton';
import {Colors, Spacing, Radius, cardStyle, cardBorder, textPrimary, textSecondary} from '../../theme/AppTheme';
import {authService} from '../../services/authService';
import {googleAuthService} from '../../services/googleAuthService';

type Props = {
  navigation: NativeStackNavigationProp<AuthStackParamList, 'Login'>;
};

/**
 * A Google credential waiting on the user's existing password, shown by the
 * link card below. Set when the Google email already belongs to an
 * email/password account: confirming the password LINKS the two rather than
 * leaving a second account behind.
 */
type PendingLink = {
  email: string;
  credential: FirebaseAuthTypes.AuthCredential;
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
  const [googleLoading, setGoogleLoading] = useState(false);
  const [pendingLink, setPendingLink] = useState<PendingLink | null>(null);
  const [linkPassword, setLinkPassword] = useState('');
  const [linking, setLinking] = useState(false);

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

  async function handleGoogleSignIn() {
    setGoogleLoading(true);
    setShowEmailNotVerified(false);
    try {
      const outcome = await googleAuthService.signIn();
      switch (outcome.status) {
        case 'signedIn':
          // The session listener swaps this screen out; nothing to do here.
          break;
        case 'cancelled':
          break;
        case 'needsPasswordLink':
          setLinkPassword('');
          setPendingLink({
            email: outcome.email,
            credential: outcome.credential,
          });
          break;
        case 'appleAccountExists':
          Alert.alert(
            'Account Already Exists',
            `${outcome.email} is already signed up with Apple. Sign in with Apple in the Allim iOS app to use that account, or sign in here with a different Google account.`,
          );
          break;
      }
    } catch (err: any) {
      Alert.alert(
        'Google Sign-In Failed',
        err.message ?? 'Google Sign-In failed. Please try again.',
      );
    } finally {
      setGoogleLoading(false);
    }
  }

  async function handleConfirmLink() {
    if (!pendingLink || !linkPassword) {
      return;
    }
    setLinking(true);
    try {
      await googleAuthService.linkToPasswordAccount(
        pendingLink.email,
        linkPassword,
        pendingLink.credential,
      );
      setPendingLink(null);
      setLinkPassword('');
    } catch (err: any) {
      const msg =
        err.code === 'auth/invalid-credential' ||
        err.code === 'auth/wrong-password' ||
        err.code === 'auth/user-not-found'
          ? 'Incorrect password. Please try again.'
          : err.message ?? 'Couldn\'t link your accounts. Please try again.';
      Alert.alert('Link Failed', msg);
    } finally {
      setLinking(false);
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

            {/* Continue with Google */}
            <OrDivider />
            <GoogleSignInButton
              onPress={handleGoogleSignIn}
              loading={googleLoading}
              disabled={loading || !!pendingLink}
            />

            {/* Link prompt: this Google email already has a password account */}
            {pendingLink && (
              <View style={[styles.linkCard, cardStyle(scheme)]}>
                <Text style={[styles.linkCardTitle, {color: textPrimary(scheme)}]}>
                  Link Your Account
                </Text>
                <Text style={[styles.linkCardBody, {color: textSecondary(scheme)}]}>
                  {pendingLink.email} already has an Allim account with a
                  password. Enter it once and Google will be added to that same
                  account — no second account, and all your stores and reminders
                  stay put.
                </Text>
                <ThemedInput
                  placeholder="Password"
                  value={linkPassword}
                  onChangeText={setLinkPassword}
                  secureTextEntry
                  autoFocus
                  style={{marginTop: Spacing.md}}
                />
                <View style={styles.linkActions}>
                  <TouchableOpacity
                    style={[styles.linkBtn, {backgroundColor: Colors.blue + '1A'}]}
                    onPress={() => {
                      setPendingLink(null);
                      setLinkPassword('');
                    }}
                    disabled={linking}>
                    <Text style={{color: Colors.blue, fontWeight: '600'}}>
                      Cancel
                    </Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[styles.linkBtn, {backgroundColor: Colors.blue}]}
                    onPress={handleConfirmLink}
                    disabled={linking || !linkPassword}>
                    <Text style={{color: '#fff', fontWeight: '600'}}>
                      {linking ? 'Linking...' : 'Link'}
                    </Text>
                  </TouchableOpacity>
                </View>
              </View>
            )}

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
  linkCard: {
    padding: Spacing.md,
    marginTop: Spacing.md,
  },
  linkCardTitle: {
    fontSize: 17,
    fontWeight: '600',
    marginBottom: Spacing.xs,
  },
  linkCardBody: {
    fontSize: 13,
    lineHeight: 18,
  },
  linkActions: {
    flexDirection: 'row',
    gap: Spacing.sm,
    marginTop: Spacing.md,
  },
  linkBtn: {
    flex: 1,
    height: 44,
    borderRadius: Radius.md,
    alignItems: 'center',
    justifyContent: 'center',
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
