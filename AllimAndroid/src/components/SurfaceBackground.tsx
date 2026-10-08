import React from 'react';
import {StyleSheet, useColorScheme} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import {
  BackgroundSurface,
  useBackgroundPreference,
} from '../services/backgroundPreferences';
import {backgroundStops} from '../theme/BackgroundTheme';

// GradientBackground for a screen the user can recolor from its Colors picker:
// the app gradient until they choose otherwise.
export default function SurfaceBackground({
  surface,
}: {
  surface: BackgroundSurface;
}) {
  const scheme = useColorScheme();
  const {color, shade} = useBackgroundPreference(surface);

  return (
    <LinearGradient
      colors={backgroundStops(color, scheme, shade)}
      start={{x: 0, y: 0}}
      end={{x: 0, y: 1}}
      style={StyleSheet.absoluteFill}
    />
  );
}
