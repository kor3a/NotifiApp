import {Platform, StyleSheet, ColorSchemeName} from 'react-native';

// ─── Palette ──────────────────────────────────────────────────────────────────
export const Colors = {
  // Brand
  blue: '#007AFF',
  purple: '#AF52DE',
  green: '#34C759',
  red: '#FF3B30',
  orange: '#FF9500',

  // Neutrals (light)
  backgroundTopLight: '#F2F3F8',
  backgroundBottomLight: '#E0E8F5',
  cardBackgroundLight: 'rgba(255,255,255,0.72)',
  cardBorderLight: 'rgba(255,255,255,0.6)',
  textPrimaryLight: '#000000',
  textSecondaryLight: '#6C6C70',

  // Neutrals (dark)
  backgroundTopDark: '#1A1A26',
  backgroundBottomDark: '#262633',
  cardBackgroundDark: 'rgba(255,255,255,0.08)',
  cardBorderDark: 'rgba(255,255,255,0.15)',
  textPrimaryDark: '#FFFFFF',
  textSecondaryDark: '#8E8E93',

  white: '#FFFFFF',
  black: '#000000',
};

// ─── Gradient Stops ───────────────────────────────────────────────────────────
export function backgroundGradient(scheme: ColorSchemeName) {
  if (scheme === 'dark') {
    return [Colors.backgroundTopDark, Colors.backgroundBottomDark];
  }
  return [Colors.backgroundTopLight, Colors.backgroundBottomLight];
}

export function iconGradient() {
  return [Colors.blue, Colors.purple];
}

// ─── Dynamic helpers ──────────────────────────────────────────────────────────
export function cardBackground(scheme: ColorSchemeName) {
  return scheme === 'dark' ? Colors.cardBackgroundDark : Colors.cardBackgroundLight;
}

export function cardBorder(scheme: ColorSchemeName) {
  return scheme === 'dark' ? Colors.cardBorderDark : Colors.cardBorderLight;
}

export function textPrimary(scheme: ColorSchemeName) {
  return scheme === 'dark' ? Colors.textPrimaryDark : Colors.textPrimaryLight;
}

export function textSecondary(scheme: ColorSchemeName) {
  return scheme === 'dark' ? Colors.textSecondaryDark : Colors.textSecondaryLight;
}

// ─── Shared styles ────────────────────────────────────────────────────────────
export const Spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
};

export const Radius = {
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  full: 9999,
};

export const Typography = {
  largeTitle: {fontSize: 34, fontWeight: '700' as const},
  title1: {fontSize: 28, fontWeight: '700' as const},
  title2: {fontSize: 22, fontWeight: '700' as const},
  title3: {fontSize: 20, fontWeight: '600' as const},
  headline: {fontSize: 17, fontWeight: '600' as const},
  body: {fontSize: 17, fontWeight: '400' as const},
  callout: {fontSize: 16, fontWeight: '400' as const},
  subheadline: {fontSize: 15, fontWeight: '400' as const},
  footnote: {fontSize: 13, fontWeight: '400' as const},
  caption: {fontSize: 12, fontWeight: '400' as const},
};

// Card style — equivalent to iOS .cardStyle() modifier
export function cardStyle(scheme: ColorSchemeName) {
  return {
    backgroundColor: cardBackground(scheme),
    borderRadius: Radius.lg,
    borderWidth: 1.5,
    borderColor: cardBorder(scheme),
    marginVertical: 4,
    // iOS renders the soft drop shadow from the shadow* props. Android ignores
    // them and only understands `elevation`, whose shadow is drawn from the
    // view outline on the assumption the fill is opaque. Our cards are
    // translucent white, so the shadow bleeds out around the rounded corners
    // and reads as a washed-out sheet sitting behind every row instead of a
    // shadow. Drop elevation there and let the border carry the separation.
    ...Platform.select({
      ios: {
        shadowColor: Colors.black,
        shadowOffset: {width: 0, height: 4},
        shadowOpacity: scheme === 'dark' ? 0.3 : 0.1,
        shadowRadius: 8,
      },
      default: {},
    }),
  };
}

// Primary button — equivalent to iOS PrimaryButtonStyle
export function primaryButton(color: string = Colors.blue) {
  return StyleSheet.create({
    container: {
      backgroundColor: color,
      borderRadius: Radius.md,
      height: 50,
      alignItems: 'center' as const,
      justifyContent: 'center' as const,
      width: '100%' as unknown as number,
    },
    label: {
      color: Colors.white,
      fontSize: 17,
      fontWeight: '600' as const,
    },
  });
}

// Outlined / secondary button
export function secondaryButton(color: string = Colors.red) {
  return StyleSheet.create({
    container: {
      backgroundColor: color + '1A', // ~10% opacity
      borderRadius: Radius.md,
      height: 50,
      alignItems: 'center' as const,
      justifyContent: 'center' as const,
      width: '100%' as unknown as number,
    },
    label: {
      color: color,
      fontSize: 17,
      fontWeight: '600' as const,
    },
  });
}

// Input field style
export function inputStyle(scheme: ColorSchemeName) {
  return {
    backgroundColor: cardBackground(scheme),
    borderRadius: Radius.md,
    borderWidth: 1.5,
    borderColor: cardBorder(scheme),
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.md,
    color: textPrimary(scheme),
    fontSize: 17,
  };
}
