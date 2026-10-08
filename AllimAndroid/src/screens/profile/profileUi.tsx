import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
  ColorSchemeName,
  StyleProp,
  ViewStyle,
} from 'react-native';
import {useNavigation} from '@react-navigation/native';
import Icon from '../../components/AppIcon';
import {Colors, cardStyle, textPrimary, textSecondary} from '../../theme/AppTheme';

type IconName = React.ComponentProps<typeof Icon>['name'];

// The iOS Profile screens' terracotta (accent), blush (accent wash), sage
// (success) and rust (destructive) roles, in the Android app's palette — the
// same mapping FriendsScreen uses.
export function profilePalette(scheme: ColorSchemeName) {
  const dark = scheme === 'dark';
  return {
    accent: Colors.blue,
    blush: dark ? 'rgba(0,122,255,0.22)' : 'rgba(0,122,255,0.10)',
    sage: dark ? '#1F3A28' : '#DDF3E3',
    sageInk: dark ? '#5FD982' : '#1E7A35',
    rust: Colors.red,
    rustWash: dark ? 'rgba(255,59,48,0.20)' : 'rgba(255,59,48,0.10)',
    outline: dark ? 'rgba(255,255,255,0.18)' : 'rgba(0,0,0,0.12)',
    field: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.05)',
  };
}

// iOS shows these screens with an inline navigation bar: back on the left,
// the title centred, and an optional control on the right.
export function ProfileHeader({
  scheme,
  title,
  right,
}: {
  scheme: ColorSchemeName;
  title: string;
  right?: React.ReactNode;
}) {
  const navigation = useNavigation();
  const p = profilePalette(scheme);
  return (
    <View style={styles.header}>
      <View style={styles.headerSide}>
        {navigation.canGoBack() && (
          <TouchableOpacity
            onPress={() => navigation.goBack()}
            style={styles.backBtn}
            accessibilityLabel="Back">
            <Icon name="chevron-back" size={28} color={p.accent} />
          </TouchableOpacity>
        )}
      </View>
      <Text style={[styles.headerTitle, {color: textPrimary(scheme)}]} numberOfLines={1}>
        {title}
      </Text>
      <View style={[styles.headerSide, styles.headerRight]}>{right}</View>
    </View>
  );
}

// The display heading above a group of cards.
export function SectionLabel({scheme, title}: {scheme: ColorSchemeName; title: string}) {
  return <Text style={[styles.sectionLabel, {color: textPrimary(scheme)}]}>{title}</Text>;
}

// A card-shaped row that opens somewhere (chevron) or does something (no
// accessory). Port of iOS OrganicNavRow.
export function NavRow({
  scheme,
  icon,
  title,
  subtitle,
  tint,
  accessory = 'chevron-forward',
  onPress,
  disabled,
}: {
  scheme: ColorSchemeName;
  icon: IconName;
  title: string;
  subtitle?: string;
  tint?: string;
  accessory?: IconName | null;
  onPress: () => void;
  disabled?: boolean;
}) {
  const p = profilePalette(scheme);
  return (
    <TouchableOpacity
      onPress={onPress}
      disabled={disabled}
      activeOpacity={0.75}
      style={[cardStyle(scheme), styles.navRow]}>
      <View style={[styles.navIcon, {backgroundColor: p.blush}]}>
        <Icon name={icon} size={18} color={tint ?? p.accent} />
      </View>
      <View style={styles.navText}>
        <Text style={[styles.navTitle, {color: textPrimary(scheme)}]}>{title}</Text>
        {subtitle ? (
          <Text style={[styles.navSubtitle, {color: textSecondary(scheme)}]}>{subtitle}</Text>
        ) : null}
      </View>
      {accessory ? (
        <Icon name={accessory} size={16} color={textSecondary(scheme)} style={{opacity: 0.7}} />
      ) : null}
    </TouchableOpacity>
  );
}

// Full-width capsule button. Port of iOS OrganicPillButton.
export function PillButton({
  title,
  onPress,
  disabled,
  loading,
  color = Colors.blue,
  style,
}: {
  title: string;
  onPress: () => void;
  disabled?: boolean;
  loading?: boolean;
  color?: string;
  style?: StyleProp<ViewStyle>;
}) {
  return (
    <TouchableOpacity
      onPress={onPress}
      disabled={disabled || loading}
      activeOpacity={0.8}
      style={[styles.pill, {backgroundColor: color, opacity: disabled ? 0.5 : 1}, style]}>
      {loading ? (
        <ActivityIndicator color="#fff" />
      ) : (
        <Text style={styles.pillText}>{title}</Text>
      )}
    </TouchableOpacity>
  );
}

// A text input sunk into the canvas rather than raised off it — iOS
// organicField.
export function fieldStyle(scheme: ColorSchemeName) {
  return [
    styles.field,
    {backgroundColor: profilePalette(scheme).field, color: textPrimary(scheme)},
  ];
}

export const profileStyles = StyleSheet.create({
  scroll: {
    paddingHorizontal: 20,
    paddingTop: 12,
    paddingBottom: 40,
    gap: 24,
  },
  section: {
    gap: 10,
  },
  hint: {
    fontSize: 14,
    lineHeight: 19,
  },
});

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    height: 52,
  },
  headerSide: {
    width: 56,
    flexDirection: 'row',
    alignItems: 'center',
  },
  headerRight: {
    justifyContent: 'flex-end',
  },
  backBtn: {
    padding: 4,
  },
  headerTitle: {
    flex: 1,
    textAlign: 'center',
    fontSize: 17,
    fontWeight: '700',
  },
  sectionLabel: {
    fontSize: 22,
    fontWeight: '800',
  },
  navRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 22,
    marginVertical: 0,
  },
  navIcon: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: 'center',
    justifyContent: 'center',
  },
  navText: {
    flex: 1,
    gap: 2,
  },
  navTitle: {
    fontSize: 16,
    fontWeight: '600',
  },
  navSubtitle: {
    fontSize: 13,
    lineHeight: 17,
  },
  pill: {
    height: 54,
    borderRadius: 27,
    alignItems: 'center',
    justifyContent: 'center',
  },
  pillText: {
    color: '#fff',
    fontSize: 17,
    fontWeight: '600',
  },
  field: {
    height: 54,
    borderRadius: 27,
    paddingHorizontal: 18,
    fontSize: 17,
  },
});
