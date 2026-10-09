import React, {useRef, useState} from 'react';
import {
  View,
  Text,
  ScrollView,
  TextInput,
  KeyboardAvoidingView,
  Platform,
  useColorScheme,
  Alert,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {NativeStackScreenProps} from '@react-navigation/native-stack';
import {AuthStackParamList} from '../../navigation/AppNavigator';

import GradientBackground from '../../components/GradientBackground';
import {textPrimary} from '../../theme/AppTheme';
import {PillButton, ProfileHeader, profilePalette} from '../profile/profileUi';
import {AuthField, authStyles} from './authUi';
import {authService} from '../../services/authService';

type Props = NativeStackScreenProps<AuthStackParamList, 'Signup'>;

// Port of iOS SignupView.
export default function SignupScreen({navigation}: Props) {
  const scheme = useColorScheme();
  const p = profilePalette(scheme);
  const [userId, setUserId] = useState('');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const emailRef = useRef<TextInput>(null);
  const nameRef = useRef<TextInput>(null);
  const passwordRef = useRef<TextInput>(null);
  const confirmRef = useRef<TextInput>(null);

  // Back to Login, which shows where the confirmation email went — the iOS
  // onSignupComplete hand-off.
  function returnToLogin(registeredEmail: string) {
    navigation.popTo('Login', {signupEmail: registeredEmail});
  }

  async function handleSignup() {
    if (!userId.trim() || !name.trim() || !email.trim() || !password) {
      Alert.alert('Note', 'Please fill in all fields.');
      return;
    }
    if (password !== confirmPassword) {
      Alert.alert('Note', 'Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      Alert.alert('Note', 'Password must be at least 6 characters.');
      return;
    }

    const normalizedEmail = email.trim().toLowerCase();
    setLoading(true);
    try {
      await authService.signup(normalizedEmail, password, name.trim(), userId.trim());
      returnToLogin(normalizedEmail);
    } catch (err: any) {
      // An unverified account from a previous signup attempt — the backend has
      // re-sent the verification link, so point the user back to their inbox.
      if (err.message === 'EMAIL_PENDING_VERIFICATION') {
        returnToLogin(normalizedEmail);
        return;
      }
      const msg =
        err.code === 'auth/email-already-in-use'
          ? 'This email is already registered. Please log in instead.'
          : err.code === 'auth/weak-password'
          ? 'Password is too weak.'
          : err.message ?? 'Signup failed. Please try again.';
      Alert.alert('Note', msg);
    } finally {
      setLoading(false);
    }
  }

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}}>
        {/* Pushed from Login, so a back chevron and no title — the heading
            below names the job. */}
        <ProfileHeader scheme={scheme} title="" />
        <KeyboardAvoidingView
          style={{flex: 1}}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <ScrollView
            contentContainerStyle={[authStyles.scroll, {paddingTop: 24}]}
            keyboardShouldPersistTaps="handled">
            <Text style={[authStyles.display, {color: textPrimary(scheme), marginBottom: 4}]}>
              Create your account
            </Text>

            <View style={authStyles.fields}>
              <AuthField
                scheme={scheme}
                placeholder="User ID"
                value={userId}
                onChangeText={setUserId}
                autoCapitalize="none"
                autoCorrect={false}
                autoComplete="username-new"
                returnKeyType="next"
                onSubmitEditing={() => emailRef.current?.focus()}
                blurOnSubmit={false}
              />
              <AuthField
                ref={emailRef}
                scheme={scheme}
                placeholder="Email"
                value={email}
                onChangeText={setEmail}
                keyboardType="email-address"
                autoCapitalize="none"
                autoCorrect={false}
                autoComplete="email"
                returnKeyType="next"
                onSubmitEditing={() => nameRef.current?.focus()}
                blurOnSubmit={false}
              />
              <AuthField
                ref={nameRef}
                scheme={scheme}
                placeholder="Name"
                value={name}
                onChangeText={setName}
                autoCapitalize="words"
                autoCorrect={false}
                autoComplete="name"
                returnKeyType="next"
                onSubmitEditing={() => passwordRef.current?.focus()}
                blurOnSubmit={false}
              />
              <AuthField
                ref={passwordRef}
                scheme={scheme}
                placeholder="Password"
                value={password}
                onChangeText={setPassword}
                secureTextEntry
                autoComplete="password-new"
                returnKeyType="next"
                onSubmitEditing={() => confirmRef.current?.focus()}
                blurOnSubmit={false}
              />
              <AuthField
                ref={confirmRef}
                scheme={scheme}
                placeholder="Confirm Password"
                value={confirmPassword}
                onChangeText={setConfirmPassword}
                secureTextEntry
                autoComplete="password-new"
                returnKeyType="go"
                onSubmitEditing={handleSignup}
              />
            </View>

            <PillButton
              title="Sign Up"
              onPress={handleSignup}
              loading={loading}
              color={p.accent}
              style={{marginTop: 4}}
            />
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </View>
  );
}
