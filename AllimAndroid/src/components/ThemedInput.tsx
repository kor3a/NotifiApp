import React from 'react';
import {TextInput, TextInputProps, useColorScheme} from 'react-native';
import {inputStyle, textPrimary} from '../theme/AppTheme';

interface Props extends TextInputProps {
  style?: any;
}

export default function ThemedInput({style, ...props}: Props) {
  const scheme = useColorScheme();
  return (
    <TextInput
      placeholderTextColor={scheme === 'dark' ? '#636366' : '#8E8E93'}
      style={[inputStyle(scheme), style]}
      {...props}
    />
  );
}
