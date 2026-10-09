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
  Modal,
  ActivityIndicator,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {FirebaseAuthTypes} from '@react-native-firebase/auth';
import {NativeStackScreenProps} from '@react-navigation/native-stack';
import {AuthStackParamList} from '../../navigation/AppNavigator';
import Icon from '../../components/AppIcon';

import GradientBackground from '../../components/GradientBackground';
import GoogleSignInButton, {OrDivider} from '../../components/GoogleSignInButton';
import {cardStyle, sheetBackground, textPrimary, textSecondary} from '../../theme/AppTheme';
import {PillButton, profilePalette} from '../profile/profileUi';
import {AllimWordmark, AuthField, BlushIcon, FormError, QuietLink, authStyles} from './authUi';
import {authService} from '../../services/authService';
import {googleAuthService} from '../../services/googleAuthService';

type Props = NativeStackScreenProps<AuthStackParamList, 'Login'>;

/**
 * A Google credential waiting on the user's existing password, shown by the
 * link sheet below. Set when the Google email already belongs to an
 * email/password account: confirming the password LINKS the two rather than
 * leaving a second account behind.
 */
type PendingLink = {
  email: string;
  credential: FirebaseAuthTypes.AuthCredential;
};

// Port of iOS LoginView.
export default function LoginScreen({navigation, route}: Props) {
  const scheme = useColorScheme();
  const p = profilePalette(scheme);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [showEmailNotVerified, setShowEmailNotVerified] = useState(false);
  const [resending, setResending] = useState(false);
  const [googleLoading, setGoogleLoading] = useState(false);
  const [pendingLink, setPendingLink] = useState<PendingLink | null>(null);
  const [linkPassword, setLinkPassword] = useState('');
  const [linkError, setLinkError] = useState('');
  const [linking, setLinking] = useState(false);

  // Sign Up pops back here with the address it just registered, and this
  // screen says where the confirmation went — as on iOS.
  const signupEmail = route.params?.signupEmail ?? '';

  async function handleLogin() {
    if (!email.trim() || !password) {
      Alert.alert('Note', 'Please enter your email and password.');
      return;
    }
    setLoading(true);
    setShowEmailNotVerified(false);
    try {
      await authService.login(email.trim(), password);
    } catch (err: any) {
      if (err.message === 'EMAIL_NOT_VERIFIED') {
        setShowEmailNotVerified(true);
        Alert.alert('Note', 'Please verify your email before logging in.');
      } else {
        const msg =
          err.code === 'auth/invalid-credential' ||
          err.code === 'auth/wrong-password' ||
          err.code === 'auth/user-not-found'
            ? 'Incorrect email or password.'
            : err.message ?? 'Login failed. Please try again.';
        Alert.alert('Note', msg);
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
          setLinkError('');
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
        'Note',
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
    setLinkError('');
    try {
      await googleAuthService.linkToPasswordAccount(
        pendingLink.email,
        linkPassword,
        pendingLink.credential,
      );
      setPendingLink(null);
      setLinkPassword('');
    } catch (err: any) {
      setLinkError(
        err.code === 'auth/invalid-credential' ||
          err.code === 'auth/wrong-password' ||
          err.code === 'auth/user-not-found'
          ? 'Incorrect password. Please try again.'
          : err.message ?? "Couldn't link your accounts. Please try again.",
      );
    } finally {
      setLinking(false);
    }
  }

  function cancelLink() {
    if (linking) {
      return;
    }
    setPendingLink(null);
    setLinkPassword('');
    setLinkError('');
  }

  async function handleResendVerification() {
    setResending(true);
    try {
      await authService.resendVerificationEmail();
      Alert.alert('Note', 'Verification email resent. Check your inbox.');
    } catch (err: any) {
      Alert.alert('Note', err.message ?? 'Failed to resend email.');
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
            contentContainerStyle={[authStyles.scroll, styles.scroll]}
            keyboardShouldPersistTaps="handled">
            <AllimWordmark scheme={scheme} />

            {!!signupEmail && (
              <View style={[styles.confirmationCard, {backgroundColor: p.sage}]}>
                <Icon name="mail-unread" size={30} color={p.sageInk} />
                <Text style={[styles.confirmText, {color: p.sageInk}]}>
                  A confirmation email has been sent to {signupEmail}. Please
                  click on the link to complete the sign up.
                </Text>
                <Text style={[styles.confirmSubText, {color: p.sageInk}]}>
                  Can't find it? Be sure to check your spam or junk folder.
                </Text>
              </View>
            )}

            <View style={authStyles.fields}>
              <AuthField
                scheme={scheme}
                placeholder="Email"
                value={email}
                onChangeText={setEmail}
                keyboardType="email-address"
                autoCapitalize="none"
                autoCorrect={false}
                autoComplete="email"
                textContentType="emailAddress"
              />
              <AuthField
                scheme={scheme}
                placeholder="Password"
                value={password}
                onChangeText={setPassword}
                secureTextEntry
                autoComplete="password"
                textContentType="password"
                returnKeyType="go"
                onSubmitEditing={handleLogin}
              />
            </View>

            <PillButton
              title="Login"
              onPress={handleLogin}
              loading={loading}
              color={p.accent}
              style={styles.pillTop}
            />

            <View style={styles.social}>
              <OrDivider />
              <GoogleSignInButton
                onPress={handleGoogleSignIn}
                disabled={loading || googleLoading || !!pendingLink}
              />
            </View>

            {showEmailNotVerified && (
              <TouchableOpacity
                onPress={handleResendVerification}
                disabled={resending}
                style={styles.resend}>
                <Text style={[styles.resendText, {color: p.accent}]}>
                  {resending ? 'Sending…' : 'Resend verification email'}
                </Text>
              </TouchableOpacity>
            )}

            {/* The two ways off this screen, as quiet text rather than a
                second and third pill — Login is the only thing here that
                should read as a button. */}
            <View style={styles.offRamps}>
              <TouchableOpacity
                onPress={() => navigation.navigate('Signup')}
                activeOpacity={0.6}
                hitSlop={8}>
                <Text style={[styles.offRampText, {color: textSecondary(scheme)}]}>
                  Don't have an account?{' '}
                  <Text style={[styles.offRampAction, {color: p.accent}]}>Sign up</Text>
                </Text>
              </TouchableOpacity>
              <QuietLink
                scheme={scheme}
                title="Forgot password?"
                onPress={() => navigation.navigate('ForgotPassword')}
              />
            </View>
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>

      {/* Google sign-in in flight: the form dims under a spinner card. */}
      {googleLoading && (
        <View style={[StyleSheet.absoluteFill, styles.loadingScrim]}>
          <View style={[cardStyle(scheme), styles.loadingCard]}>
            <ActivityIndicator size="large" color={p.accent} />
          </View>
        </View>
      )}

      <LinkAccountSheet
        visible={!!pendingLink}
        email={pendingLink?.email ?? ''}
        password={linkPassword}
        onChangePassword={setLinkPassword}
        error={linkError}
        linking={linking}
        onConfirm={handleConfirmLink}
        onCancel={cancelLink}
      />
    </View>
  );
}

/**
 * Password prompt shown when a Google email already belongs to an existing
 * email/password account. Port of the iOS LinkAccountSheet: confirming the
 * password links Google onto that same account instead of creating a
 * duplicate.
 */
function LinkAccountSheet({
  visible,
  email,
  password,
  onChangePassword,
  error,
  linking,
  onConfirm,
  onCancel,
}: {
  visible: boolean;
  email: string;
  password: string;
  onChangePassword: (value: string) => void;
  error: string;
  linking: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  const scheme = useColorScheme();
  const p = profilePalette(scheme);
  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onCancel}>
      <View style={[styles.sheet, {backgroundColor: sheetBackground(scheme)}]}>
        <View style={styles.sheetBar}>
          <TouchableOpacity onPress={onCancel} disabled={linking} hitSlop={8}>
            <Text style={[styles.sheetCancel, {color: p.accent, opacity: linking ? 0.4 : 1}]}>
              Cancel
            </Text>
          </TouchableOpacity>
        </View>
        <ScrollView
          contentContainerStyle={styles.sheetContent}
          keyboardShouldPersistTaps="handled">
          <BlushIcon scheme={scheme} name="link" size={88} glyphSize={34} />
          <Text style={[styles.sheetTitle, {color: textPrimary(scheme)}]}>
            Link your account
          </Text>
          <Text style={[authStyles.subtitle, styles.sheetBody, {color: textSecondary(scheme)}]}>
            You already have an account for {email}. Enter your password to
            connect Google to it — no duplicate account will be created.
          </Text>
          <AuthField
            scheme={scheme}
            placeholder="Password"
            value={password}
            onChangeText={onChangePassword}
            secureTextEntry
            autoFocus
            autoComplete="password"
            returnKeyType="go"
            onSubmitEditing={onConfirm}
            style={styles.sheetField}
          />
          <FormError message={error} />
          <PillButton
            title="Link & Continue"
            onPress={onConfirm}
            loading={linking}
            disabled={!password}
            color={p.accent}
            style={styles.sheetField}
          />
        </ScrollView>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  scroll: {
    paddingTop: 32,
  },
  confirmationCard: {
    alignItems: 'center',
    gap: 10,
    padding: 20,
    borderRadius: 24,
  },
  confirmText: {
    fontSize: 15,
    lineHeight: 21,
    textAlign: 'center',
  },
  confirmSubText: {
    fontSize: 13,
    textAlign: 'center',
    opacity: 0.8,
  },
  pillTop: {
    marginTop: 4,
  },
  social: {
    gap: 12,
    marginTop: 4,
  },
  resend: {
    alignItems: 'center',
    marginTop: 4,
  },
  resendText: {
    fontSize: 14,
    fontWeight: '700',
  },
  offRamps: {
    alignItems: 'center',
    gap: 12,
    marginTop: 10,
  },
  offRampText: {
    fontSize: 14,
    textAlign: 'center',
  },
  offRampAction: {
    fontWeight: '700',
  },
  loadingScrim: {
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(0,0,0,0.25)',
  },
  loadingCard: {
    padding: 28,
    borderRadius: 24,
  },
  sheet: {
    flex: 1,
  },
  sheetBar: {
    height: 52,
    paddingHorizontal: 20,
    flexDirection: 'row',
    alignItems: 'center',
  },
  sheetCancel: {
    fontSize: 17,
  },
  sheetContent: {
    alignItems: 'center',
    gap: 20,
    paddingHorizontal: 24,
    paddingTop: 24,
    paddingBottom: 40,
  },
  sheetTitle: {
    fontSize: 26,
    fontWeight: '800',
    textAlign: 'center',
  },
  sheetBody: {
    fontSize: 15,
  },
  sheetField: {
    alignSelf: 'stretch',
  },
});
