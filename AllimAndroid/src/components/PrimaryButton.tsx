import React from 'react';
import {
  TouchableOpacity,
  Text,
  ActivityIndicator,
  StyleSheet,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import {Colors, Radius} from '../theme/AppTheme';

interface Props {
  title: string;
  onPress: () => void;
  loading?: boolean;
  disabled?: boolean;
  gradient?: boolean;
  color?: string;
  style?: any;
}

export default function PrimaryButton({
  title,
  onPress,
  loading,
  disabled,
  gradient = false,
  color = Colors.blue,
  style,
}: Props) {
  const isDisabled = disabled || loading;

  if (gradient) {
    return (
      <TouchableOpacity
        onPress={onPress}
        disabled={isDisabled}
        activeOpacity={0.75}
        style={style}>
        <LinearGradient
          colors={[Colors.blue, Colors.purple]}
          start={{x: 0, y: 0}}
          end={{x: 1, y: 0}}
          style={[styles.button, isDisabled && styles.disabled]}>
          {loading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.label}>{title}</Text>
          )}
        </LinearGradient>
      </TouchableOpacity>
    );
  }

  return (
    <TouchableOpacity
      onPress={onPress}
      disabled={isDisabled}
      activeOpacity={0.75}
      style={[
        styles.button,
        {backgroundColor: color},
        isDisabled && styles.disabled,
        style,
      ]}>
      {loading ? (
        <ActivityIndicator color="#fff" />
      ) : (
        <Text style={styles.label}>{title}</Text>
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: {
    height: 50,
    borderRadius: Radius.md,
    alignItems: 'center',
    justifyContent: 'center',
    width: '100%',
  },
  label: {
    color: '#fff',
    fontSize: 17,
    fontWeight: '600',
  },
  disabled: {
    opacity: 0.6,
  },
});
