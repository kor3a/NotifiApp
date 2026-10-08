import React from 'react';
import {View, Text, Image, StyleSheet} from 'react-native';
import {Colors} from '../theme/AppTheme';
import {portraitFor} from './portraits';

interface Props {
  url?: string | null;
  name?: string;
  size?: number;
}

export default function ProfileAvatar({url, name, size = 40}: Props) {
  const circle = {width: size, height: size, borderRadius: size / 2};

  if (url) {
    return <Image source={{uri: url}} style={[styles.image, circle]} />;
  }

  // No photo yet: an illustrated portrait picked from their name.
  const portrait = portraitFor(name);
  if (portrait) {
    return <Image source={portrait} style={[styles.image, circle]} />;
  }

  return (
    <View style={[styles.fallback, circle, {backgroundColor: Colors.blue}]}>
      <Text style={[styles.letter, {fontSize: size * 0.4}]}>?</Text>
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
