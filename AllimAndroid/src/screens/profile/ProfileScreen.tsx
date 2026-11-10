import React, {useEffect, useState} from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  TextInput,
  Alert,
  Modal,
  useColorScheme,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {useNavigation} from '@react-navigation/native';
import Icon from '../../components/AppIcon';
import {launchImageLibrary} from 'react-native-image-picker';

import GradientBackground from '../../components/GradientBackground';
import ProfileAvatar from '../../components/ProfileAvatar';
import AdBanner from '../../components/AdBanner';
import {hasPremiumAccess} from '../../services/subscription';
import {
  cardBackground,
  cardStyle,
  sheetBackground,
  textPrimary,
  textSecondary,
} from '../../theme/AppTheme';
import {useSession} from '../../context/SessionContext';
import {userService} from '../../services/userService';
import {authService} from '../../services/authService';
import {googleAuthService} from '../../services/googleAuthService';
import {friendService} from '../../services/friendService';
import {
  ProfileHeader,
  SectionLabel,
  NavRow,
  PillButton,
  fieldStyle,
  profilePalette,
  profileStyles,
} from './profileUi';

// Laid out like the iOS ProfileView: an identity card you tap to change the
// photo, then rows that open the rest — Account, Friends, Account actions.
export default function ProfileScreen() {
  const scheme = useColorScheme();
  const p = profilePalette(scheme);
  const navigation = useNavigation<any>();
  const {currentUser, firebaseUser, refreshUser} = useSession();
  const myId = currentUser?.userId ?? '';
  const isPremium = hasPremiumAccess(currentUser);

  // An account created with Google has no password to type — Firebase's
  // "recent login" requirement is met by re-running the Google sheet instead.
  const usesPassword = googleAuthService.hasPasswordProvider(firebaseUser);

  const [uploadingPhoto, setUploadingPhoto] = useState(false);
  const [pendingRequests, setPendingRequests] = useState(0);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [deletePassword, setDeletePassword] = useState('');
  const [deleting, setDeleting] = useState(false);

  // The Friends row carries the count of requests still waiting, as on iOS.
  useEffect(() => {
    if (!myId) {return;}
    return friendService.subscribeToPendingRequests(myId, r =>
      setPendingRequests(r.length),
    );
  }, [myId]);

  async function handlePickPhoto() {
    if (!currentUser) {return;}
    const result = await launchImageLibrary({mediaType: 'photo', quality: 0.8});
    if (!result.assets?.[0]?.uri) {return;}
    setUploadingPhoto(true);
    try {
      await userService.uploadProfilePicture(currentUser.userId, result.assets[0].uri);
      await refreshUser();
    } catch (err: any) {
      Alert.alert('Error', err.message);
    } finally {
      setUploadingPhoto(false);
    }
  }

  function handleSignOut() {
    Alert.alert('Sign Out', 'Are you sure you want to sign out?', [
      {text: 'Cancel', style: 'cancel'},
      {
        text: 'Sign Out',
        style: 'destructive',
        onPress: () => authService.signOut(),
      },
    ]);
  }

  function closeDeleteModal() {
    setShowDeleteModal(false);
    setDeletePassword('');
  }

  async function handleDeleteAccount() {
    if (usesPassword && !deletePassword) {return;}
    setDeleting(true);
    try {
      const deleted = await authService.deleteAccount(deletePassword);
      // Dismissing the Google re-auth sheet leaves the account untouched, so
      // keep the confirmation open rather than implying anything happened.
      if (!deleted) {
        return;
      }
      closeDeleteModal();
    } catch (err: any) {
      Alert.alert('Error', err.message ?? 'Failed to delete account.');
      closeDeleteModal();
    } finally {
      setDeleting(false);
    }
  }

  // A waiting request is the one thing on this row worth interrupting for,
  // so it takes the line over the description of what Friends is.
  const friendsSubtitle =
    pendingRequests === 0
      ? 'Add friends and family to share stores and reminders with'
      : pendingRequests === 1
        ? '1 friend request waiting'
        : `${pendingRequests} friend requests waiting`;

  if (!currentUser) {
    return (
      <View style={{flex: 1}}>
        <GradientBackground />
        <SafeAreaView style={styles.center}>
          <ActivityIndicator size="large" color={p.accent} />
          <Text style={[styles.loadingText, {color: textSecondary(scheme)}]}>
            Loading profile...
          </Text>
        </SafeAreaView>
      </View>
    );
  }

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}} edges={['top', 'left', 'right']}>
        {/* The iOS toolbar crown: subscribers manage their plan, everyone
            else sees the paywall. Ionicons has no crown, so the paywall's
            diamond stands in, filled once you own Premium. */}
        <ProfileHeader
          scheme={scheme}
          title="Profile"
          right={
            <TouchableOpacity
              onPress={() =>
                navigation.navigate(isPremium ? 'SubscriptionManagement' : 'Subscription')
              }
              hitSlop={{top: 10, bottom: 10, left: 10, right: 10}}
              style={styles.premiumButton}
              accessibilityLabel={isPremium ? 'Manage subscription' : 'Allim Premium'}>
              <Icon
                name={isPremium ? 'diamond' : 'diamond-outline'}
                size={24}
                color={isPremium ? p.accent : textSecondary(scheme)}
              />
            </TouchableOpacity>
          }
        />
        <ScrollView contentContainerStyle={[profileStyles.scroll, {paddingTop: 8}]}>
          {/* Identity */}
          <View style={[cardStyle(scheme), styles.identityCard]}>
            <TouchableOpacity
              onPress={handlePickPhoto}
              disabled={uploadingPhoto}
              activeOpacity={0.8}
              accessibilityLabel="Change profile picture">
              {uploadingPhoto ? (
                <View style={[styles.avatarPlaceholder, {backgroundColor: p.blush}]}>
                  <ActivityIndicator color={p.accent} />
                </View>
              ) : (
                <ProfileAvatar
                  url={currentUser.profilePictureURL}
                  name={currentUser.name}
                  size={92}
                />
              )}
              <View
                style={[
                  styles.cameraBadge,
                  {backgroundColor: p.accent, borderColor: cardBackground(scheme)},
                ]}>
                <Icon name="camera" size={14} color="#fff" />
              </View>
            </TouchableOpacity>

            <View style={styles.identityText}>
              <View style={styles.nameRow}>
                <Text
                  style={[styles.userName, {color: textPrimary(scheme)}]}
                  numberOfLines={1}>
                  {currentUser.name}
                </Text>
                {isPremium && (
                  <View style={[styles.premiumBadge, {backgroundColor: p.sage}]}>
                    <Text style={[styles.premiumText, {color: p.sageInk}]}>PREMIUM</Text>
                  </View>
                )}
              </View>
              <Text
                style={[styles.userHandle, {color: textSecondary(scheme)}]}
                numberOfLines={1}>
                @{currentUser.userId}
              </Text>
              <Text
                style={[styles.userEmail, {color: textSecondary(scheme)}]}
                numberOfLines={1}>
                {currentUser.email}
              </Text>
            </View>
          </View>

          {/* AdBanner carries its own bottom margin; cancel it so the gap
              matches the rest of the sections. */}
          {!isPremium && (
            <View style={{marginBottom: -16}}>
              <AdBanner onPress={() => navigation.navigate('Subscription')} />
            </View>
          )}

          {/* Account */}
          <View style={profileStyles.section}>
            <SectionLabel scheme={scheme} title="Account" />
            <NavRow
              scheme={scheme}
              icon="lock-closed"
              title="Account Security"
              subtitle="Your display name and password"
              onPress={() => navigation.navigate('AccountSecurity')}
            />
            <NavRow
              scheme={scheme}
              icon="information-circle"
              title="About Allim"
              subtitle="Version, privacy policy and what the app does"
              onPress={() => navigation.navigate('About')}
            />
            <NavRow
              scheme={scheme}
              icon="chatbox-ellipses"
              title="Report Errors and Feedback"
              subtitle="Tell us what's broken or what you'd like next"
              onPress={() => navigation.navigate('ReportFeedback')}
            />
          </View>

          {/* Friends — reached from here rather than a tab, as on iOS. */}
          <View style={profileStyles.section}>
            <SectionLabel scheme={scheme} title="Friends" />
            <NavRow
              scheme={scheme}
              icon="people"
              title="Friends & Family"
              subtitle={friendsSubtitle}
              onPress={() => navigation.navigate('Friends')}
            />
          </View>

          {/* Account actions */}
          <View style={profileStyles.section}>
            <SectionLabel scheme={scheme} title="Account actions" />
            <NavRow
              scheme={scheme}
              icon="log-out-outline"
              title="Sign Out"
              tint={textSecondary(scheme)}
              accessory={null}
              onPress={handleSignOut}
            />
            <NavRow
              scheme={scheme}
              icon="trash"
              title="Delete Account"
              subtitle="Permanently removes your account and everything in it"
              tint={p.rust}
              accessory={null}
              onPress={() => setShowDeleteModal(true)}
            />
          </View>
        </ScrollView>
      </SafeAreaView>

      {/* Delete confirmation — the iOS alert, with the password field only
          for accounts that have a password. */}
      <Modal
        visible={showDeleteModal}
        transparent
        animationType="fade"
        onRequestClose={() => !deleting && closeDeleteModal()}>
        <KeyboardAvoidingView
          style={styles.backdrop}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <View style={[styles.dialog, {backgroundColor: sheetBackground(scheme)}]}>
            <View style={[styles.dialogIcon, {backgroundColor: p.rustWash}]}>
              <Icon name="person-remove" size={26} color={p.rust} />
            </View>
            <Text style={[styles.dialogTitle, {color: textPrimary(scheme)}]}>
              Delete Account
            </Text>
            <Text style={[styles.dialogMessage, {color: textSecondary(scheme)}]}>
              This will permanently delete your account and all associated data. This
              action cannot be undone.
              {usesPassword
                ? '\n\nPlease enter your password to confirm.'
                : '\n\nYou may be asked to confirm with Google first.'}
            </Text>
            {usesPassword && (
              <TextInput
                placeholder="Password"
                placeholderTextColor={textSecondary(scheme)}
                value={deletePassword}
                onChangeText={setDeletePassword}
                secureTextEntry
                autoFocus
                editable={!deleting}
                style={[fieldStyle(scheme), styles.dialogField]}
              />
            )}
            <PillButton
              title="Delete"
              color={p.rust}
              loading={deleting}
              disabled={usesPassword && !deletePassword}
              onPress={handleDeleteAccount}
              style={styles.dialogButton}
            />
            <TouchableOpacity
              onPress={closeDeleteModal}
              disabled={deleting}
              style={styles.dialogCancel}>
              <Text style={[styles.dialogCancelText, {color: p.accent}]}>Cancel</Text>
            </TouchableOpacity>
          </View>
        </KeyboardAvoidingView>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 14,
  },
  loadingText: {
    fontSize: 16,
  },
  identityCard: {
    alignItems: 'center',
    gap: 16,
    paddingVertical: 24,
    paddingHorizontal: 20,
    borderRadius: 28,
    marginVertical: 0,
  },
  avatarPlaceholder: {
    width: 92,
    height: 92,
    borderRadius: 46,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cameraBadge: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: 30,
    height: 30,
    borderRadius: 15,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2.5,
  },
  identityText: {
    alignItems: 'center',
    gap: 4,
    alignSelf: 'stretch',
  },
  nameRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    maxWidth: '100%',
  },
  userName: {
    flexShrink: 1,
    fontSize: 26,
    fontWeight: '800',
  },
  premiumButton: {
    padding: 4,
  },
  premiumBadge: {
    borderRadius: 999,
    paddingHorizontal: 8,
    paddingVertical: 3,
  },
  premiumText: {
    fontSize: 10,
    fontWeight: '700',
    letterSpacing: 0.6,
  },
  userHandle: {
    fontSize: 15,
    fontWeight: '600',
  },
  userEmail: {
    fontSize: 14,
    opacity: 0.85,
  },
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.4)',
    justifyContent: 'center',
    padding: 28,
  },
  dialog: {
    borderRadius: 28,
    padding: 24,
    alignItems: 'center',
  },
  dialogIcon: {
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 14,
  },
  dialogTitle: {
    fontSize: 20,
    fontWeight: '800',
    marginBottom: 8,
  },
  dialogMessage: {
    fontSize: 15,
    lineHeight: 21,
    textAlign: 'center',
    marginBottom: 18,
  },
  dialogField: {
    alignSelf: 'stretch',
    marginBottom: 14,
  },
  dialogButton: {
    alignSelf: 'stretch',
  },
  dialogCancel: {
    paddingTop: 14,
    paddingBottom: 2,
  },
  dialogCancelText: {
    fontSize: 16,
    fontWeight: '600',
  },
});
