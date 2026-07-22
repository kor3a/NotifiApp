import React, {useState} from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  TextInput,
  Alert,
  useColorScheme,
  ActivityIndicator,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {useNavigation} from '@react-navigation/native';
import Icon from 'react-native-vector-icons/Ionicons';
import {launchImageLibrary} from 'react-native-image-picker';

import GradientBackground from '../../components/GradientBackground';
import ProfileAvatar from '../../components/ProfileAvatar';
import AdBanner from '../../components/AdBanner';
import PrimaryButton from '../../components/PrimaryButton';
import {
  Colors,
  Spacing,
  Radius,
  cardStyle,
  textPrimary,
  textSecondary,
  cardBackground,
} from '../../theme/AppTheme';
import {useSession} from '../../context/SessionContext';
import {userService} from '../../services/userService';
import {authService} from '../../services/authService';

export default function ProfileScreen() {
  const scheme = useColorScheme();
  const navigation = useNavigation();
  const {currentUser, firebaseUser, refreshUser} = useSession();

  const [editName, setEditName] = useState(currentUser?.name ?? '');
  const [saving, setSaving] = useState(false);
  const [uploadingPhoto, setUploadingPhoto] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [deletePassword, setDeletePassword] = useState('');
  const [deleting, setDeleting] = useState(false);

  async function handleSaveName() {
    if (!editName.trim() || !firebaseUser?.email) {return;}
    setSaving(true);
    try {
      await userService.updateProfile(firebaseUser.email, {name: editName.trim()});
      await refreshUser();
      Alert.alert('Saved', 'Profile updated successfully.');
    } catch (err: any) {
      Alert.alert('Error', err.message);
    } finally {
      setSaving(false);
    }
  }

  async function handlePickPhoto() {
    if (!firebaseUser?.email || !currentUser?.userId) {return;}
    const result = await launchImageLibrary({mediaType: 'photo', quality: 0.8});
    if (!result.assets?.[0]?.uri) {return;}
    setUploadingPhoto(true);
    try {
      await userService.uploadProfilePicture(
        firebaseUser.email,
        currentUser.userId,
        result.assets[0].uri,
      );
      await refreshUser();
    } catch (err: any) {
      Alert.alert('Error', err.message);
    } finally {
      setUploadingPhoto(false);
    }
  }

  async function handleSignOut() {
    Alert.alert('Sign Out', 'Are you sure you want to sign out?', [
      {text: 'Cancel', style: 'cancel'},
      {
        text: 'Sign Out',
        style: 'destructive',
        onPress: () => authService.signOut(),
      },
    ]);
  }

  async function handleDeleteAccount() {
    if (!deletePassword) {return;}
    setDeleting(true);
    try {
      await authService.deleteAccount(deletePassword);
    } catch (err: any) {
      Alert.alert('Error', err.message ?? 'Failed to delete account.');
    } finally {
      setDeleting(false);
      setShowDeleteModal(false);
    }
  }

  if (!currentUser) {
    return (
      <View style={{flex: 1}}>
        <GradientBackground />
        <SafeAreaView style={{flex: 1, justifyContent: 'center', alignItems: 'center'}}>
          <ActivityIndicator size="large" color={Colors.blue} />
        </SafeAreaView>
      </View>
    );
  }

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}}>
        <ScrollView contentContainerStyle={styles.scroll}>
          {/* Header */}
          <View style={styles.header}>
            <TouchableOpacity onPress={() => navigation.goBack()}>
              <Icon name="chevron-back" size={24} color={Colors.blue} />
            </TouchableOpacity>
            <Text style={[styles.headerTitle, {color: textPrimary(scheme)}]}>
              Profile
            </Text>
            <View style={{width: 24}} />
          </View>

          {/* Avatar */}
          <View style={styles.avatarSection}>
            <TouchableOpacity onPress={handlePickPhoto} disabled={uploadingPhoto}>
              {uploadingPhoto ? (
                <View style={[styles.avatarPlaceholder, {backgroundColor: Colors.blue + '22'}]}>
                  <ActivityIndicator color={Colors.blue} />
                </View>
              ) : (
                <ProfileAvatar
                  url={currentUser.profilePictureURL}
                  name={currentUser.name}
                  size={90}
                />
              )}
              <View style={styles.cameraOverlay}>
                <Icon name="camera" size={14} color="#fff" />
              </View>
            </TouchableOpacity>
            <Text style={[styles.userName, {color: textPrimary(scheme)}]}>
              {currentUser.name}
            </Text>
            <Text style={[styles.userEmail, {color: textSecondary(scheme)}]}>
              {currentUser.email}
            </Text>
          </View>

          {/* Edit name */}
          <View
            style={[
              styles.section,
              cardStyle(scheme),
              scheme !== 'dark' && {backgroundColor: Colors.backgroundBottomLight},
            ]}>
            <Text style={[styles.sectionLabel, {color: textSecondary(scheme)}]}>
              Display Name
            </Text>
            <TextInput
              value={editName}
              onChangeText={setEditName}
              style={[styles.nameInput, {color: textPrimary(scheme)}]}
              placeholder="Your name"
              placeholderTextColor={textSecondary(scheme)}
            />
            <PrimaryButton
              title={saving ? 'Saving...' : 'Save Changes'}
              onPress={handleSaveName}
              loading={saving}
              disabled={editName.trim() === currentUser.name}
              color={Colors.blue}
              style={styles.saveBtn}
            />
          </View>

          {/* Account info */}
          <View
            style={[
              styles.section,
              cardStyle(scheme),
              scheme !== 'dark' && {backgroundColor: Colors.backgroundBottomLight},
            ]}>
            <View style={styles.infoRow}>
              <Icon name="mail-outline" size={18} color={Colors.blue} />
              <Text style={[styles.infoText, {color: textPrimary(scheme)}]}>
                {currentUser.email}
              </Text>
            </View>
            <View style={[styles.infoRow, {marginTop: Spacing.sm}]}>
              <Icon name="person-outline" size={18} color={Colors.blue} />
              <Text style={[styles.infoText, {color: textPrimary(scheme)}]}>
                {currentUser.userId}
              </Text>
            </View>
            {currentUser.isSubscribed || currentUser.adminSubscribed ? (
              <View style={[styles.infoRow, {marginTop: Spacing.sm}]}>
                <Icon name="star" size={18} color={Colors.orange} />
                <Text style={[styles.infoText, {color: Colors.orange}]}>
                  Premium Member
                </Text>
              </View>
            ) : null}
          </View>

          {/* Ad banner */}
          <AdBanner />

          {/* Sign out */}
          <TouchableOpacity
            style={[styles.dangerRow, {backgroundColor: Colors.red + '1A', borderRadius: Radius.md}]}
            onPress={handleSignOut}>
            <Icon name="log-out-outline" size={20} color={Colors.red} />
            <Text style={[styles.dangerText, {color: Colors.red}]}>Sign Out</Text>
          </TouchableOpacity>

          {/* Delete account */}
          <TouchableOpacity
            style={[styles.dangerRow, {marginTop: Spacing.sm, backgroundColor: Colors.red + '0D', borderRadius: Radius.md}]}
            onPress={() => setShowDeleteModal(true)}>
            <Icon name="trash-outline" size={20} color={Colors.red} />
            <Text style={[styles.dangerText, {color: Colors.red}]}>Delete Account</Text>
          </TouchableOpacity>

          {/* Delete confirmation */}
          {showDeleteModal && (
            <View style={[styles.deleteCard, cardStyle(scheme)]}>
              <Text style={[styles.deleteTitle, {color: Colors.red}]}>
                Delete Account
              </Text>
              <Text style={[styles.deleteWarning, {color: textSecondary(scheme)}]}>
                This action is permanent. Enter your password to confirm.
              </Text>
              <TextInput
                placeholder="Password"
                placeholderTextColor={textSecondary(scheme)}
                value={deletePassword}
                onChangeText={setDeletePassword}
                secureTextEntry
                style={[styles.nameInput, {color: textPrimary(scheme), marginBottom: Spacing.md}]}
              />
              <View style={styles.deleteActions}>
                <TouchableOpacity
                  style={[styles.deleteBtn, {backgroundColor: Colors.blue + '1A'}]}
                  onPress={() => setShowDeleteModal(false)}>
                  <Text style={{color: Colors.blue, fontWeight: '600'}}>Cancel</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.deleteBtn, {backgroundColor: Colors.red}]}
                  onPress={handleDeleteAccount}
                  disabled={deleting}>
                  {deleting ? (
                    <ActivityIndicator color="#fff" />
                  ) : (
                    <Text style={{color: '#fff', fontWeight: '600'}}>Delete</Text>
                  )}
                </TouchableOpacity>
              </View>
            </View>
          )}

        </ScrollView>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  scroll: {
    padding: Spacing.lg,
    paddingBottom: 60,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: Spacing.lg,
  },
  headerTitle: {
    fontSize: 20,
    fontWeight: '700',
  },
  avatarSection: {
    alignItems: 'center',
    marginBottom: Spacing.xl,
  },
  avatarPlaceholder: {
    width: 90,
    height: 90,
    borderRadius: 45,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cameraOverlay: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: 26,
    height: 26,
    borderRadius: 13,
    backgroundColor: Colors.blue,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: '#fff',
  },
  userName: {
    fontSize: 20,
    fontWeight: '700',
    marginTop: Spacing.md,
  },
  userEmail: {
    fontSize: 14,
    marginTop: 4,
  },
  section: {
    padding: Spacing.md,
    marginBottom: Spacing.md,
  },
  sectionLabel: {
    fontSize: 12,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: Spacing.sm,
  },
  nameInput: {
    fontSize: 17,
    borderBottomWidth: 1.5,
    borderBottomColor: Colors.blue + '55',
    paddingVertical: Spacing.sm,
    marginBottom: Spacing.md,
  },
  saveBtn: {},
  infoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  infoText: {
    fontSize: 15,
    flex: 1,
  },
  dangerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.md,
    gap: Spacing.md,
    marginBottom: 4,
  },
  dangerText: {
    fontSize: 17,
    fontWeight: '500',
  },
  deleteCard: {
    padding: Spacing.md,
    marginTop: Spacing.md,
  },
  deleteTitle: {
    fontSize: 18,
    fontWeight: '700',
    marginBottom: Spacing.sm,
  },
  deleteWarning: {
    fontSize: 14,
    marginBottom: Spacing.md,
    lineHeight: 20,
  },
  deleteActions: {
    flexDirection: 'row',
    gap: Spacing.md,
  },
  deleteBtn: {
    flex: 1,
    height: 44,
    borderRadius: Radius.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
