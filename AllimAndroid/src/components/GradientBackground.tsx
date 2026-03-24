import React from 'react';
import {StyleSheet} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import {useColorScheme} from 'react-native';
import {backgroundGradient} from '../theme/AppTheme';

export default function GradientBackground({
  children,
  style,
}: {
  children?: React.ReactNode;
  style?: any;
}) {
  const scheme = useColorScheme();
  const colors = backgroundGradient(scheme);

  return (
    <LinearGradient
      colors={colors}
      start={{x: 0, y: 0}}
      end={{x: 0, y: 1}}
      style={[StyleSheet.absoluteFill, style]}>
      {children}
    </LinearGradient>
  );
}
