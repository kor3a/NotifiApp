import React, {forwardRef} from 'react';
import {
  View,
  Text,
  TextInput,
  TextInputProps,
  StyleSheet,
  TouchableOpacity,
  ColorSchemeName,
  StyleProp,
  ViewStyle,
} from 'react-native';
import Icon from '../../components/AppIcon';
import {Colors, textPrimary, textSecondary} from '../../theme/AppTheme';
import {fieldStyle, profilePalette} from '../profile/profileUi';

// Pieces shared by the sign-in, sign-up, password reset and profile setup
// screens — ports of what the iOS LoginView family draws from OrganicTheme.

/**
 * A form input sunk into the canvas: the iOS `organicField` capsule with its
 * placeholder in soft ink rather than the system grey.
 */
export const AuthField = forwardRef<
  TextInput,
  TextInputProps & {scheme: ColorSchemeName}
>(function AuthField({scheme, style, ...props}, ref) {
  return (
    <TextInput
      ref={ref}
      placeholderTextColor={textSecondary(scheme) + 'CC'}
      style={[fieldStyle(scheme), style]}
      {...props}
    />
  );
});

/**
 * The app's mark on a blush disc with the name below — the iOS LoginView
 * wordmark. iOS draws its AllimMark artwork here; the storefront and its check
 * disc are redrawn from the icon font so they take this app's accent and warm
 * highlight instead of the iOS teal baked into that PNG.
 */
export function AllimWordmark({scheme}: {scheme: ColorSchemeName}) {
  const p = profilePalette(scheme);
  return (
    <View style={styles.wordmark}>
      <View style={[styles.markDisc, {backgroundColor: p.blush}]}>
        <Icon name="storefront-outline" size={50} color={p.accent} />
        <View style={styles.markCheck}>
          <Icon name="checkmark" size={13} color="#fff" />
        </View>
      </View>
      <Text style={[styles.wordmarkText, {color: textPrimary(scheme)}]}>Allim</Text>
    </View>
  );
}

/** A glyph on a blush disc — the icon atop the permission primers and sheets. */
export function BlushIcon({
  scheme,
  name,
  size = 120,
  glyphSize = 48,
}: {
  scheme: ColorSchemeName;
  name: React.ComponentProps<typeof Icon>['name'];
  size?: number;
  glyphSize?: number;
}) {
  const p = profilePalette(scheme);
  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        backgroundColor: p.blush,
        alignItems: 'center',
        justifyContent: 'center',
      }}>
      <Icon name={name} size={glyphSize} color={p.accent} />
    </View>
  );
}

/**
 * The quiet underlined way off a screen ("Forgot password?", "Back to Login")
 * — text rather than a second pill, so the one pill reads as the action.
 */
export function QuietLink({
  scheme,
  title,
  onPress,
  underline = true,
  disabled,
  style,
}: {
  scheme: ColorSchemeName;
  title: string;
  onPress: () => void;
  underline?: boolean;
  disabled?: boolean;
  style?: StyleProp<ViewStyle>;
}) {
  return (
    <TouchableOpacity
      onPress={onPress}
      disabled={disabled}
      activeOpacity={0.6}
      hitSlop={8}
      style={style}>
      <Text
        style={[
          styles.quietLink,
          {
            color: textSecondary(scheme),
            textDecorationLine: underline ? 'underline' : 'none',
          },
        ]}>
        {title}
      </Text>
    </TouchableOpacity>
  );
}

/** Inline error line above a form, in the destructive tint. */
export function FormError({message}: {message: string}) {
  if (!message) {
    return null;
  }
  return <Text style={styles.formError}>{message}</Text>;
}

export const authStyles = StyleSheet.create({
  // The iOS screens stack everything in a 22pt-spaced column with 20pt
  // gutters.
  scroll: {
    flexGrow: 1,
    paddingHorizontal: 20,
    paddingBottom: 40,
    gap: 22,
  },
  fields: {
    gap: 12,
  },
  display: {
    fontSize: 32,
    fontWeight: '800',
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 16,
    lineHeight: 22,
    textAlign: 'center',
  },
});

const styles = StyleSheet.create({
  wordmark: {
    alignItems: 'center',
    gap: 14,
    marginBottom: 4,
  },
  markDisc: {
    width: 96,
    height: 96,
    borderRadius: 48,
    alignItems: 'center',
    justifyContent: 'center',
  },
  markCheck: {
    position: 'absolute',
    right: 20,
    bottom: 20,
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: Colors.orange,
    alignItems: 'center',
    justifyContent: 'center',
  },
  wordmarkText: {
    fontSize: 40,
    fontWeight: '800',
    letterSpacing: -0.5,
  },
  quietLink: {
    fontSize: 14,
    textAlign: 'center',
  },
  formError: {
    fontSize: 13,
    color: Colors.red,
    textAlign: 'center',
    paddingHorizontal: 4,
  },
});
