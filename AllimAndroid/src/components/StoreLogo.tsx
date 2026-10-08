import React, {useEffect, useState} from 'react';
import {View, Text, Image, StyleSheet} from 'react-native';
import {Colors} from '../theme/AppTheme';
import {storeLogoService} from '../services/storeLogoService';

interface Props {
  storeName: string;
  size?: number;
}

// The store's logo from the shared catalog, or its initial on a tinted circle
// when the catalog has none (or the image fails to load). Stands in for the
// iOS CachedLogoImage; React Native's image cache covers the disk caching.
export default function StoreLogo({storeName, size = 48}: Props) {
  const [url, setUrl] = useState<string | undefined>(() =>
    storeLogoService.logoURL(storeName),
  );
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    setFailed(false);
    storeLogoService.load().then(() => {
      if (!cancelled) {
        setUrl(storeLogoService.logoURL(storeName));
      }
    });
    return () => {
      cancelled = true;
    };
  }, [storeName]);

  const circle = {width: size, height: size, borderRadius: size / 2};

  if (url && !failed) {
    return (
      <Image
        source={{uri: url}}
        style={[styles.image, circle]}
        onError={() => setFailed(true)}
      />
    );
  }

  return (
    <View style={[styles.fallback, circle]}>
      <Text style={[styles.letter, {fontSize: size * 0.42}]}>
        {storeName.trim().charAt(0).toUpperCase() || '?'}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  image: {
    backgroundColor: Colors.white,
  },
  fallback: {
    backgroundColor: Colors.blue + '26',
    alignItems: 'center',
    justifyContent: 'center',
  },
  letter: {
    color: Colors.blue,
    fontWeight: '700',
  },
});
