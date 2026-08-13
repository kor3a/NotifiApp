/**
 * TEMPORARY diagnostic — delete once the fix is confirmed.
 *
 * Four renderings of the same glyph, to confirm the diagnosis:
 *
 *   1 (red)   AppIcon — the fix
 *   2 (green) raw <Text> with fontFamily only — known to work
 *   3 (blue)  plain '+' — control
 *   4 (black) raw <Text> with fontFamily PLUS fontWeight/fontStyle 'normal',
 *             exactly what the icon libraries force on. Expected to be BLANK:
 *             that pair of properties is the whole bug.
 *
 * Expected: 1, 2, 3 render and 4 is blank.
 */
import React from 'react';
import {Text, View, StyleSheet} from 'react-native';
import Ionicons from '@expo/vector-icons/Ionicons';
import AppIcon from './AppIcon';

const addCode = (Ionicons.glyphMap as unknown as Record<string, number>).add;
const glyph = String.fromCodePoint(addCode);

export default function IconDebugProbe() {
  return (
    <View style={styles.row}>
      <AppIcon name="add" size={36} color="#FF0000" />
      <Text style={styles.fontFamilyOnly}>{glyph}</Text>
      <Text style={styles.control}>+</Text>
      <Text style={styles.withWeightAndStyle}>{glyph}</Text>
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
  fontFamilyOnly: {fontFamily: 'Ionicons', fontSize: 36, color: '#00AA00'},
  control: {fontSize: 36, color: '#0000FF'},
  withWeightAndStyle: {
    fontFamily: 'Ionicons',
    fontSize: 36,
    color: '#000000',
    fontWeight: 'normal',
    fontStyle: 'normal',
  },
});
