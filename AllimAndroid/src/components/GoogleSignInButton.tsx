import React from 'react';
import {
  ActivityIndicator,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  useColorScheme,
} from 'react-native';
import {
  Colors,
  Radius,
  Spacing,
  cardBackground,
  cardBorder,
  textPrimary,
  textSecondary,
} from '../theme/AppTheme';

interface Props {
  onPress: () => void;
  loading?: boolean;
  disabled?: boolean;
}

/**
 * "Continue with Google", styled to match the iOS LoginView button: the
 * four-colour Google G on a card-coloured pill the same height as PrimaryButton.
 *
 * The mark is drawn from four coloured glyph layers rather than an image so it
 * scales with the type and needs no asset — Android has no equivalent of the
 * gradient-filled text iOS uses.
 */
export default function GoogleSignInButton({onPress, loading, disabled}: Props) {
  const scheme = useColorScheme();
  const isDisabled = disabled || loading;

  return (
    <TouchableOpacity
      onPress={onPress}
      disabled={isDisabled}
      activeOpacity={0.75}
      accessibilityRole="button"
      accessibilityLabel="Continue with Google"
      style={[
        styles.button,
        {
          backgroundColor: cardBackground(scheme),
          borderColor: cardBorder(scheme),
        },
        isDisabled && styles.disabled,
      ]}>
      {loading ? (
        <ActivityIndicator color={Colors.blue} />
      ) : (
        <View style={styles.content}>
          <GoogleMark />
          <Text style={[styles.label, {color: textPrimary(scheme)}]}>
            Continue with Google
          </Text>
        </View>
      )}
    </TouchableOpacity>
  );
}

/** The Google "G" in its four brand colours. */
function GoogleMark() {
  return (
    <View style={styles.mark}>
      <Text style={[styles.markLetter, {color: '#4285F4'}]}>G</Text>
      <View style={styles.markStripes}>
        <View style={[styles.stripe, {backgroundColor: '#EA4335'}]} />
        <View style={[styles.stripe, {backgroundColor: '#FBBC05'}]} />
        <View style={[styles.stripe, {backgroundColor: '#34A853'}]} />
      </View>
    </View>
  );
}

/** "or" rule, matching the divider above the social section on iOS. */
export function OrDivider() {
  const scheme = useColorScheme();
  const line = {backgroundColor: cardBorder(scheme)};
  return (
    <View style={styles.divider}>
      <View style={[styles.dividerLine, line]} />
      <Text style={[styles.dividerLabel, {color: textSecondary(scheme)}]}>
        or
      </Text>
      <View style={[styles.dividerLine, line]} />
    </View>
  );
}

const styles = StyleSheet.create({
  button: {
    height: 50,
    borderRadius: Radius.md,
    borderWidth: 1.5,
    alignItems: 'center',
    justifyContent: 'center',
    width: '100%',
  },
  disabled: {
    opacity: 0.6,
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  label: {
    fontSize: 16,
    fontWeight: '500',
    marginLeft: 10,
  },
  mark: {
    alignItems: 'center',
  },
  markLetter: {
    fontSize: 20,
    fontWeight: '700',
    lineHeight: 22,
  },
  markStripes: {
    flexDirection: 'row',
    marginTop: 2,
  },
  stripe: {
    width: 5,
    height: 2.5,
    borderRadius: 1,
    marginHorizontal: 0.5,
  },
  divider: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: Spacing.md,
  },
  dividerLine: {
    flex: 1,
    height: 1,
  },
  dividerLabel: {
    fontSize: 13,
    marginHorizontal: Spacing.md,
  },
});
