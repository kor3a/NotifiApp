import React from 'react';
import {ColorSchemeName, Image, StyleSheet, View} from 'react-native';

// The recipe screens run on a warm accent rather than the app blue — they sit
// on culinary artwork, where a cool blue reads as foreign. Same tokens as the
// iOS RecipePalette (AllimColor accent / warning / success).
export const RecipePalette = {
  paprika: (s: ColorSchemeName) => (s === 'dark' ? '#FF7A45' : '#D94F16'),
  apricot: (s: ColorSchemeName) => (s === 'dark' ? '#E0A33F' : '#B06A08'),
  basil: (s: ColorSchemeName) => (s === 'dark' ? '#5FCB90' : '#1C6640'),
  onAccent: '#FFFFFF',
  // Frosted surface for bubbles, chips and banners over the artwork.
  surface: (s: ColorSchemeName) =>
    s === 'dark' ? 'rgba(40,36,34,0.82)' : 'rgba(255,255,255,0.86)',
  surfaceBorder: (s: ColorSchemeName) =>
    s === 'dark' ? 'rgba(255,255,255,0.12)' : 'rgba(255,255,255,0.95)',
  hairline: (s: ColorSchemeName) =>
    s === 'dark' ? 'rgba(255,255,255,0.10)' : 'rgba(0,0,0,0.06)',
  rowDivider: (s: ColorSchemeName) =>
    s === 'dark' ? 'rgba(255,255,255,0.16)' : 'rgba(0,0,0,0.12)',
};

const ARTWORK = {
  light: require('../../../assets/images/recipe-background-light.png'),
  dark: require('../../../assets/images/recipe-background-dark.png'),
};

// Full-bleed culinary artwork with a wash over it so text keeps its contrast.
// Screens that put bare text on the photo turn `extraScrim` up.
export function RecipeBackdrop({
  scheme,
  extraScrim = 0,
}: {
  scheme: ColorSchemeName;
  extraScrim?: number;
}) {
  const dark = scheme === 'dark';
  const base = dark ? 0.28 : 0.3;
  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      <Image
        source={dark ? ARTWORK.dark : ARTWORK.light}
        style={StyleSheet.absoluteFill}
        resizeMode="cover"
      />
      <View
        style={[
          StyleSheet.absoluteFill,
          {
            backgroundColor: dark
              ? `rgba(0,0,0,${base + extraScrim})`
              : `rgba(255,255,255,${base + extraScrim})`,
          },
        ]}
      />
    </View>
  );
}
