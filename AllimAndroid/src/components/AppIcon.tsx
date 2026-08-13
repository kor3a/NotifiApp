import React from 'react';
import {StyleProp, Text, TextStyle} from 'react-native';
import Ionicons from '@expo/vector-icons/Ionicons';

/**
 * Ionicons glyph renderer.
 *
 * Both react-native-vector-icons and @expo/vector-icons (which vendors the
 * former's create-icon-set) force `fontWeight: 'normal'` and
 * `fontStyle: 'normal'` onto every icon, appended *after* the caller's style so
 * they cannot be overridden. On RN 0.76 / API 35 that combination makes Android
 * resolve the typeface through a path that drops the custom asset font and
 * falls back to the system one, where Ionicons' private-use codepoints have no
 * glyphs — so every icon renders as empty, zero-width text. A plain <Text>
 * carrying only fontFamily renders the same glyph correctly, which is all this
 * component does.
 *
 * The family name is the basename of the .ttf embedded by the expo-font config
 * plugin in app.config.js (assets/fonts/Ionicons.ttf) — that plugin entry is
 * what makes this work, so keep it.
 *
 * Names and codepoints still come from @expo/vector-icons, so `name` stays
 * typed to the real glyph set and a typo remains a compile error.
 */

type IconName = React.ComponentProps<typeof Ionicons>['name'];

const GLYPHS = Ionicons.glyphMap as unknown as Record<string, number>;

type Props = {
  name: IconName;
  size?: number;
  color?: string;
  style?: StyleProp<TextStyle>;
};

export default function AppIcon({name, size = 24, color, style}: Props) {
  const codepoint = GLYPHS[name];

  if (codepoint === undefined) {
    if (__DEV__) {
      console.warn(`AppIcon: "${name}" is not an Ionicons glyph`);
    }
    return null;
  }

  return (
    <Text
      selectable={false}
      allowFontScaling={false}
      style={[{fontFamily: 'Ionicons', fontSize: size, color}, style]}>
      {String.fromCodePoint(codepoint)}
    </Text>
  );
}
