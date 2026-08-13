/**
 * TEMPORARY diagnostic — delete once the icon rendering is understood.
 *
 * Renders the same glyph four ways so the failure can be located by looking at
 * which swatches are blank:
 *
 *   1 (red)   Icon component from @expo/vector-icons
 *   2 (green) raw <Text> with fontFamily 'Ionicons' — bypasses the component
 *   3 (blue)  raw <Text> with no fontFamily — control, must always render '+'
 *   4 (black) Icon from react-native-vector-icons — the previous library
 *
 * 3 blank        -> nothing renders here at all; look higher up the tree.
 * 3 only         -> the Ionicons typeface is not registered natively.
 * 2 + 3, not 1/4 -> the font works; the icon components are the problem.
 * all four       -> icons work, and the real issue is elsewhere on the screen.
 */
import React from 'react';
import {Text, View, StyleSheet} from 'react-native';
import * as Font from 'expo-font';
import ExpoIcon from '@expo/vector-icons/Ionicons';
import RnviIcon from 'react-native-vector-icons/Ionicons';

const glyphMap: Record<string, number> =
  (ExpoIcon as any).glyphMap ?? (ExpoIcon as any).getRawGlyphMap?.() ?? {};
const addCode = glyphMap.add;

export default function IconDebugProbe() {
  React.useEffect(() => {
    console.log('[probe] Font.isLoaded(Ionicons) =', Font.isLoaded('Ionicons'));
    console.log('[probe] glyphMap entries =', Object.keys(glyphMap).length);
    console.log('[probe] glyph code for "add" =', addCode);
    console.log('[probe] typeof ExpoIcon =', typeof ExpoIcon);
    console.log('[probe] typeof RnviIcon =', typeof RnviIcon);
  }, []);

  return (
    <View style={styles.row}>
      <ExpoIcon name="add" size={36} color="#FF0000" />
      <Text style={styles.fontFamilyText}>
        {addCode ? String.fromCharCode(addCode) : '?'}
      </Text>
      <Text style={styles.controlText}>+</Text>
      <RnviIcon name="add" size={36} color="#000000" />
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-around',
    paddingVertical: 8,
    marginHorizontal: 16,
    borderWidth: 2,
    borderColor: '#FF00FF',
  },
  fontFamilyText: {fontFamily: 'Ionicons', fontSize: 36, color: '#00AA00'},
  controlText: {fontSize: 36, color: '#0000FF'},
});
