import React from 'react';
import {View, Text, Image, StyleSheet} from 'react-native';
import {Colors} from '../theme/AppTheme';

interface Props {
  url?: string | null;
  name?: string;
  size?: number;
}

export default function ProfileAvatar({url, name, size = 40}: Props) {
  const letter = name ? name.charAt(0).toUpperCase() : '?';

  if (url) {
    return (
      <Image
        source={{uri: url}}
        style={[
          styles.image,
          {width: size, height: size, borderRadius: size / 2},
        ]}
      />
    );
  }

  return (
    <View
      style={[
        styles.fallback,
        {
          width: size,
          height: size,
          borderRadius: size / 2,
          backgroundColor: Colors.blue,
        },
      ]}>
      <Text style={[styles.letter, {fontSize: size * 0.4}]}>{letter}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  image: {
    resizeMode: 'cover',
  },
  fallback: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  letter: {
    color: '#fff',
    fontWeight: '600',
  },
});
