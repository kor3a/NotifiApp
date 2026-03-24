import React from 'react';
import {View, useColorScheme} from 'react-native';
import {cardStyle} from '../theme/AppTheme';

interface CardProps {
  children: React.ReactNode;
  style?: any;
}

export default function Card({children, style}: CardProps) {
  const scheme = useColorScheme();
  return (
    <View style={[cardStyle(scheme), style]}>
      {children}
    </View>
  );
}
